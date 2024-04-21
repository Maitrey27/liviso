import 'dart:io';
import 'dart:typed_data';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:liviso/models/remote_data_source.dart';
import 'package:liviso/screens/event_description.dart';
import 'package:liviso/screens/event_form.dart';
import 'package:liviso/screens/event_list.dart';
import 'package:liviso/screens/login_screen.dart';
import 'package:liviso/screens/photos_screen.dart';
import 'package:liviso/screens/preview_photo_screen.dart';
import 'package:liviso/screens/qr_code_screen.dart';

import 'package:liviso/screens/qr_scanner_screen.dart';
import 'package:liviso/services/notifications_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final RemoteDataSource _remoteDataSource = RemoteDataSource(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<String> _userPhotoUrls = [];
  File? _selectedImage;
  int _selectedIndex = 0;
  String? eventImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserPhotoUrls();
    NotificationController.initializeLocalNotifications();
    NotificationController.startListeningNotificationEvents();
  }

  void _updateEventList() {
    setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (_selectedIndex) {
      case 0:
        // Navigate to the Create Event screen
        _createEvent();
        break;
      case 1:
        // Navigate to the scan code screen
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ScanCodePage(
                    onEventJoined: _updateEventList,
                  )),
        );
        break;
      default:
        // Do nothing for other cases
        break;
    }
  }

  Future<void> _loadUserPhotoUrls() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedUserPhotoUrls = prefs.getStringList(userId);
      if (savedUserPhotoUrls != null) {
        setState(() {
          _userPhotoUrls = savedUserPhotoUrls;
        });
      }
    }
  }

  Future<void> _saveUserPhotoUrls() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(userId, _userPhotoUrls);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
  }

  Future<void> _createEventWithNameAndTime(
    String eventName,
    DateTime startDateTime,
    DateTime endDateTime,
    File? eventImage,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Generate a unique event ID
        final String eventId = 'event_${DateTime.now().millisecondsSinceEpoch}';
        // Upload event image to Firebase Storage
        String? imageUrl;
        if (eventImage != null) {
          final storageReference = FirebaseStorage.instance.ref().child(
              'event_images/$eventId.jpg'); // Use your preferred file extension
          final uploadTask = storageReference.putFile(eventImage);
          await uploadTask.whenComplete(() async {
            imageUrl = await storageReference.getDownloadURL();
          });
        }

        setState(() {
          eventImageUrl = imageUrl;
        });

        // Create an event in Firestore with the generated event ID
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('events')
            .doc(eventId)
            .set({
          'eventName': eventName,
          'organizerUserId': userId,
          'participants': [userId],
          'uploadedImageUrl': imageUrl,
          'startDateTime': startDateTime,
          'endDateTime': endDateTime,
        });

        _showEventCreatedSnackbar(eventName);
        await _loadUserPhotoUrls();
        // Navigate to the QR Code screen with the event ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QrCodeScreen(
              eventId: eventId,
              eventName: eventName,
            ),
          ),
        );
        // Payload to be included in the notification
        final Map<String, dynamic> payload = {
          'eventName': eventName,
          'eventId': eventId,
          'eventStartDate': startDateTime.toIso8601String(),
          'eventEndDate': endDateTime.toIso8601String(),
        };
        // Show instant notification in the app
        _showInstantNotification(
            eventName, startDateTime, endDateTime, payload);
      }
    } catch (e) {
      print("Error creating event: $e");
    }
  }

  void _showEventInstantNotification(
      String eventId,
      String eventName,
      DateTime startDateTime,
      DateTime endDateTime,
      Map<String, dynamic> payload) async {
    // Display an instant notification in the app
    final Map<String, String?> stringPayload = payload.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final currentTime = DateTime.now();
    if (currentTime.isBefore(endDateTime)) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: eventId.hashCode + 1,
          channelKey:
              'basic_channel', // Make sure this key matches your channel setup
          title: 'Event Reminder',
          body: 'Event "$eventName" is ongoing!',
          payload: stringPayload,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'OPEN_EVENT_DETAILS',
            label: 'View Event',
          ),
        ],
      );
    }
  }

  void _scheduleOngoingEventReminder(
    String eventId,
    String eventName,
    DateTime eventStartTime,
    DateTime eventEndTime,
    Map<String, dynamic> payload,
  ) async {
    final Map<String, String?> stringPayload = payload.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final currentTime = DateTime.now();

    // Ensure event is ongoing (current time is before end time)
    if (currentTime.isBefore(eventEndTime)) {
      final localTimeZone =
          await AwesomeNotifications().getLocalTimeZoneIdentifier();

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: eventId.hashCode + 1, // Use a single ID for the ongoing reminder
          channelKey: 'basic_channel',
          title: 'Event Reminder',
          body: 'Event "$eventName" is ongoing!',
          payload: stringPayload,
          actionType: ActionType.SilentAction,
        ),
        schedule: NotificationInterval(
          interval: 10 * 60, // Interval in second
          timeZone: localTimeZone,
          repeats: true,
          preciseAlarm: true, // Ensure timely delivery (optional)
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'OPEN_EVENT_DETAILS',
            label: 'View Event',
          ),
        ],
      );
    }
  }

  void _showEventCreatedSnackbar(String eventName) {
    final snackBar = SnackBar(
      elevation: 8.0,
      backgroundColor: Colors.black38, // Background color of the snackbar
      content: Container(
        height: 50, // Adjust the height as needed
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white), // Icon
            SizedBox(width: 8.0),
            Flexible(
              child: Text(
                'Event $eventName created successfully!', // Displayed text
                style: TextStyle(color: Colors.blue, fontSize: 16.0),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior
          .floating, // Make the snackbar float above other content
      duration: Duration(seconds: 4), // Adjust duration as needed
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showInstantNotification(String eventName, DateTime startDateTime,
      DateTime endDateTime, Map<String, dynamic> payload) {
    // Display an instant notification in the app
    final Map<String, String?> stringPayload = payload.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 0,
        channelKey:
            'basic_channel', // Make sure this key matches your channel setup
        title: eventName,
        body:
            'Start Time: ${_formatDateTime(startDateTime)}\nEnd Time: ${_formatDateTime(endDateTime)}',
        payload: stringPayload,
      ),
    );
  }

  Future<void> _uploadImageToFirebase(String eventId) async {
    if (_selectedImage == null) {
      // No image selected, show a message or return early
      return;
    }

    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // if (eventImage == null) {
        //   // No image selected, show a message or return early
        //   return;
        // }
        // Create a user-specific folder in Firebase Storage
        final String userFolder = 'users/$userId';
        final String fileName = DateTime.now().toString();
        final Reference storageReference =
            _storage.ref().child('$userFolder/images/$fileName.png');

        // Read the file as bytes
        final List<int> imageBytes = await _selectedImage!.readAsBytes();

        // Convert List<int> to Uint8List
        final Uint8List uint8ImageBytes = Uint8List.fromList(imageBytes);

        // Upload the bytes to Firebase Storage
        final TaskSnapshot storageTask =
            await storageReference.putData(uint8ImageBytes);
        final String downloadURL = await storageTask.ref.getDownloadURL();

        // Update the list of user photo URLs
        setState(() {
          _userPhotoUrls.add(downloadURL);
        });

        // Save the updated list to SharedPreferences
        await _saveUserPhotoUrls();

        // Create a Firestore collection for user photos
        final CollectionReference userPhotosCollection = FirebaseFirestore
            .instance
            .collection('user_photos')
            .doc(eventId)
            .collection('photos');

        // Add the uploaded image to Firestore
        await userPhotosCollection.add({
          'eventId': userId,
          'downloadURL': downloadURL,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update or create the event in Firestore with the uploaded image URL
        final eventDocRef =
            FirebaseFirestore.instance.collection('events').doc(eventId);

        if (await eventDocRef.get().then((doc) => doc.exists)) {
          // Document exists, update it
          await eventDocRef.update({
            'uploadedImageUrl': downloadURL,
          });
        } else {
          // Document doesn't exist, create it
          await eventDocRef.set({
            'uploadedImageUrl': downloadURL,
          });
        }

        // Show Snackbar after successful upload
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image uploaded to Firebase Storage and Firestore!'),
          ),
        );

        // Clear the selected image after upload
        setState(() {
          _selectedImage = null;
        });
      }
    } catch (e) {
      // Handle both Firebase and Firestore errors here
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    if (_auth.currentUser != null) {
      // Check if a user is signed in
      await _auth.signOut();

      // Sign out from Google as well
      await _googleSignIn.signOut();
      // Navigate back to the login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _processAndSetImage(File originalImage) async {
    try {
      final List<int> originalBytes = await originalImage.readAsBytes();
      final img.Image image =
          img.decodeImage(Uint8List.fromList(originalBytes))!;

      // Adjust the quality and dimensions based on your requirements
      final List<int> compressedBytes = img.encodeJpg(image, quality: 85);

      setState(() {
        _selectedImage = File(originalImage.path)
          ..writeAsBytesSync(compressedBytes);
      });
    } catch (e) {
      print("Error processing image: $e");
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (image != null) {
        await _processAndSetImage(File(image.path));
      }
    } catch (e) {
      print("Error capturing photo: $e");
    }
  }

  Future<List<String>> fetchEvents() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('events').get();

      return querySnapshot.docs
          .where((doc) => doc.data().containsKey('eventName'))
          .map((doc) => (doc.data()['eventName'] as String?) ?? "")
          .toList();
    } catch (e) {
      print("Error fetching events: $e");
      return [];
    }
  }

  // Future<List<String>> fetchUserEvents() async {
  //   try {
  //     //fetch user events
  //     final userId = _auth.currentUser?.uid;
  //     if (userId != null) {
  //       final querySnapshot = await FirebaseFirestore.instance
  //           .collection('users')
  //           .doc(userId)
  //           .collection('events')
  //           .get();

  //       return querySnapshot.docs
  //           .where((doc) => doc.data().containsKey('eventName'))
  //           .map((doc) => (doc.data()['eventName'] as String?) ?? "")
  //           .toList();
  //     } else {
  //       // User is not logged in or user ID is null
  //       return [];
  //     }
  //   } catch (e) {
  //     print("Error fetching user events: $e");
  //     return [];
  //   }
  // }
  Future<List<Map<String, dynamic>>> fetchUserEvents() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('events')
            .get();

        return querySnapshot.docs
            .where((doc) =>
                doc.data().containsKey('eventName') &&
                doc.data().containsKey('startDateTime') &&
                doc.data().containsKey('endDateTime'))
            .map((doc) => {
                  'eventName': doc.data()['eventName'] as String,
                  'startTime':
                      (doc.data()['startDateTime'] as Timestamp).toDate(),
                  'endTime': (doc.data()['endDateTime'] as Timestamp).toDate(),
                })
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching user events: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchParticipantEvents() async {
    try {
      final userBId = _auth.currentUser?.uid; // Current user (user B)
      if (userBId != null) {
        final eventsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('events')
            .where('participants', arrayContains: userBId)
            .get();

        List<Map<String, dynamic>> participantEvents = [];
        final currentTime = DateTime.now();

        for (final eventDoc in eventsSnapshot.docs) {
          final event = eventDoc.data();
          final organizerId = event['organizerUserId'];
          final eventName = event['eventName'] as String;
          final startTime = (event['startDateTime'] as Timestamp).toDate();
          final endTime = (event['endDateTime'] as Timestamp).toDate();

          print('Event start time: $startTime');
          print('Event end time: $endTime');
          // Check if the organizer is not the current user
          if (organizerId != null && organizerId != userBId) {
            participantEvents.add({
              'eventName': eventName,
              'startTime': startTime,
              'endTime': endTime,
            });
          }

          // Schedule ongoing event reminder for each event participated by the user

          if (currentTime.isBefore(endTime)) {
            _scheduleOngoingEventReminder(
              eventDoc.id,
              eventName,
              startTime,
              endTime,
              {
                'eventId': eventDoc.id,
                'eventName': eventName,
                'eventStartDate': startTime.toIso8601String(),
                'eventEndDate': endTime.toIso8601String(),
              },
            );

            _showEventInstantNotification(
              eventDoc.id,
              eventName,
              startTime,
              endTime,
              {
                'eventId': eventDoc.id,
                'eventName': eventName,
                'eventStartDate': startTime.toIso8601String(),
                'eventEndDate': endTime.toIso8601String(),
              },
            );
          }
        }

        print('Participant events: $participantEvents');
        return participantEvents;
      } else {
        print('User ID is null.');
        return [];
      }
    } catch (e) {
      print("Error fetching participant events: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchEventDetails(String eventId) async {
    try {
      final eventSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      return eventSnapshot.data() as Map<String, dynamic>? ?? {};
    } catch (e) {
      print("Error fetching event details: $e");
      return {};
    }
  }

  Future<void> _createEvent() async {
    String eventName = "";
    DateTime? startDateTime;
    DateTime? endDateTime;
    File? eventImage;

    // Show a dialog to get the event details from the user
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return EventForm(
          onEventDetailsEntered: (name, start, end, image) {
            eventName = name;
            startDateTime = start;
            endDateTime = end;
            eventImage = image;
          },
        );
      },
    );

    if (eventName.isNotEmpty && startDateTime != null && endDateTime != null) {
      await _createEventWithNameAndTime(
          eventName, startDateTime!, endDateTime!, eventImage);
      // ... (rest of your existing code for handling events)
    }
  }

  Future<void> _refreshData() async {
    // Implement your refresh logic here
    // For example, refetch data from API
    setState(() {
      // Update the UI after refreshing data
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Liviso"),
        actions: [
          // IconButton(
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => ScanCodePage()),
          //     );
          //   },
          //   icon: const Icon(Icons.qr_code_scanner_outlined),
          // ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome,',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _auth.currentUser != null
                        ? _auth.currentUser!.displayName ?? 'User'
                        : 'User',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // ListTile(
            //   title: Text('Toggle Dark Theme'),
            //   trailing: Switch(
            //     value: Theme.of(context).brightness == Brightness.dark,
            //     onChanged: (value) {
            //       final dynamicTheme = EasyDynamicTheme.of(context);
            //       if (dynamicTheme != null) {
            //         dynamicTheme.changeTheme();
            //       }
            //     },
            //   ),
            // ),
            ListTile(
              title: Text(
                'Terms and Conditions',
              ),
              onTap: () {
                // Add navigation to terms and conditions screen
              },
            ),
            ListTile(
              title: Text(
                'Privacy Policy',
              ),
              onTap: () {
                // Add navigation to privacy policy screen
              },
            ),
            const Divider(),
            ListTile(
              title: Text(
                'Sign Out',
              ),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Events Created Section
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Events Created',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchUserEvents(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else {
                        List<Map<String, dynamic>> userEvents =
                            snapshot.data ?? [];
                        if (userEvents.isEmpty) {
                          return SizedBox(
                            width: 350,
                            child: InkWell(
                              onTap:
                                  _createEvent, // Call _createEvent function on tap
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                padding: EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create your first event',
                                      style: TextStyle(
                                        fontSize: 20.0,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(height: 16.0),
                                    Text(
                                      'Click here to create an event',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: userEvents.length,
                          itemBuilder: (context, index) {
                            final event = userEvents[index];
                            return EventListTile(
                              eventName: event['eventName'],
                              eventStartDate: event['startTime'],
                              eventEndDate: event['endTime'],
                              onTap: () async {
                                final eventId =
                                    await _fetchEventIdFromFirestore(
                                        event['eventName']);
                                if (eventId != null) {
                                  _openEventDescriptionPage(
                                    eventName: event['eventName'],
                                    eventId: eventId,
                                    eventStartDate: event['startTime'],
                                    eventEndDate: event['endTime'],
                                    // Add other necessary parameters
                                  );
                                } else {
                                  print(
                                      'Event ID not found for ${event['eventName']}');
                                }
                              },
                            );
                          },
                        );
                      }
                    },
                  ),
                ],
              ),
              SizedBox(
                height: 30,
              ),
              // Events Participated Section
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Events Participated',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchParticipantEvents(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else {
                        List<Map<String, dynamic>> participantEvents =
                            snapshot.data ?? [];
                        if (participantEvents.isEmpty) {
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScanCodePage(
                                    onEventJoined: _updateEventList,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scan code to join events',
                                    style: TextStyle(
                                      fontSize: 20.0,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  SizedBox(height: 16.0),
                                  Text(
                                    'Click here to scan code and join events',
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: participantEvents.length,
                          itemBuilder: (context, index) {
                            final event = participantEvents[index];
                            return EventListTile(
                              eventName: event['eventName'],
                              eventStartDate: event['startTime'],
                              eventEndDate: event['endTime'],
                              onTap: () async {
                                final eventId =
                                    await _fetchEventIdForParticipantFromFirestore(
                                        event['eventName']);
                                if (eventId != null) {
                                  print(
                                      'Event ID found for ${event['eventName']}: $eventId');
                                  _openEventDescriptionPage(
                                    eventName: event['eventName'],
                                    eventId: eventId,
                                    eventStartDate: event['startTime'],
                                    eventEndDate: event['endTime'],
                                    // Add other necessary parameters
                                  );
                                } else {
                                  // Handle the case where event ID is not found
                                  print(
                                      'Event ID not found for ${event['eventName']}');
                                }
                              },
                            );
                          },
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Create Event',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            label: 'Scan QR',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }

  Future<String?> _fetchEventIdFromFirestore(String eventName) async {
    try {
      final userBId = _auth.currentUser?.uid;
      if (userBId != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userBId)
            .collection('events')
            .where('eventName', isEqualTo: eventName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final eventId = querySnapshot.docs.first.id;
          print('Event ID for $eventName: $eventId');
          return eventId;
        } else {
          print('Event ID not found for $eventName');
          return null;
        }
      } else {
        print('User ID is null.');
        return null;
      }
    } catch (e) {
      print("Error fetching event ID: $e");
      return null;
    }
  }

  Future<String?> _fetchEventIdForParticipantFromFirestore(
      String eventName) async {
    try {
      final userBId = _auth.currentUser?.uid;
      if (userBId != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('events') // Search across all users' events
            .where('eventName', isEqualTo: eventName)
            .where('participants', arrayContains: userBId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final eventId = querySnapshot.docs.first.id;
          print('Event ID for $eventName: $eventId');
          return eventId;
        } else {
          print('Event ID not found for $eventName');
          return null;
        }
      } else {
        print('User ID is null.');
        return null;
      }
    } catch (e) {
      print("Error fetching event ID: $e");
      return null;
    }
  }

  void _openEventDescriptionPage(
      {required String eventName,
      required String eventId,
      required DateTime eventStartDate,
      required DateTime eventEndDate}) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDescriptionPage(
          eventName: eventName,
          eventId: eventId,
          eventStartDate: eventStartDate,
          eventEndDate: eventEndDate,
        ),
      ),
    );
  }
}

class EventListTile extends StatelessWidget {
  final String eventName;
  final VoidCallback onTap;
  final DateTime eventStartDate;
  final DateTime eventEndDate;

  EventListTile(
      {required this.eventName,
      required this.onTap,
      required this.eventStartDate,
      required this.eventEndDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xff29404E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: EdgeInsets.only(left: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      eventName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Start Date: ${DateFormat('dd/MM/yyyy').format(eventStartDate)}\nEnd Date: ${DateFormat('dd/MM/yyyy').format(eventEndDate)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Image.asset(
                "assets/event_logo.png", // Add your asset path
                height: 100,
                width: 120,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

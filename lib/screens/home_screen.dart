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
          MaterialPageRoute(builder: (context) => ScanCodePage()),
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

  void _scheduleNotification(
    String eventId,
    String eventName,
    DateTime eventStartDateTime,
    DateTime eventEndDateTime,
    String notificationMessage,
  ) {
    // Calculate the time difference for scheduling the initial notification
    final Duration timeDifference =
        eventStartDateTime.difference(DateTime.now());

    // Create a notification content with event details
    final NotificationContent content = NotificationContent(
      id: eventId.hashCode,
      channelKey: 'basic_channel',
      title: eventName,
      body:
          '$notificationMessage\nStart Time: ${_formatDateTime(eventStartDateTime)}\nEnd Time: ${_formatDateTime(eventEndDateTime)}',
      payload: {
        'eventId': eventId,
      },
    );

    // Schedule the initial notification using awesome_notifications
    AwesomeNotifications().createNotification(
      content: content,
      schedule: NotificationInterval(interval: timeDifference.inSeconds),
    );
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

        // Create an event using the RemoteDataSource
        // final Event event = Event(
        //   id: eventId,
        //   creatorId: userId,
        //   attendeeIds: [userId],
        // );

        // Add the event to Firestore using RemoteDataSource
        // await _remoteDataSource.addEvent(event);

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

        // Show Snackbar after event creation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event created successfully!'),
          ),
        );

        // Navigate to the QR Code screen with the event ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QrCodeScreen(eventId: eventId),
          ),
        );
        // Show instant notification in the app
        _showInstantNotification(eventName, startDateTime, endDateTime);

        // Schedule additional notifications during the event
        // while (DateTime.now().isBefore(endDateTime)) {
        //   await Future.delayed(Duration(minutes: 30)); // Adjust delay as needed
        //   _scheduleNotification(
        //     eventId,
        //     eventName,
        //     startDateTime,
        //     endDateTime,
        //     'Event is ongoing!',
        //   );
        // }
      }
    } catch (e) {
      print("Error creating event: $e");
    }
  }

  void _showInstantNotification(
    String eventName,
    DateTime startDateTime,
    DateTime endDateTime,
  ) {
    // Display an instant notification in the app
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 0,
        channelKey:
            'basic_channel', // Make sure this key matches your channel setup
        title: eventName,
        body:
            'Start Time: ${_formatDateTime(startDateTime)}\nEnd Time: ${_formatDateTime(endDateTime)}',
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

  // Future<List<DocumentSnapshot>> fetchParticipantEvents() async {
  //   try {
  //     final userBId = _auth.currentUser?.uid; // Current user (user B)
  //     if (userBId != null) {
  //       final eventsSnapshot = await FirebaseFirestore.instance
  //           .collectionGroup('events')
  //           .where('participants', arrayContains: userBId)
  //           .get();

  //       print('Query snapshot length: ${eventsSnapshot.docs.length}');

  //       List<DocumentSnapshot> participantEvents = [];

  //       for (final eventDoc in eventsSnapshot.docs) {
  //         final event = eventDoc.data();
  //         final eventName = event['eventName'] as String;
  //         final organizerId = event['organizerUserId'];

  //         // Check if the organizer is not the current user
  //         if (organizerId != userBId) {
  //           participantEvents.add(eventDoc);
  //         }
  //       }

  //       print('Participant events: $participantEvents');
  //       return participantEvents;
  //     } else {
  //       print('User ID is null.');
  //       return [];
  //     }
  //   } catch (e) {
  //     print("Error fetching participant events: $e");
  //     return [];
  //   }
  // }

  Future<List<Map<String, dynamic>>> fetchParticipantEvents() async {
    try {
      final userBId = _auth.currentUser?.uid; // Current user (user B)
      if (userBId != null) {
        final eventsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('events')
            .where('participants', arrayContains: userBId)
            .get();

        List<Map<String, dynamic>> participantEvents = [];

        for (final eventDoc in eventsSnapshot.docs) {
          final event = eventDoc.data();
          final organizerId = event['organizerUserId'];
          final eventName = event['eventName'] as String;
          final startTime = (event['startDateTime'] as Timestamp).toDate();
          final endTime = (event['endDateTime'] as Timestamp).toDate();

          // Check if the organizer is not the current user
          if (organizerId != null && organizerId != userBId) {
            participantEvents.add({
              'eventName': eventName,
              'startTime': startTime,
              'endTime': endTime,
            });
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
            ListTile(
              title: Text('Toggle Dark Theme'),
              trailing: Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (value) {
                  final dynamicTheme = EasyDynamicTheme.of(context);
                  if (dynamicTheme != null) {
                    dynamicTheme.changeTheme();
                  }
                },
              ),
            ),
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
      body: SingleChildScrollView(
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
                        fontSize: 20,
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
                        return Center(
                          child: Text(
                            'Create your first event',
                            style: TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
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
                              final eventId = await _fetchEventIdFromFirestore(
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
                        fontSize: 20,
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
                        return Center(
                          child: Text(
                            'Scan code to join events',
                            style: TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
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
                "assets/sign_in.png", // Add your asset path
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

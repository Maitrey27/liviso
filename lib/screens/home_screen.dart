import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:liviso/screens/login_screen.dart';
import 'package:liviso/screens/photos_screen.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<String> _userPhotoUrls = [];
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserPhotoUrls();
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

  Future<void> _createEventWithName(String eventName) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Generate a unique event ID
        final String eventId = 'event_${DateTime.now().millisecondsSinceEpoch}';

        // Create an event in Firestore with the generated event ID
        await FirebaseFirestore.instance.collection('events').doc(eventId).set({
          'eventName': eventName,
          'organizerUserId': userId,
          'participants': [userId],
          'uploadedImageUrl': null, // Add this line to create the field
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
      }
    } catch (e) {
      print("Error creating event: $e");
    }
  }

  Future<void> _uploadImageToFirebase(String eventId) async {
    if (_selectedImage == null) {
      // No image selected, show a message or return early
      return;
    }

    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
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
      print("Error uploading image to Firebase: $e");
    }
  }

  Future<void> _signOut(BuildContext context) async {
    if (_auth.currentUser != null) {
      // Check if a user is signed in
      await _auth.signOut();
      // Navigate back to the login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print("Error capturing photo: $e");
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print("Error picking image from gallery: $e");
    }
  }

  Future<List<String>> fetchEvents() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('events').get();
      return querySnapshot.docs
          .map((doc) => doc['eventName'] as String)
          .toList();
    } catch (e) {
      print("Error fetching events: $e");
      return [];
    }
  }

  void _viewPhotos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotosScreen(userPhotoUrls: _userPhotoUrls),
      ),
    );
  }

  Future<void> _createEvent() async {
    String eventName = "";

    // Show a dialog to get the event name from the user
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create Event'),
          content: TextField(
            onChanged: (value) {
              eventName = value;
            },
            decoration: InputDecoration(
              hintText: 'Enter event name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Create the event before uploading the image
                await _createEventWithName(eventName);

                // Fetch the list of events from Firestore
                List<String> events = await fetchEvents();

                // Show a dialog to let the user choose the event
                String? selectedEvent = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    String? event;
                    return AlertDialog(
                      title: Text('Select Event'),
                      content: DropdownButtonFormField<String>(
                        value: event,
                        items: events.map((event) {
                          return DropdownMenuItem<String>(
                            value: event,
                            child: Text(event),
                          );
                        }).toList(),
                        onChanged: (value) {
                          event = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Choose an event',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, event);
                          },
                          child: Text('Upload'),
                        ),
                      ],
                    );
                  },
                );

                // Check if an event is selected before calling the image upload function
                if (selectedEvent != null) {
                  await _uploadImageToFirebase(selectedEvent);
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Click photos"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScanCodePage()),
              );
            },
            icon: const Icon(Icons.qr_code_scanner_outlined),
          ),
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
                    _auth.currentUser?.displayName ?? '',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedImage != null)
              Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _takePhoto,
              child: const Text('Take Photo'),
            ),
            ElevatedButton(
              onPressed: _pickImageFromGallery,
              child: const Text('Pick Image from Gallery'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Fetch the list of events from Firestore
                List<String> events = await fetchEvents();

                // Show a dialog to let the user choose the event
                String? selectedEvent = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    String? event;
                    return AlertDialog(
                      title: Text('Select Event'),
                      content: DropdownButtonFormField<String>(
                        value: event,
                        items: events.map((event) {
                          return DropdownMenuItem<String>(
                            value: event,
                            child: Text(event),
                          );
                        }).toList(),
                        onChanged: (value) {
                          event = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Choose an event',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, event);
                          },
                          child: Text('Upload'),
                        ),
                      ],
                    );
                  },
                );

                // Check if an event is selected before calling the image upload function
                if (selectedEvent != null) {
                  await _uploadImageToFirebase(selectedEvent);
                }
              },
              child: const Text('Upload Image '),
            ),
            ElevatedButton(
              onPressed: _viewPhotos,
              child: const Text('View Photos'),
            ),
            ElevatedButton(
              onPressed: _createEvent,
              child: const Text('Create Event'),
            ),
          ],
        ),
      ),
    );
  }
}

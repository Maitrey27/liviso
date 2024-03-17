import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:liviso/screens/photos_screen.dart';
import 'package:liviso/screens/preview_photo_screen.dart';
import 'package:liviso/screens/qr_code_screen.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class EventDescriptionPage extends StatefulWidget {
  final String eventName;
  final String eventId;
  final DateTime eventStartDate;
  final DateTime eventEndDate;

  EventDescriptionPage(
      {required this.eventName,
      required this.eventId,
      required this.eventStartDate,
      required this.eventEndDate});

  @override
  State<EventDescriptionPage> createState() => _EventDescriptionPageState();
}

class _EventDescriptionPageState extends State<EventDescriptionPage> {
  late String eventImageUrl = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  File? _selectedImage;
  List<String> _userPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    // Fetch event details, including eventImageUrl, from Firestore
    _fetchEventDetails();
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

  // Future<void> _fetchEventDetails() async {
  //   try {
  //     final DocumentSnapshot eventSnapshot = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(_auth.currentUser?.uid)
  //         .collection('events')
  //         .doc(widget.eventId)
  //         .get();

  //     setState(() {
  //       eventImageUrl = eventSnapshot['uploadedImageUrl'];
  //     });
  //   } catch (e) {
  //     print("Error fetching event details: $e");
  //   }
  // }

  Future<void> _fetchEventDetails() async {
    try {
      final eventName = widget.eventName;
      final userBId = _auth.currentUser?.uid;
      if (userBId != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('events') // Search across all users' events
            .where('eventName', isEqualTo: eventName)
            .where('participants', arrayContains: userBId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Fetch the event details for the first matching event
          final eventDoc = querySnapshot.docs.first;
          final event = eventDoc.data();
          final uploadedImageUrl = event['uploadedImageUrl'] ?? '';
          print('Uploaded Image URL for $eventName: $uploadedImageUrl');

          setState(() {
            eventImageUrl = uploadedImageUrl;
          });
        } else {
          setState(() {
            eventImageUrl = '';
          });
          print('No event found for $eventName');
        }
      } else {
        print('User ID is null.');
      }
    } catch (e) {
      print("Error fetching event details: $e");
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

        // Navigate to PreviewPhotosScreen with selected image
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewPhotosScreen(
              selectedImage: _selectedImage,
              eventId: widget.eventId,
            ),
          ),
        );
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

        // Navigate to PreviewPhotosScreen with selected image
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewPhotosScreen(
              selectedImage: _selectedImage,
              eventId: widget.eventId,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error picking image from gallery: $e");
    }
  }

  Future<void> _uploadImage() async {
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

        // Create a Firestore collection for event photos
        final CollectionReference eventPhotosCollection = FirebaseFirestore
            .instance
            .collection('events')
            .doc(widget.eventId)
            .collection('photos');

        // Add the uploaded image to Firestore
        await eventPhotosCollection.add({
          'userId': userId,
          'downloadURL': downloadURL,
          'timestamp': FieldValue.serverTimestamp(),
        });

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

        // Save updated user photo URLs to SharedPreferences
        await _saveUserPhotoUrls();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventName),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QrCodeScreen(eventId: widget.eventId),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (eventImageUrl.isNotEmpty)
              Image.network(
                eventImageUrl,
                height: 200.0,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            // Display a placeholder or an error message if the URL is empty or null
            if (eventImageUrl.isEmpty)
              Text(
                'No image available',
                style: TextStyle(fontSize: 16.0),
              ),
            SizedBox(height: 16.0),
            Text(
              'Event Details:',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Welcome to ${widget.eventName} Event!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),

            SizedBox(height: 16.0),
            Text(
              'Event Start Date: ${DateFormat('dd/MM/yyyy').format(widget.eventStartDate)}\nEvent End Date: ${DateFormat('dd/MM/yyyy').format(widget.eventEndDate)}',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 45.0),
            _buildActionButton('Pick from Gallery', Icons.photo_library, () {
              _pickImageFromGallery();
            }),
            SizedBox(height: 16.0),
            _buildActionButton('Take Photo', Icons.camera_alt, () {
              _takePhoto();
            }),
            SizedBox(height: 16.0),
            _buildActionButton('View Photos', Icons.photo, () {
              // View photos logic
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhotosScreen(
                    userPhotoUrls: _userPhotoUrls,
                    eventId: widget.eventId,
                    eventName: widget.eventName,
                  ),
                ),
              );
            }),
            // SizedBox(height: 16.0),
            // _buildActionButton('Upload Photo', Icons.cloud_upload, () {
            //   // Upload photo logic
            //   _uploadImage();
            // }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Color(0xff29404E),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32.0,
            ),
            SizedBox(width: 8.0),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

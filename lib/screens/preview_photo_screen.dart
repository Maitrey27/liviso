import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PreviewPhotosScreen extends StatelessWidget {
  final File? selectedImage;
  final String eventId;

  const PreviewPhotosScreen({
    Key? key,
    required this.selectedImage,
    required this.eventId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Photo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: selectedImage != null
                  ? Image.file(selectedImage!)
                  : Center(child: Text('No image selected')),
            ),
            SizedBox(height: 16.0),
            _buildButton(
              label: 'Upload Image',
              onPressed: () => _uploadImage(context),
            ),
            SizedBox(height: 16.0),
            _buildButton(
              label: 'Take Another Photo',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
      {required String label, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        primary: Color(0xff29404E), // Button color
        onPrimary: Colors.white, // Text color
        padding: EdgeInsets.all(16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _uploadImage(BuildContext context) async {
    if (selectedImage == null) {
      // No image selected, show a message or return early
      return;
    }

    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final FirebaseStorage storage = FirebaseStorage.instance;

      final String userId = auth.currentUser!.uid;

      // Create a user-specific folder in Firebase Storage
      final String userFolder = 'users/$userId';
      final String fileName = DateTime.now().toString();
      final Reference storageReference =
          storage.ref().child('$userFolder/images/$fileName.png');

      // Compress the image before uploading
      final Uint8List compressedImage = await _compressImage(selectedImage!);

      // Upload the compressed image to Firebase Storage
      final UploadTask uploadTask = storageReference.putData(compressedImage);
      final TaskSnapshot storageTask = await uploadTask.whenComplete(() {});

      // Get the download URL of the uploaded image
      final String downloadURL = await storageTask.ref.getDownloadURL();

      // Create a Firestore collection for event photos
      final CollectionReference eventPhotosCollection = FirebaseFirestore
          .instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .doc(eventId)
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
          content: Text('Image uploaded SuccessFully!'),
        ),
      );

      // Navigate back to EventDescriptionPage
      Navigator.pop(context);
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

  Future<Uint8List> _compressImage(File image) async {
    final List<int> imageBytes = await image.readAsBytes();
    final Uint8List uint8ImageBytes = Uint8List.fromList(imageBytes);
    final compressedImage = await FlutterImageCompress.compressWithList(
      uint8ImageBytes,
      minHeight: 1920,
      minWidth: 1080,
      quality: 90,
    );
    return Uint8List.fromList(compressedImage!);
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PreviewPhotosScreen extends StatelessWidget {
  final List<File> selectedImages;
  final String eventId;
  final Function(String) updatePhotoUrls;

  const PreviewPhotosScreen({
    Key? key,
    required this.selectedImages,
    required this.eventId,
    required this.updatePhotoUrls,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Photos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Check if only one image is selected
            selectedImages.length == 1
                ? Expanded(
                    child: Image.file(
                      selectedImages.first,
                      fit: BoxFit.cover,
                    ),
                  )
                : Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
                      ),
                      itemCount: selectedImages.length,
                      itemBuilder: (context, index) {
                        return Image.file(
                          selectedImages[index],
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
            SizedBox(height: 16.0),
            _buildButton(
              label: 'Upload Images',
              onPressed: () => _uploadImages(context),
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

  Future<void> _uploadImages(BuildContext context) async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final FirebaseStorage storage = FirebaseStorage.instance;
      final CollectionReference eventPhotosCollection = FirebaseFirestore
          .instance
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('events')
          .doc(eventId)
          .collection('photos');
      // Show uploading indicator
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Uploading Images'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16.0),
                Text('Please wait...'),
              ],
            ),
          );
        },
      );

      for (final image in selectedImages) {
        final String fileName =
            DateTime.now().millisecondsSinceEpoch.toString();
        final Reference storageReference = storage
            .ref()
            .child('users/${auth.currentUser!.uid}/images/$fileName.png');

        final Uint8List compressedImage = await _compressImage(image);

        final UploadTask uploadTask = storageReference.putData(compressedImage);
        final TaskSnapshot storageTask = await uploadTask.whenComplete(() {});

        final String downloadURL = await storageTask.ref.getDownloadURL();

        await eventPhotosCollection.add({
          'userId': auth.currentUser!.uid,
          'downloadURL': downloadURL,
          'timestamp': FieldValue.serverTimestamp(),
        });

        updatePhotoUrls(downloadURL);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black38,
          content: Text('Images uploaded successfully!',
              style: TextStyle(color: Colors.blue, fontSize: 16.0)),
        ),
      );

      Navigator.pop(context); // Navigate back to EventDescriptionPage
      Navigator.pop(context); // Navigate back to EventDescriptionPage
    } catch (e) {
      print("Error uploading images: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error uploading images: $e',
              style: TextStyle(color: Colors.blue, fontSize: 16.0)),
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

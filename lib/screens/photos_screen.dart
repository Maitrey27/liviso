import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'qr_code_screen.dart';

class PhotosScreen extends StatefulWidget {
  final List<String> userPhotoUrls;
  final String eventId;

  const PhotosScreen(
      {Key? key, required this.userPhotoUrls, required this.eventId})
      : super(key: key);

  @override
  _PhotosScreenState createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  FirebaseAuth _auth = FirebaseAuth.instance;
  // Create a controller for the QR code scanner
  final TextEditingController _qrCodeController = TextEditingController();

  // Create a link to handle dynamic links
  final FirebaseDynamicLinks _firebaseDynamicLinks =
      FirebaseDynamicLinks.instance;
  List<String> _userPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    _loadUserPhotoUrls(widget.eventId);
  }

  Future<void> _loadUserPhotoUrls(String eventId) async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        // Fetch URLs from Firestore
        final snapshot = await FirebaseFirestore.instance
            .collection('user_photos')
            .doc(eventId)
            .collection('photos')
            .orderBy('timestamp', descending: true)
            .get();

        final urls = snapshot.docs
            .map((doc) =>
                (doc.data() as Map<String, dynamic>)['downloadURL'].toString())
            .toList();

        setState(() {
          _userPhotoUrls = urls;
        });
      } catch (e) {
        print("Error loading user photo URLs: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Photos'),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // Adjust the number of columns as needed
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        itemCount: _userPhotoUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // Navigate to a full-screen view of the image
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FullScreenImage(url: _userPhotoUrls[index]),
                ),
              );
            },
            onLongPress: () {
              // Show options menu for each image
              _showOptions(context, _userPhotoUrls[index]);
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: CachedNetworkImage(
                imageUrl: _userPhotoUrls[index],
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOptions(BuildContext context, String imageUrl) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.download),
                title: Text('Download Image'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadImage(imageUrl);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete Image'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, imageUrl);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _downloadImage(String imageUrl) async {
    // Implement your download logic here
    Fluttertoast.showToast(
      msg: 'Downloading image...',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );

    // You can replace the following code with your own download logic using dio
    try {
      Dio dio = Dio();
      Response response = await dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Get the documents directory using path_provider
      final String documentsPath =
          (await getApplicationDocumentsDirectory()).path;

      // Create a subdirectory named 'downloads' within the documents directory
      final String downloadsPath = '$documentsPath/downloads';
      await Directory(downloadsPath).create(recursive: true);

      // Generate a unique file name for the downloaded image
      String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.png';
      String savePath = '$downloadsPath/$fileName';

      // Save the downloaded image to the 'downloads' subdirectory
      await File(savePath).writeAsBytes(response.data);

      // Open the downloaded image using the platform's file opener
      OpenFile.open(savePath);

      // Save the image to the phone's gallery
      await ImageGallerySaver.saveFile(savePath);

      Fluttertoast.showToast(
        msg: 'Image downloaded and saved to gallery successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      print("Error downloading image: $e");
      Fluttertoast.showToast(
        msg: 'Error downloading image. Please try again.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _confirmDelete(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Image'),
          content: Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteImage(imageUrl);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteImage(String imageUrl) async {
    // Check if the image URL exists in the list
    if (!_userPhotoUrls.contains(imageUrl)) {
      Fluttertoast.showToast(
        msg: 'Image does not exist.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      // Remove the image URL from the list
      setState(() {
        _userPhotoUrls.remove(imageUrl);
      });

      // Save the updated list to SharedPreferences
      await _saveUserPhotoUrls();

      // Delete the image information from Firestore
      final CollectionReference userPhotosCollection = FirebaseFirestore
          .instance
          .collection('user_photos')
          .doc(widget.eventId)
          .collection('photos');

      // Query Firestore to find the document with the specified downloadURL
      QuerySnapshot<Map<String, dynamic>> snapshot = await userPhotosCollection
          .where('downloadURL', isEqualTo: imageUrl)
          .get() as QuerySnapshot<Map<String, dynamic>>;

      if (snapshot.docs.isNotEmpty) {
        // Delete the document corresponding to the image URL
        await userPhotosCollection.doc(snapshot.docs.first.id).delete();
      }

      Fluttertoast.showToast(
        msg: 'Image deleted successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      print("Error deleting image: $e");
      Fluttertoast.showToast(
        msg: 'Error deleting image. Please try again.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _saveUserPhotoUrls() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(userId, widget.userPhotoUrls);
    }
  }
}

class FullScreenImage extends StatelessWidget {
  final String url;

  const FullScreenImage({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: GestureDetector(
          onTap: () {
            // Pop the screen when tapped
            Navigator.pop(context);
          },
          child: Image.network(url),
        ),
      ),
    );
  }
}

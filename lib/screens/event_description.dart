import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:liviso/screens/photos_screen.dart';
import 'package:liviso/screens/preview_photo_screen.dart';
import 'package:liviso/screens/qr_code_screen.dart';
import 'package:liviso/services/notifications_controller.dart';
import 'package:multiple_image_camera/camera_file.dart';
import 'package:multiple_image_camera/multiple_image_camera.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:multi_image_picker_plus/multi_image_picker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventDescriptionPage extends StatefulWidget {
  final String eventName;
  final String eventId;
  final DateTime eventStartDate;
  final DateTime eventEndDate;

  EventDescriptionPage({
    required this.eventName,
    required this.eventId,
    required this.eventStartDate,
    required this.eventEndDate,
  });

  @override
  State<EventDescriptionPage> createState() => _EventDescriptionPageState();
}

class _EventDescriptionPageState extends State<EventDescriptionPage> {
  late String eventImageUrl = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<File> _selectedImage = [];
  List<String> _userPhotoUrls = [];
  bool _isLoading = true; // Add loading indicator state

  @override
  void initState() {
    super.initState();
    // Fetch event details, including eventImageUrl, from Firestore
    _fetchEventDetails();
    _loadUserPhotoUrls();
    loadPhotos(widget.eventName, widget.eventId);
    NotificationController.startListeningNotificationEvents();
  }

  void _updatePhotoUrls(String photoUrl) {
    setState(() {
      _userPhotoUrls.add(photoUrl);
    });
  }

  Future<void> loadPhotos(String eventName, String eventId) async {
    try {
      setState(() {
        _isLoading = true;
      });
      final userBId = _auth.currentUser?.uid;
      if (userBId != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('events') // Search across all users' events
            .where('eventName', isEqualTo: eventName)
            .where('participants', arrayContains: userBId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final List<String> photoUrls = [];
          for (final doc in querySnapshot.docs) {
            final participants = doc.data()['participants'] as List<dynamic>;
            final eventId = doc.id;

            print('Fetching photos for event ID $eventId');

            final List<Future<QuerySnapshot>> futures = [];
            for (final participantId in participants) {
              print('Fetching photos for participant ID: $participantId');
              final future = FirebaseFirestore.instance
                  .collection('users')
                  .doc(participantId)
                  .collection('events')
                  .doc(eventId)
                  .collection('photos')
                  .get();
              futures.add(future);
            }

            final snapshots = await Future.wait(futures);
            for (final snapshot in snapshots) {
              final List<String> eventPhotoUrls = snapshot.docs
                  .map((photoDoc) {
                    final data = photoDoc.data();
                    if (data is Map<String, dynamic> &&
                        data.containsKey('downloadURL')) {
                      return data['downloadURL'] as String?;
                    } else {
                      return null;
                    }
                  })
                  .where((url) => url != null)
                  .cast<String>() // Cast to non-nullable String
                  .toList();

              photoUrls.addAll(eventPhotoUrls);
            }
          }

          print('Total photo URLs for event $eventId: $photoUrls');

          setState(() {
            _userPhotoUrls = photoUrls;
            _isLoading = false;
          });
        } else {
          print(
              'No event found for event ID: $eventId and event name: $eventName');
        }
      } else {
        print('User ID is null.');
      }
    } catch (e) {
      print("Error loading photos: $e");
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

  Future<void> _takePhotos() async {
    try {
      final List<MediaModel>? images = await MultipleImageCamera.capture(
        context: context,
      );

      if (images != null && images.isNotEmpty) {
        // Convert selected MediaModel objects to File objects
        final List<File> files =
            images.map((media) => File(media.file.path)).toList();

        // Navigate to PreviewPhotosScreen with selected images
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewPhotosScreen(
              selectedImages: files,
              eventId: widget.eventId,
              updatePhotoUrls: _updatePhotoUrls,
            ),
          ),
        );
      } else {
        // User canceled the selection
        print("User canceled image selection");
        // You can provide feedback to the user here if needed
      }
    } catch (e) {
      print("Error capturing photos: $e");
      // Handle error if necessary
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<Asset>? images = await MultiImagePicker.pickImages(
        iosOptions: IOSOptions(),
        androidOptions: AndroidOptions(
          maxImages: 10,
          actionBarColor: Color(0xff29404E),
          actionBarTitle: "Select Images",
          allViewTitle: "All Photos",
          useDetailsView: false,
          selectCircleStrokeColor: Theme.of(context).colorScheme.primary,
        ),
      );

      if (images != null && images.isNotEmpty) {
        // Convert selected Asset objects to File objects
        final List<File> files = await _convertAssetsToFiles(images);

        // Navigate to PreviewPhotosScreen with selected images
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewPhotosScreen(
              selectedImages: files,
              eventId: widget.eventId,
              updatePhotoUrls: _updatePhotoUrls,
            ),
          ),
        );
      } else {
        // User canceled the selection
        print("User canceled image selection");
        // You can provide feedback to the user here if needed
      }
    } catch (e) {
      print("Error picking images from gallery: $e");
      // Handle error if necessary
    }
  }

// Helper function to convert Asset   objects to File objects
  Future<List<File>> _convertAssetsToFiles(List<Asset> assets) async {
    final List<File> files = [];
    for (final Asset asset in assets) {
      final ByteData byteData = await asset.getByteData();
      final List<int> imageData = byteData.buffer.asUint8List();
      final File file =
          File('${(await getTemporaryDirectory()).path}/${asset.name}');
      await file.writeAsBytes(imageData);
      files.add(file);
    }
    return files;
  }

  // Future<void> _uploadImage() async {
  //   if (_selectedImage == null) {
  //     // No image selected, show a message or return early
  //     return;
  //   }

  //   try {
  //     final userId = _auth.currentUser?.uid;
  //     if (userId != null) {
  //       // Create a user-specific folder in Firebase Storage
  //       final String userFolder = 'users/$userId';
  //       final String fileName = DateTime.now().toString();
  //       final Reference storageReference =
  //           _storage.ref().child('$userFolder/images/$fileName.png');

  //       // Read the file as bytes
  //       final List<int> imageBytes = await _selectedImage!.readAsBytes();

  //       // Convert List<int> to Uint8List
  //       final Uint8List uint8ImageBytes = Uint8List.fromList(imageBytes);

  //       // Upload the bytes to Firebase Storage
  //       final TaskSnapshot storageTask =
  //           await storageReference.putData(uint8ImageBytes);
  //       final String downloadURL = await storageTask.ref.getDownloadURL();

  //       // Create a Firestore collection for event photos
  //       final CollectionReference eventPhotosCollection = FirebaseFirestore
  //           .instance
  //           .collection('events')
  //           .doc(widget.eventId)
  //           .collection('photos');

  //       // Add the uploaded image to Firestore
  //       await eventPhotosCollection.add({
  //         'userId': userId,
  //         'downloadURL': downloadURL,
  //         'timestamp': FieldValue.serverTimestamp(),
  //       });

  //       // Show Snackbar after successful upload
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Image uploaded to Firebase Storage and Firestore!'),
  //         ),
  //       );

  //       // Clear the selected image after upload
  //       setState(() {
  //         _selectedImage = null;
  //       });

  //       // Save updated user photo URLs to SharedPreferences
  //       await _saveUserPhotoUrls();
  //     }
  //   } catch (e) {
  //     // Handle both Firebase and Firestore errors here
  //     print("Error: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error: $e'),
  //       ),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Text(widget.eventName),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QrCodeScreen(
                    eventId: widget.eventId,
                    eventName: widget.eventName,
                  ),
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
            //Event name and details
            // Event name and details
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.0),
              ),
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.eventName,
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    'Duration: ${DateFormat('dd/MM/yyyy').format(widget.eventStartDate)} to ${DateFormat('dd/MM/yyyy').format(widget.eventEndDate)}',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.0),
            // Take photo and pick from gallery buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  'Use Gallery',
                  Icons.photo_library,
                  _pickImageFromGallery,
                  height: 60,
                  width: 150,
                ), // Use smaller button
                _buildActionButton('Take Photo', Icons.camera_alt, _takePhotos,
                    height: 60, width: 150),
              ],
            ),
            SizedBox(height: 24.0),
            // Display photos in a grid view
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4.0,
                      mainAxisSpacing: 4.0,
                    ),
                    itemCount: _userPhotoUrls.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FullScreenImage(url: _userPhotoUrls[index]),
                            ),
                          );
                        },
                        onLongPress: () {
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
                            errorWidget: (context, url, error) =>
                                Icon(Icons.error),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
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

  void _deleteImage(String imageUrl) async {
    try {
      // Remove the image URL from the list
      setState(() {
        _userPhotoUrls.remove(imageUrl);
      });

      // Save the updated list to SharedPreferences
      await _saveUserPhotoUrls();

      // Clear the cache for the deleted image
      await CachedNetworkImage.evictFromCache(imageUrl);

      // Delete the image from Firebase Storage
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();

      // Delete the corresponding document from Firestore
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('events')
              .doc(widget.eventId)
              .collection('photos')
              .where('downloadURL', isEqualTo: imageUrl)
              .get();

      if (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Update the UI to reflect the changes
      setState(() {});

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

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xff29404E),
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 22.0,
              ),
              SizedBox(width: 8.0),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

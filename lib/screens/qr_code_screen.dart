import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:liviso/screens/event_success_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class QrCodeScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  QrCodeScreen({required this.eventId, required this.eventName});

  @override
  _QrCodeScreenState createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  // Replace "https://liviso.page.link/6SuK" with your actual Dynamic Link
  late final String _dynamicLink;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey _qrCodeKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    final String dynamicLinkBase = "https://liviso.page.link/6SuK";
    final String userUid = _auth.currentUser?.uid ?? "";
    _dynamicLink = "$dynamicLinkBase?eventId=${widget.eventId}&userId=$userUid";
    // Call the _joinEvent function only if the app was opened via a dynamic link
    initDynamicLinks();
    _joinEvent();
  }

  Future<void> initDynamicLinks() async {
    try {
      final PendingDynamicLinkData? data =
          await FirebaseDynamicLinks.instance.getInitialLink();
      _handleDynamicLink(data);
    } catch (e) {
      print("Error getting initial dynamic link: $e");
    }

    FirebaseDynamicLinks.instance.onLink.listen(
      (PendingDynamicLinkData? dynamicLink) async {
        _handleDynamicLink(dynamicLink);
      },
      onError: (e) async {
        print("Error handling dynamic link: $e");
      },
    );
  }

  void _handleDynamicLink(PendingDynamicLinkData? data) {
    if (data != null && data.link != null) {
      // Check if the dynamic link contains the expected eventId
      final Uri uri = data.link!;
      final String eventId = uri.queryParameters['eventId'] ?? "";

      if (eventId == widget.eventId) {
        // The dynamic link contains the expected eventId, so call _joinEvent
        _joinEvent();
      }
    }
  }

  Future<void> _joinEvent() async {
    final userId = _auth.currentUser?.uid;

    if (userId != null) {
      try {
        final Uri uri = Uri.parse(_dynamicLink);
        final String eventId = uri.queryParameters['eventId'] ?? "";
        final String participantUid = uri.queryParameters['userId'] ?? "";

        print(
            "User ID: $userId, Event ID: $eventId, Participant UID: $participantUid");

        if (eventId.isNotEmpty &&
            participantUid.isNotEmpty &&
            participantUid == userId) {
          // Check if the user is already a participant
          final DocumentSnapshot eventDoc = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .get();

          if (eventDoc.exists) {
            final Map<String, dynamic>? eventData =
                eventDoc.data() as Map<String, dynamic>?;

            if (eventData != null) {
              final List<dynamic>? participants = eventData['participants'];

              if (participants != null && !participants.contains(userId)) {
                // Add the participant to the event's participants list
                await FirebaseFirestore.instance
                    .collection('events')
                    .doc(eventId)
                    .update({
                  'participants': FieldValue.arrayUnion([userId]),
                });
                print("User $userId joined the event $eventId successfully!");

                // Show a success message or navigate to a success screen
                // Navigate to a success screen or show a success dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventJoinSuccessScreen(),
                  ),
                );
              } else if (participants != null &&
                  participants.contains(userId)) {
                // User is already a participant
                print("User is already a participant in this event");
              } else {
                // Handle the case where 'participants' is null or eventId is not found
                print("Invalid event document for eventId: $eventId");
              }
            } else {
              // Handle the case where 'eventData' is null
              print("Invalid event document for eventId: $eventId");
            }
          } else {
            // Handle the case where the QR code is valid, but the event document doesn't exist
            print("Event document does not exist for eventId: $eventId");
          }
        } else {
          // Handle the case where the QR code is invalid or doesn't match the user
          print("Invalid QR code");
        }
      } catch (e) {
        print("Error joining event: $e");
      }
    }
  }

  Future<void> _launchURL() async {
    final fallbackURL =
        "https://drive.google.com/drive/folders/1P7PO2HYCqZs-KJkc1NDwcF7oM_Rkx73R?usp=sharing"; // Provide your installation link
    if (await canLaunch(_dynamicLink)) {
      await launch(_dynamicLink);
    } else {
      await launch(fallbackURL);
    }
  }

  Future<void> _shareQRCode() async {
    try {
      // Capture the QR code image using ScreenshotController
      final imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        // Save the QR code image to a temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/qr_code_image.png';
        final imageFile = File(tempFilePath);
        await imageFile.writeAsBytes(imageBytes);

        // Check if the file exists before sharing
        final bool exists = await imageFile.exists();

        if (exists) {
          // Share the QR code image along with the text
          await Share.shareFiles(
            [tempFilePath],
            text:
                'Join the event "${widget.eventName}" by scanning this QR code!',
            subject: 'Event QR Code',
            // You can also provide a subject for email applications
          );
        } else {
          print('Image file does not exist at path: $tempFilePath');
        }
      } else {
        print('Failed to capture QR code image.');
      }
    } catch (e) {
      print('Error sharing QR code: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: theme.primaryColor,
        title: Text('Generate QR Code'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              _shareQRCode();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              // Use Flexible widget to allow text to wrap
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'SCAN THE QR TO JOIN THE EVENT ${widget.eventName}',
                  textAlign: TextAlign.center, // Align text to center
                  style: TextStyle(
                    fontSize: 20.0,
                    fontStyle: FontStyle.italic,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Screenshot(
              controller: _screenshotController,
              child: Container(
                color: Theme.of(context).backgroundColor,
                padding: EdgeInsets.all(20.0),
                child: QrImageView(
                  data: _dynamicLink,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  size: 250.0,
                  key: _qrCodeKey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

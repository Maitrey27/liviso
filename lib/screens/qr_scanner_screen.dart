import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScanCodePage extends StatefulWidget {
  const ScanCodePage({Key? key}) : super(key: key);

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              returnImage: true,
            ),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                print('Barcode found! ${barcode.rawValue}');
                _fetchEventNameAndShowDialogFromUrl(barcode.rawValue);
              }
            },
          ),
        ],
      ),
    );
  }

  void _fetchEventNameAndShowDialogFromUrl(String? url) {
    try {
      if (url != null && url.isNotEmpty) {
        final Uri uri = Uri.parse(url);
        final String? eventId = uri.queryParameters['eventId'];
        final String? userId = uri.queryParameters['userId'];

        if (eventId != null &&
            eventId.isNotEmpty &&
            userId != null &&
            userId.isNotEmpty) {
          _fetchEventNameAndShowDialog(eventId, userId);
        } else {
          print('Event ID or User ID not found in URL: $url');
        }
      } else {
        print('Invalid URL');
      }
    } catch (e) {
      print("Error parsing URL: $e");
    }
  }

  void _fetchEventNameAndShowDialog(String eventId, String userId) async {
    try {
      // Fetch event name from Firestore using the eventId
      final DocumentSnapshot eventSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .doc(eventId)
          .get();

      if (eventSnapshot.exists) {
        final Map<String, dynamic> eventData =
            eventSnapshot.data() as Map<String, dynamic>;
        final String eventName = eventData['eventName'];

        // Show dialog to join the event
        _showJoinEventDialog(eventName, eventId, userId);
      } else {
        print("Event not found with ID: $eventId");
      }
    } catch (e) {
      print("Error fetching event details: $e");
    }
  }

  void _showJoinEventDialog(String eventName, String eventId, String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Join Event"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Do you want to join the event \"$eventName\"?"),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _joinEvent(eventId, userId);
                      Navigator.pop(context); // Close the dialog
                    },
                    child: Text('Join'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
                    },
                    child: Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _joinEvent(String eventId, String userId) async {
    final currentUserUid = _auth.currentUser?.uid;

    if (currentUserUid != null) {
      try {
        // Add the current user's ID to the event's participants list
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('events')
            .doc(eventId)
            .update({
          'participants': FieldValue.arrayUnion([currentUserUid]),
        });

        print("User $currentUserUid joined the event $eventId successfully!");
      } catch (e) {
        print("Error joining event: $e");
      }
    } else {
      print("Error: Current user ID is null");
    }
  }
}

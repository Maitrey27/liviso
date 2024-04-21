import 'dart:async';
import 'dart:typed_data';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:liviso/screens/event_description.dart';
import 'package:liviso/services/notifications_controller.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScanCodePage extends StatefulWidget {
  final VoidCallback onEventJoined;
  const ScanCodePage({Key? key, required this.onEventJoined}) : super(key: key);
  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  void initState() {
    // TODO: implement initState
    NotificationController.initializeLocalNotifications();
    NotificationController.startListeningNotificationEvents();
    super.initState();
  }

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
                      _joinEvent(eventId, userId, eventName, () {
                        Navigator.pop(context); // Close the dialog
                        Navigator.pop(context); // Pop back to previous screen
                      });
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

  void _showInstantNotification(
      String eventName, Map<String, dynamic> payload) {
    // Display an instant notification in the app
    final Map<String, String?> stringPayload = payload.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final content = NotificationContent(
      id: 0,
      channelKey: 'basic_channel',
      title: 'Event Joined',
      body: 'You joined the event $eventName',
      payload: stringPayload,
    );

    AwesomeNotifications().createNotification(
      content: content,
    );
  }

  Future<void> _joinEvent(String eventId, String userId, String eventName,
      VoidCallback callback) async {
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
        callback();
        // Show the "Event joined" snackbar
        // Call the callback function to update the state
        widget.onEventJoined();
        showEventJoinedSnackbar(eventName);
        // Send an instant notification to the user
        final Map<String, dynamic> payload = {
          'eventName': eventName,
          'eventId': eventId,
        };
        _showInstantNotification(eventName, payload);
      } catch (e) {
        print("Error joining event: $e");
      }
    } else {
      print("Error: Current user ID is null");
    }
  }

  void showEventJoinedSnackbar(String eventName) {
    final snackBar = SnackBar(
      elevation: 8.0,
      backgroundColor: Color.fromARGB(255, 0, 0, 0),
      content: Container(
        height: 50,
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8.0),
            Flexible(
              child: Text(
                'You joined the event $eventName successfully!',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16.0,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 4),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

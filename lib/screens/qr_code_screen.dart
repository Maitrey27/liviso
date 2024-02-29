import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeScreen extends StatefulWidget {
  final String eventId;

  QrCodeScreen({required this.eventId});
  @override
  _QrCodeScreenState createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  // Replace "https://liviso.page.link/photos" with your actual Dynamic Link
  late final String _dynamicLink;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    final String dynamicLinkBase = "https://liviso.page.link/6SuK";
    _dynamicLink = "$dynamicLinkBase?eventId=${widget.eventId}";
    _joinEvent();
  }

  Future<void> _joinEvent() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      // Add the participant to the event's participants list
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
        'participants': FieldValue.arrayUnion([userId]),
      });

      // Show a success message or navigate to a success screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined the event successfully!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate QR Code'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: QrImageView(
                data: _dynamicLink,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "This QR code leads to: $_dynamicLink",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // Import the services package
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:liviso/screens/qr_code_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
              final Uint8List? image = capture.image;
              for (final barcode in barcodes) {
                print('Barcode found! ${barcode.rawValue}');
                _showQRCodeDialog(
                    barcode.rawValue); // Show dialog with QR code details
              }
              if (image != null) {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(
                        barcodes.first.rawValue ?? "",
                      ),
                      content: InkWell(
                        onTap: () {
                          _showQRCodeDialog(barcodes.first.rawValue);
                        },
                        child: Image(
                          image: MemoryImage(image),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: ElevatedButton(
              onPressed: () async {
                final userId = _auth.currentUser?.uid;
                if (userId != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QrCodeScreen(eventId: userId),
                    ),
                  );
                } else {}
              },
              child: Text('Generate QR Code'),
            ),
          ),
        ],
      ),
    );
  }

  // Function to show the QR code details and provide options to copy or open URL
  void _showQRCodeDialog(String? url) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("QR Code Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CachedNetworkImage(
                // Use CachedNetworkImage instead of Image.network
                imageUrl: url ?? '',
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
              SizedBox(height: 16),
              SelectableText(
                url ?? '',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.copy),
                    onPressed: () {
                      _copyToClipboard(url);
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.open_in_browser),
                    onPressed: () {
                      _launchURL(url);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchURL(String? url) async {
    if (url != null && await canLaunch(url)) {
      await launch(url, forceSafariVC: false, forceWebView: false);
    } else {
      print('Could not launch $url');
    }
  }

  // Function to copy text to clipboard
  void _copyToClipboard(String? text) {
    Clipboard.setData(ClipboardData(text: text ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('URL copied to clipboard'),
    ));
  }
}

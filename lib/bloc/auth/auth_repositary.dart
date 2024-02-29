// auth_repository.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:liviso/models/event_model.dart';

// class AuthRepository {
//   final FirebaseStorage _storage = FirebaseStorage.instance;

//   Future<void> submitEventDetails(Event event, List<File> photos) async {
//     try {
//       // Create a folder in Firebase Storage with the event name
//       final eventFolderReference =
//           _storage.ref().child('events/${event.eventName}');

//       // Upload each photo to the event folder
//       for (int i = 0; i < photos.length; i++) {
//         final photoReference = eventFolderReference.child('photo_$i.png');
//         await photoReference.putFile(photos[i]);
//       }
//     } catch (e) {
//       print('Error submitting event details: $e');
//       rethrow;
//     }
//   }
// }

class AuthRepository {
  // Your existing code...

  Future<void> submitEventDetails(Event event) async {
    try {
      // Process the event details, submit to the repository, or perform any other actions
      // For example, you can print the event details:
      print('Event Name: ${event.eventName}');
      print('Event DateTime: ${event.eventDateTime}');

      // Add your logic here to handle the event details submission
    } catch (e) {
      print('Error submitting event details: $e');
      rethrow;
    }
  }
}

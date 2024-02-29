// event_model.dart
import 'dart:io';

class Event {
  final String eventName;
  final DateTime eventDateTime;
  // final List<File> photos;

  Event({
    required this.eventName,
    required this.eventDateTime,
    // required this.photos,
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Event {
  const Event({
    required this.id,
    required this.creatorId,
    required this.attendeeIds,
  });

  Event.fromMap(Map<String, dynamic> map)
      : id = map['id'] as String,
        creatorId = map['creatorId'] as String,
        attendeeIds = (map['attendeeIds'] as List<dynamic>).cast<String>();

  final String id;
  final String creatorId;
  final List<String> attendeeIds;

  Event copyWith({
    String? id,
    String? creatorId,
    List<String>? attendeeIds,
  }) {
    return Event(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      attendeeIds: attendeeIds ?? this.attendeeIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'attendeeIds': attendeeIds,
    };
  }
}

class RemoteDataSource {
  RemoteDataSource({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> addEvent(Event event) async {
    final eventRef = _firestore
        .collection('users')
        .doc(event.creatorId)
        .collection('events')
        .doc();
    await eventRef.set(event.copyWith(id: eventRef.id).toMap());
  }

  Future<void> inviteUser({
    required String attendeeId,
    required Event event,
  }) async {
    await _firestore
        .collection('users')
        .doc(attendeeId)
        .collection('invites')
        .add(event.copyWith(attendeeIds: []).toMap());

    await _firestore
        .collection('users')
        .doc(event.creatorId)
        .collection('events')
        .doc(event.id)
        .update({
      'attendeeIds': FieldValue.arrayUnion([attendeeId]),
    });
  }

  Future<List<Event>> getEvents() async {
    final events = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('events')
        .get();
    return events.docs.map((e) => Event.fromMap(e.data())).toList();
  }

  Future<List<Event>> getInvites() async {
    final invites = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('invites')
        .get();
    return invites.docs.map((e) => Event.fromMap(e.data())).toList();
  }

  Future<String> getUsername(String userId) async {
    final user = await _firestore.collection('users').doc(userId).get();
    return user.data()!['username'] as String;
  }
}

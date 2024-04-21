// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:liviso/screens/event_description.dart';

// class EventList extends StatefulWidget {
//   @override
//   _EventListState createState() => _EventListState();
// }

// class _EventListState extends State<EventList> {
//   late Future<List<EventData>> _eventsFuture;

//   @override
//   void initState() {
//     super.initState();
//     _eventsFuture = fetchEvents();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Events List'),
//       ),
//       body: FutureBuilder<List<EventData>>(
//         future: _eventsFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text('No events found.'));
//           } else {
//             final events = snapshot.data!;

//             return ListView.builder(
//               itemCount: events.length,
//               itemBuilder: (context, index) {
//                 final eventData = events[index];

//                 return Padding(
//                   padding:
//                       const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//                   child: GestureDetector(
//                     onTap: () {
//                       // Navigate to the event description screen
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => EventDescription(
//                             eventId: eventData.eventId,
//                             eventName: eventData.eventName,
//                             startDateTime: eventData.startDateTime,
//                             endDateTime: eventData.endDateTime,
//                           ),
//                         ),
//                       );
//                     },
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(12),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.grey.withOpacity(0.5),
//                             spreadRadius: 1,
//                             blurRadius: 5,
//                             offset: Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: ListTile(
//                         contentPadding: EdgeInsets.all(8),
//                         leading: eventData.imageUrl != null
//                             ? ClipRRect(
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: Image.network(
//                                   eventData.imageUrl!,
//                                   width: 60,
//                                   height: 60,
//                                   fit: BoxFit.cover,
//                                 ),
//                               )
//                             : Container(
//                                 width: 60,
//                                 height: 60,
//                                 color: Colors.grey[200],
//                                 child: Icon(
//                                   Icons.event,
//                                   size: 30,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                         title: Text(
//                           eventData.eventName,
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             SizedBox(height: 4),
//                             Text(
//                               'Start: ${_formatDateTime(eventData.startDateTime)}',
//                               style: TextStyle(fontSize: 14),
//                             ),
//                             SizedBox(height: 2),
//                             Text(
//                               'End: ${_formatDateTime(eventData.endDateTime)}',
//                               style: TextStyle(fontSize: 14),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             );
//           }
//         },
//       ),
//     );
//   }

//   String _formatDateTime(DateTime? dateTime) {
//     return dateTime != null
//         ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}'
//         : 'Unknown';
//   }

//   Future<List<EventData>> fetchEvents() async {
//     try {
//       final querySnapshot =
//           await FirebaseFirestore.instance.collection('events').get();

//       return querySnapshot.docs
//           .where((doc) => doc.data().containsKey('eventName'))
//           .map((doc) {
//         return EventData(
//           eventId: doc.id,
//           eventName: (doc.data()['eventName'] as String?) ?? "",
//           startDateTime: doc.data()['startDateTime']?.toDate() as DateTime?,
//           endDateTime: doc.data()['endDateTime']?.toDate() as DateTime?,
//           imageUrl: doc.data()['imageUrl'] as String?,
//         );
//       }).toList();
//     } catch (e) {
//       print("Error fetching events: $e");
//       return [];
//     }
//   }
// }

// class EventData {
//   final String eventId;
//   final String eventName;
//   final DateTime? startDateTime;
//   final DateTime? endDateTime;
//   final String? imageUrl;

//   EventData({
//     required this.eventId,
//     required this.eventName,
//     required this.startDateTime,
//     required this.endDateTime,
//     required this.imageUrl,
//   });
// }


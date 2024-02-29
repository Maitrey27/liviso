import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liviso/bloc/auth/auth_bloc.dart';
import 'package:liviso/models/event_model.dart';
import 'package:liviso/screens/home_screen.dart';

class EventForm extends StatefulWidget {
  @override
  _EventFormState createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _eventNameController = TextEditingController();
  DateTime _eventDateTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _eventNameController,
              decoration: InputDecoration(labelText: 'Event Name'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: Text('Select Event Date'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _selectTime(context),
              child: Text('Select Event Time'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submitEvent(context),
              child: Text('Create Event'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _eventDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _eventDateTime) {
      setState(() {
        _eventDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _eventDateTime.hour,
          _eventDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventDateTime),
    );

    if (pickedTime != null) {
      setState(() {
        _eventDateTime = DateTime(
          _eventDateTime.year,
          _eventDateTime.month,
          _eventDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _submitEvent(BuildContext context) {
    final eventName = _eventNameController.text;
    if (eventName.isNotEmpty) {
      final event = Event(eventName: eventName, eventDateTime: _eventDateTime);
      context.read<AuthBloc>().add(EventDetailsSubmitted(event: event));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EventForm extends StatefulWidget {
  final Function(String, DateTime, DateTime, File?) onEventDetailsEntered;

  const EventForm({Key? key, required this.onEventDetailsEntered})
      : super(key: key);

  @override
  _EventFormState createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final TextEditingController _eventNameController = TextEditingController();
  DateTime? _selectedStartDateTime;
  DateTime? _selectedEndDateTime;
  File? _selectedImage;

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDateTime(
    BuildContext context,
    bool isStartDateTime,
  ) async {
    DateTime? pickedDateTime = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDateTime != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime selectedDateTime = DateTime(
          pickedDateTime.year,
          pickedDateTime.month,
          pickedDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isStartDateTime) {
            _selectedStartDateTime = selectedDateTime;
          } else {
            _selectedEndDateTime = selectedDateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          // title: Text('Create Event'),
          ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GestureDetector(
            //   onTap: _pickImageFromGallery,
            //   child: Container(
            //     width: double.infinity,
            //     height: 200,
            //     decoration: BoxDecoration(
            //       // color: Colors.grey[200],
            //       color: Color(0xff29404E),
            //       borderRadius: BorderRadius.circular(8),
            //     ),
            //     child: _selectedImage != null
            //         ? ClipRRect(
            //             borderRadius: BorderRadius.circular(8),
            //             child: Image.file(
            //               _selectedImage!,
            //               fit: BoxFit.cover,
            //             ),
            //           )
            //         : Column(
            //             mainAxisAlignment: MainAxisAlignment.center,
            //             children: [
            //               Icon(
            //                 Icons.add_a_photo_outlined,
            //                 size: 42,
            //                 color: Colors.white,
            //               ),
            //               SizedBox(
            //                 height: 8,
            //               ),
            //               Text(
            //                 "Add Event Image",
            //                 style: TextStyle(
            //                   color: Colors.white,
            //                   fontWeight: FontWeight.w600,
            //                 ),
            //               )
            //             ],
            //           ),
            //   ),
            // ),
            SizedBox(height: 16),
            Text(
              'Create an Event',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _eventNameController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.note_alt_outlined),
                labelText: 'Event Name',
              ),
            ),
            SizedBox(height: 15),
            InkWell(
              onTap: () async {
                await _selectDateTime(context, true);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today),
                  labelText: 'Start Date and Time',
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: _selectedStartDateTime != null
                    ? Text(
                        '${_selectedStartDateTime!.day}/${_selectedStartDateTime!.month}/${_selectedStartDateTime!.year} '
                        '${_selectedStartDateTime!.hour}:${_selectedStartDateTime!.minute}',
                      )
                    : Text('Pick Start Date and Time'),
              ),
            ),
            SizedBox(height: 15),
            InkWell(
              onTap: () async {
                await _selectDateTime(context, false);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today),
                  labelText: 'End Date and Time',
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: _selectedEndDateTime != null
                    ? Text(
                        '${_selectedEndDateTime!.day}/${_selectedEndDateTime!.month}/${_selectedEndDateTime!.year} '
                        '${_selectedEndDateTime!.hour}:${_selectedEndDateTime!.minute}',
                      )
                    : Text('Pick End Date and Time'),
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_eventNameController.text.isNotEmpty &&
                      _selectedStartDateTime != null &&
                      _selectedEndDateTime != null) {
                    widget.onEventDetailsEntered(
                      _eventNameController.text,
                      _selectedStartDateTime!,
                      _selectedEndDateTime!,
                      _selectedImage,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Color(0xff29404E)),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  minimumSize: MaterialStateProperty.all(const Size(500, 50)),
                  textStyle:
                      MaterialStateProperty.all(const TextStyle(fontSize: 18)),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                child: Text('Create Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

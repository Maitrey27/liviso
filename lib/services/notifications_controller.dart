import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:liviso/main.dart';
import 'package:liviso/screens/event_description.dart';
import 'package:liviso/screens/home_screen.dart';

class NotificationController {
  static ReceivedAction? initialAction;
  static Future<void> initializeLocalNotifications() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelGroupKey: 'basic_channel',
          channelKey: 'basic_channel',
          channelName: 'Basic notifications',
          channelDescription: 'Notification channel for basic notifications',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          playSound: true,
          enableVibration: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'basic_channel',
          channelGroupName: 'Group 1',
        )
      ],
      debug: true,
    );
    initialAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: false);
  }

  static Future<void> startListeningNotificationEvents() async {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  /// Use this method to detect when a new notification or a schedule is created
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint('onNotificationCreatedMethod');
  }

  /// Use this method to detect every time that a new notification is displayed
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint('onNotificationDisplayedMethod');
  }

  /// Use this method to detect if the user dismissed a notification
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint('onDismissActionReceivedMethod');
  }

  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    final Map<String, dynamic>? payload = receivedAction.payload;
    debugPrint('onActionReceivedMethod');
    final String? buttonKey = receivedAction.buttonKeyInput;

    debugPrint('Button Key: $buttonKey');
    debugPrint('Payload: $payload');

    if (buttonKey == null ||
        buttonKey.isEmpty ||
        buttonKey == 'OPEN_EVENT_DETAILS') {
      if (payload != null) {
        debugPrint('Opening Event Description Page...');
        final String? eventName = payload['eventName'];
        final String? eventId = payload['eventId'];
        final String? eventStartDateString = payload['eventStartDate'];
        final String? eventEndDateString = payload['eventEndDate'];

        if (eventName != null &&
            eventId != null &&
            eventStartDateString != null &&
            eventEndDateString != null) {
          debugPrint('Event Name: $eventName');
          debugPrint('Event ID: $eventId');
          debugPrint('Event Start Date: $eventStartDateString');
          debugPrint('Event End Date: $eventEndDateString');

          final DateTime eventStartDate = DateTime.parse(eventStartDateString);
          final DateTime eventEndDate = DateTime.parse(eventEndDateString);

          debugPrint('Parsed Event Start Date: $eventStartDate');
          debugPrint('Parsed Event End Date: $eventEndDate');

          if (MyApp.navigatorKey.currentState != null) {
            debugPrint('Navigating to Event Description Page...');
            MyApp.navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (context) => EventDescriptionPage(
                  eventName: eventName,
                  eventId: eventId,
                  eventStartDate: eventStartDate,
                  eventEndDate: eventEndDate,
                ),
              ),
            );
          } else {
            debugPrint('Navigator Key is null or currentState is null.');
            runApp(MaterialApp(
              home: HomeScreen(),
            ));
          }
        } else {
          debugPrint('Missing or invalid data in payload.');
        }
      } else {
        debugPrint('Payload is null.');
      }
    } else {
      debugPrint('Button key is not "OPEN_EVENT_DETAILS".');
    }
  }
}

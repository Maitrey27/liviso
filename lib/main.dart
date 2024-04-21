import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liviso/bloc/auth/auth_bloc.dart';
import 'package:liviso/screens/home_screen.dart';
import 'package:liviso/screens/login_screen.dart';
import 'package:liviso/screens/qr_code_screen.dart';
import 'package:liviso/services/notifications_controller.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  User? user = FirebaseAuth.instance.currentUser;
  tz.initializeTimeZones();
  await NotificationController.initializeLocalNotifications();

  // Check notification permissions
  bool isPermissionGranted =
      await AwesomeNotifications().isNotificationAllowed();

  if (!isPermissionGranted) {
    // Request notification permissions
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }
  // Call the handleDynamicLink function here
  await handleDynamicLink();

  runApp(MyApp(user: user));
}

// Function to handle dynamic link and add participant
Future<void> handleDynamicLink() async {
  FirebaseDynamicLinks.instance.onLink.listen(
    (PendingDynamicLinkData? dynamicLink) async {
      Uri? deepLink = dynamicLink?.link;
      if (deepLink != null) {
        // Extract event ID and user ID from the deep link
        String eventId = deepLink.queryParameters['eventId'] ?? '';
        String userId = deepLink.queryParameters['userId'] ?? '';

        // Add the user as a participant to the event
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('participants')
            .doc(userId)
            .set({'userId': userId});

        // Do any additional processing if needed
      }
    },
    onError: (e) async {
      print('Error handling dynamic link: ${e.message}');
    },
  );
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  final User? user;
  const MyApp({
    Key? key,
    this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Liviso App',
      theme: ThemeData.dark(),
      navigatorKey: navigatorKey,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(),
          ),
        ],
        child: user == null ? LoginScreen() : HomeScreen(),
      ),
    );
  }
}

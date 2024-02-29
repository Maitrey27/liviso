// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBZ-cNSzAO4OEcwPsC4ZSPgHbsq9pzyXQs',
    appId: '1:732277022211:web:42f06dfdff26376bcff836',
    messagingSenderId: '732277022211',
    projectId: 'livisoapp',
    authDomain: 'livisoapp.firebaseapp.com',
    storageBucket: 'livisoapp.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCN-D29gRPq6BpCB58NODLY3MKhWf74VU',
    appId: '1:732277022211:android:db2ac385a5630218cff836',
    messagingSenderId: '732277022211',
    projectId: 'livisoapp',
    storageBucket: 'livisoapp.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAE5AviXASbQN8XyWbub0t8qy-lGYFr3SY',
    appId: '1:732277022211:ios:f899a19d0cfc2b2acff836',
    messagingSenderId: '732277022211',
    projectId: 'livisoapp',
    storageBucket: 'livisoapp.appspot.com',
    iosBundleId: 'com.example.liviso',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAE5AviXASbQN8XyWbub0t8qy-lGYFr3SY',
    appId: '1:732277022211:ios:33568ed3a28e3147cff836',
    messagingSenderId: '732277022211',
    projectId: 'livisoapp',
    storageBucket: 'livisoapp.appspot.com',
    iosBundleId: 'com.example.liviso.RunnerTests',
  );
}

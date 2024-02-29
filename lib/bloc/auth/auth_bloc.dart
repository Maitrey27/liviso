// auth_bloc.dart
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:liviso/bloc/auth/auth_repositary.dart';
import 'package:liviso/models/event_model.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AuthRepository _authRepository = AuthRepository();

  AuthBloc() : super(AuthInitial());

  @override
  AuthState get initialState => AuthInitial();

  @override
  Stream<AuthState> mapEventToState(AuthEvent event) async* {
    if (event is SignInWithGoogle) {
      yield* _mapSignInWithGoogleToState();
    } else if (event is SignInWithEmailAndPassword) {
      yield* _mapSignInWithEmailAndPasswordToState(
        event.email,
        event.password,
      );
    } else if (event is SignUpWithEmailAndPassword) {
      yield* _mapSignUpWithEmailAndPasswordToState(
        event.email,
        event.password,
      );
    } else if (event is SignOut) {
      yield* _mapSignOutToState();
    } else if (event is EventDetailsSubmitted) {
      yield* _mapEventDetailsSubmittedToState(event);
    }
  }

  Stream<AuthState> _mapSignInWithGoogleToState() async* {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the Google sign-in
        yield AuthFailed("Google sign-in cancelled.");
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);

      if (_auth.currentUser != null) {
        yield AuthAuthenticated(_auth.currentUser!);
      } else {
        yield AuthFailed("Failed to sign in with Google.");
      }
    } catch (e) {
      yield AuthFailed("Error: $e");
    }
  }

  Stream<AuthState> _mapSignInWithEmailAndPasswordToState(
      String email, String password) async* {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (_auth.currentUser != null) {
        yield AuthAuthenticated(_auth.currentUser!);
      } else {
        yield AuthFailed("Failed to sign in with email and password.");
      }
    } catch (e) {
      yield AuthFailed("Error: $e");
    }
  }

  Stream<AuthState> _mapSignUpWithEmailAndPasswordToState(
      String email, String password) async* {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (_auth.currentUser != null) {
        yield AuthAuthenticated(_auth.currentUser!);
      } else {
        yield AuthFailed("Failed to sign up with email and password.");
      }
    } catch (e) {
      yield AuthFailed("Error: $e");
    }
  }

  Stream<AuthState> _mapSignOutToState() async* {
    try {
      await _auth.signOut();
      yield AuthInitial();
    } catch (e) {
      yield AuthFailed("Error: $e");
    }
  }

  // Stream<AuthState> _mapEventDetailsSubmittedToState(
  //   EventDetailsSubmitted event,
  // ) async* {
  //   try {
  //     // Pass the required 'photos' argument when creating an instance of 'Event'
  //     Event newEvent = Event(
  //       eventName: event.event.eventName,
  //       eventDateTime: event.event.eventDateTime,
  //       // photos: event.photos,
  //     );

  //     // Submit event details to the repository
  //     // await _authRepository.submitEventDetails(newEvent);

  //     // Emit a success state or any other state as needed
  //     yield AuthAuthenticated(_auth.currentUser!);
  //   } catch (e) {
  //     // Handle errors and emit a failure state
  //     print('Error in _mapEventDetailsSubmittedToState: $e');
  //     yield AuthFailed("Error: $e");
  //   }
  // }
  Stream<AuthState> _mapEventDetailsSubmittedToState(
    EventDetailsSubmitted event,
  ) async* {
    try {
      // Process the event details or submit to the repository if needed
      // For example:
      await _authRepository.submitEventDetails(event.event);

      // You can emit a different state if required
      yield AuthAuthenticated(_auth.currentUser!);
    } catch (e) {
      yield AuthFailed("Error: $e");
    }
  }
}

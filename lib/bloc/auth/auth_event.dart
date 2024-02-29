// auth_event.dart
part of 'auth_bloc.dart';

@immutable
abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class SignInWithGoogle extends AuthEvent {}

class SignInWithEmailAndPassword extends AuthEvent {
  final String email;
  final String password;

  SignInWithEmailAndPassword({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class SignUpWithEmailAndPassword extends AuthEvent {
  final String email;
  final String password;

  SignUpWithEmailAndPassword({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class SignOut extends AuthEvent {}

class EventDetailsSubmitted extends AuthEvent {
  final Event event;
  // final List<File> photos;

  EventDetailsSubmitted({required this.event});

  @override
  List<Object> get props => [event];
}

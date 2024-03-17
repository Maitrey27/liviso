// signup_screen.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liviso/bloc/auth/auth_bloc.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image(
                  height: 200,
                  width: 200,
                  image: AssetImage("assets/sign_in.png"),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              SignUpForm(),
            ],
          ),
        ),
      ),
    );
  }
}
// signup_form.dart

// signup_form.dart

class SignUpForm extends StatefulWidget {
  const SignUpForm({Key? key}) : super(key: key);

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  XFile? _selectedImage;

  String? _validatePassword() {
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _signUpWithEmailAndPassword() async {
    final String? passwordError = _validatePassword();
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passwordError),
        ),
      );
      return;
    }

    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = credential.user!.uid;

      // Update user display name and other information
      await credential.user!.updateProfile(
        displayName: _nameController.text,
        photoURL: null, // Set the photoURL if needed
      );

      // Send email verification
      await credential.user!.sendEmailVerification();

      // Store additional user details in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'username': _nameController.text,
        'email': _emailController.text.trim(),
        // Add more fields as needed
      });

      // Show a message to inform the user to check their email for verification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Verification email sent. Please check your email to verify your account.'),
        ),
      );

      // Navigate back to login screen
      Navigator.pop(context);
    } catch (e) {
      // Handle sign-up errors
      print("Error: $e");
      // You can show an error message to the user here
    }
  }

  // Future<String> uploadProfileImage(String userId, XFile image) async {
  //   final storage = FirebaseStorage.instance;
  //   final reference = storage.ref().child('profile_images/$userId');
  //   final task = reference.putFile(File(image.path));
  //   final snapshot = await task.whenComplete(() => null);
  //   final url = await reference.getDownloadURL();
  //   return url;
  // }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // const SizedBox(height: 10),
              Text(
                'SignUp',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
                child: TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
                child: TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUpWithEmailAndPassword,
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  minimumSize: MaterialStateProperty.all(const Size(500, 50)),
                  textStyle: MaterialStateProperty.all(
                    const TextStyle(fontSize: 18),
                  ),
                ),
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

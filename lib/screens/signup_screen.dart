// signup_screen.dart

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
      if (_selectedImage != null) {
        final imageUrl = await uploadProfileImage(userId, _selectedImage!);
        // Update user profile with image URL
        await credential.user!.updateProfile(photoURL: imageUrl);
      }

      // Navigate back to login screen
      Navigator.pop(context);
    } catch (e) {
      // Handle sign-up errors
      print("Error: $e");
      // You can show an error message to the user here
    }
  }

  Future<String> uploadProfileImage(String userId, XFile image) async {
    final storage = FirebaseStorage.instance;
    final reference = storage.ref().child('profile_images/$userId');
    final task = reference.putFile(File(image.path));
    final snapshot = await task.whenComplete(() => null);
    final url = await reference.getDownloadURL();
    return url;
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedImage != null)
                CircleAvatar(
                  backgroundImage: FileImage(File(_selectedImage!.path)),
                  radius: 50,
                )
              else
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Icon(
                      Icons.person_2_outlined,
                      color: Colors.grey[800],
                    ),
                    radius: 50,
                  ),
                ),
              SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Confirm Password'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUpWithEmailAndPassword,
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

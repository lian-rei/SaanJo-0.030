import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saanjologin/widgets/my_checkbox.dart';
import 'package:saanjologin/widgets/my_textfield.dart';
import 'package:saanjologin/widgets/my_checkbox.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isTermsAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create an Account'),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo2.png', height: 250,
            ),
            const SizedBox(height: 10),
            MyTextfield(
              controller: _firstNameController,
              hintText: 'First Name: ',
              obscureText: false,
            ),
            const SizedBox(height: 10),
            MyTextfield(
              controller: _lastNameController,
              hintText: 'Last Name: ',
              obscureText: false,
            ),
            const SizedBox(height: 10),
            MyTextfield(
              controller: _usernameController,
              hintText: 'Username: ',
              obscureText: false,
            ),
            const SizedBox(height: 10),
            MyTextfield(
              controller: _emailController,
              hintText: 'Email: ',
              obscureText: false,
            ),
            const SizedBox(height: 10),
            MyTextfield(
              controller: _passwordController,
              hintText: 'Password: ',
              obscureText: true,
            ),
            const SizedBox(height: 10),
            MyTextfield(
              controller: _confirmPasswordController,
              hintText: 'Confirm Password: ',
              obscureText: true,
            ),


            const SizedBox(height: 16.0),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomCheckbox(
                  isChecked: _isTermsAccepted,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _isTermsAccepted = newValue ?? false;
                    });
                  },
                ),
                const SizedBox(width: 8.0),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms and Conditions Clicked'),
                      ),
                    );
                  },
                  child: const Text(
                    "I agree to the Terms and Conditions",
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16.0),

            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Register'),
            ),

            const SizedBox(height: 16.0),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Already have an account? Login here.'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept the terms to register')),
      );
      return;
    }

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields must be filled')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        // Save user data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'username': _usernameController.text,
          'email': _emailController.text,
        });

        await user.updateDisplayName('${_firstNameController.text} ${_lastNameController.text}');
        await user.reload();
      }

      Navigator.pop(context); // Go back to login page or other page
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'An error occurred')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }
}

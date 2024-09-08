import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:saanjologin/widgets/my_button.dart';
import 'package:saanjologin/widgets/square_tile.dart';
import 'package:saanjologin/pages/map_page.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // LOGO
          Image.asset('assets/logo2.png', height: 250),

          const SizedBox(height: 50),

          // Welcome to Saan Jo!
          Text(
            'Welcome to Saan Jo!',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 25),

          // Email TextField
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),

          const SizedBox(height: 10),

          // Password TextField
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),

          const SizedBox(height: 10),

         

          const SizedBox(height: 25),

          // Sign in button
          MyButton(
            onTap: _isLoading ? null : _login,
          ),

          const SizedBox(height: 50),

          // Or continue with
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    thickness: 0.5,
                    color: Colors.grey[400],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Text(
                    'Or continue with',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                Expanded(
                  child: Divider(
                    thickness: 0.5,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),

          // Google sign in button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SquareTile(
                imagePath: 'assets/apple.png',
                onTap: _isLoading ? null : _signInWithGoogle,
              ),
              SizedBox(width: 25),
              SquareTile(
                imagePath: 'assets/Google.png',
                onTap: _isLoading ? null : _signInWithGoogle,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Navigation buttons
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Don\'t have an account? Register here.'),
          ),

          const SizedBox(height: 5.0),

          TextButton(
            onPressed: _continueAsGuest,
            child: const Text('Continue as Guest'),
          ),

          const SizedBox(height: 5.0),

          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/developer_dashboard');
            },
            child: const Text('Go to Developer Dashboard'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        Navigator.pushNamed(context, '/map_page');
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      Navigator.pushNamed(context, '/map_page');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'An error occurred')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _continueAsGuest() {
    Navigator.pushNamed(context, '/map_page');
  }
}

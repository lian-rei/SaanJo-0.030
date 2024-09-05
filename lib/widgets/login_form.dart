import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:saanjologin/widgets/my_button.dart';
import 'package:saanjologin/widgets/my_textfield.dart';
import 'package:saanjologin/widgets/square_tile.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void SignUserIn() {}

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(0, 255, 255, 255),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          //LOGO
          Image.asset(
            'assets/logo2.png', height: 250,),

            const SizedBox(height: 50),

          //Welcome to Saan Jo!
          Text('Welcome to Saan Jo!',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize:16,
            ),
          ),

          const SizedBox(height: 25),

          MyTextfield(
            controller: _usernameController,
            hintText: 'Username: ',
            obscureText: false,
          ),

          const SizedBox(height: 10),

            //Password (TF)
            MyTextfield(
              controller: _passwordController,
              hintText: 'Password:',
              obscureText: true,
            ),

            const SizedBox(height: 10),

            //Forgot Password?
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            //Sign in button
            MyButton(
              onTap: SignUserIn,
            ),

            const SizedBox(height: 50),
            //or continue with
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

            //google + apple sign in buttons
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SquareTile(imagePath: 'assets/apple.png'),

                SizedBox(width: 25),

                SquareTile(imagePath: 'assets/Google.png'),
              ],
            ),

            const SizedBox(height: 50),
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'components/button.dart';
import 'components/textfield.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  static const String routeName = '/register';

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  // Register user with Firebase
  Future<void> registerUser(BuildContext context) async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      showError("Fields cannot be empty");
      return;
    }

    if (password != confirmPassword) {
      showError("Passwords do not match");
      return;
    }

    try {
      setState(() => isLoading = true);

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Navigate to login page after successful registration
      Navigator.pushNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      showError(e.message ?? "Registration failed. Try again.");
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                Image.asset(
                  'assets/images/WellMate.png',
                  height: 100,
                  width: 100,
                ),
                const SizedBox(height: 50),
                Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 23,
                  ),
                ),
                const SizedBox(height: 25),
                MyTextField(
                  controller: emailController,
                  hintText: 'Email',
                  obscureText: false,
                ),
                const SizedBox(height: 10),
                MyTextField(
                  controller: passwordController,
                  hintText: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                MyTextField(
                  controller: confirmPasswordController,
                  hintText: 'Confirm Password',
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                MyButton(
                  onTap: () => registerUser(context),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/login'),
                      child: const Text(
                        'Login now',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
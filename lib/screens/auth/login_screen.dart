import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../widgets/auth_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<String?> _getEmailFromUsername(String username) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['email'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final input = _emailOrUsernameController.text.trim();
      final password = _passwordController.text.trim();
      var email = input;

      if (!input.contains('@')) {
        final fetchedEmail = await _getEmailFromUsername(input);
        if (fetchedEmail == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No user found with that username',
          );
        }
        email = fetchedEmail;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = 'Incorrect password. Please try again.';
          break;
        case 'user-not-found':
          msg = 'No account found with these credentials.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'too-many-requests':
          msg = 'Too many failed attempts. Try again later.';
          break;
        default:
          msg = e.message ?? 'Login failed.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      icon: Icons.lock_open_rounded,
      title: 'Welcome Back',
      subtitle: 'Sign in with email or username',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailOrUsernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email or Username',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter email or username';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
      footer: [
        TextButton(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.forgotPassword),
          child: const Text('Forgot Password?'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.signup),
          child: const Text('Create Account'),
        ),
      ],
    );
  }
}

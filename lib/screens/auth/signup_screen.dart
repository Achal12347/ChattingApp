import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../app_routes.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  /// ✅ Email domain checker (with fallback)
  Future<bool> _checkEmailDomain(String email) async {
    try {
      final domain = email.split('@').last;
      final response = await http
          .get(Uri.parse("https://dns.google/resolve?name=$domain&type=MX"))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["Answer"] != null && data["Answer"].isNotEmpty;
      }
    } catch (e) {
      debugPrint("Domain check failed: $e");
    }
    return true; // fallback: allow if DNS check fails
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final username = _usernameController.text.trim().toLowerCase();
      final email = _emailController.text.trim();

      // ✅ Step 1: Check email domain
      if (!await _checkEmailDomain(email)) {
        _showMessage("❌ Invalid email domain. Please use a real email.");
        if (mounted) setState(() => _loading = false);
        return;
      }

      // ✅ Step 2: Check if username exists (case-insensitive)
      final usernameCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        _showMessage("❌ Username already taken");
        if (mounted) setState(() => _loading = false);
        return;
      }

      // ✅ Step 3: Check if email exists
      final emailCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailCheck.docs.isNotEmpty) {
        _showMessage("❌ Email already exists. Try logging in.");
        if (mounted) setState(() => _loading = false);
        return;
      }

      // ✅ Step 4: Create Firebase Auth user
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // ✅ Step 5: Save user in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'fullName': _fullNameController.text.trim(),
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'weak-password':
          msg = "Password is too weak.";
          break;
        case 'email-already-in-use':
          msg = "This email is already registered.";
          break;
        case 'invalid-email':
          msg = "Invalid email format.";
          break;
        default:
          msg = e.message ?? "Signup failed.";
      }
      _showMessage("❌ $msg");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _boxDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    bool obscure = false,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _boxDecoration(label, icon: icon),
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _fullNameController,
                        label: "Full Name",
                        icon: Icons.person,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Please enter your full name";
                          }
                          if (v.length < 3) {
                            return "Full name must be at least 3 characters";
                          }
                          if (v.length > 50) {
                            return "Full name cannot exceed 50 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _usernameController,
                        label: "Username",
                        icon: Icons.account_circle,
                        validator: (v) =>
                            v!.isEmpty ? "Please choose a username" : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: "Email",
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Please enter an email";
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                            return "Invalid email format";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _passwordController,
                        label: "Password",
                        obscure: true,
                        icon: Icons.lock,
                        validator: (v) => v != null && v.length < 6
                            ? "Password must be at least 6 characters"
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: "Confirm Password",
                        obscure: true,
                        icon: Icons.lock_outline,
                        validator: (v) => v != _passwordController.text
                            ? "Passwords do not match"
                            : null,
                      ),
                      const SizedBox(height: 32),
                      _loading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _signup,
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, AppRoutes.login),
                        child: const Text("Already have an account? Login"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

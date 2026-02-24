import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_routes.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  void _getStarted() async {
    final prefs = await SharedPreferences.getInstance();
    // You can mark onboarding as not seen yet
    prefs.setBool('onboarding_seen', false);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              isWeb
                  ? 'assets/images/welcome/welcome_web.png'
                  : 'assets/images/welcome/welcome_mobile.png',
              fit: BoxFit.cover,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: ElevatedButton(
                onPressed: _getStarted,
                child: const Text('Get Started'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

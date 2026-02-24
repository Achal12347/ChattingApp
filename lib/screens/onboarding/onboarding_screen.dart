import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'imageMobile': 'assets/images/onboarding/mobile/onboard1_mobile.png',
      'imageWeb': 'assets/images/onboarding/web/onboard1_web.png',
    },
    {
      'imageMobile': 'assets/images/onboarding/mobile/onboard2_mobile.png',
      'imageWeb': 'assets/images/onboarding/web/onboard2_web.png',
    },
    {
      'imageMobile': 'assets/images/onboarding/mobile/onboard3_mobile.png',
      'imageWeb': 'assets/images/onboarding/web/onboard3_web.png',
    },
    {
      'imageMobile': 'assets/images/onboarding/mobile/onboard4_mobile.png',
      'imageWeb': 'assets/images/onboarding/web/onboard4_web.png',
    },
  ];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoSlide();
    });
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < _slides.length - 1) {
        _currentPage++;
        _controller.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _skip() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _next() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Image.asset(
                isWeb ? slide['imageWeb']! : slide['imageMobile']!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              );
            },
          ),
          // Skip Button on first page
          if (_currentPage == 0)
            Positioned(
              top: 50,
              right: 20,
              child: ElevatedButton(
                onPressed: _skip,
                child: const Text('Skip'),
              ),
            ),
          // Next Button on last page
          if (_currentPage == _slides.length - 1)
            Positioned(
              bottom: 50,
              right: 20,
              child: ElevatedButton(
                onPressed: _next,
                child: const Text('Next'),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jol_app/screens/auth/services/deep_link_service.dart';
import 'auth/services/auth_services.dart';
import 'bnb/home_screen.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Initialize Deep Link Service after binding
    Get.find<DeepLinkService>().init();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait 3 seconds for splash screen display
    await Future.delayed(const Duration(seconds: 3));

    // Check if user is already logged in
    final isLoggedIn = await _authService.isAuthenticated();

    if (!mounted) return;

    if (isLoggedIn) {
      // User is logged in, go to HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // User is not logged in, go to OnboardingScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  // Updated colors based on your palette
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFC42AF8);

  static const double logoFontSize = 40;

  TextSpan _coloredLetter(String letter, int index) {
    final colors = [textBlue, textGreen, textPink];
    return TextSpan(
      text: letter,
      style: TextStyle(
        color: colors[index % 3],
        fontSize: logoFontSize,
        fontWeight: FontWeight.w500,
        fontFamily: 'Digitalt',
        letterSpacing: logoFontSize * 0.04,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jol = <TextSpan>[
      _coloredLetter('J', 0),
      _coloredLetter('O', 1),
      _coloredLetter('L', 2),
    ];

    final puzzles = <TextSpan>[
      _coloredLetter('P', 3),
      _coloredLetter('U', 4),
      _coloredLetter('Z', 5),
      _coloredLetter('Z', 6),
      _coloredLetter('L', 7),
      _coloredLetter('E', 8),
      _coloredLetter('S', 9),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFC0CB),
              Color(0xFFADD8E6),
              Color(0xFFE6E6FA),
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'lib/assets/images/logo.png',
                    height: 100,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(text: TextSpan(children: jol)),
                      const SizedBox(height: 4),
                      RichText(text: TextSpan(children: puzzles)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: const Text(
                'Must Try...!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Aleo',
                  fontWeight: FontWeight.w400,
                  fontSize: 20,
                  height: 1.0,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jol_app/screens/auth/controllers/auth_controller.dart';

class ResetPasswordConfirmScreen extends StatefulWidget {
  const ResetPasswordConfirmScreen({super.key});

  @override
  State<ResetPasswordConfirmScreen> createState() =>
      _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState
    extends State<ResetPasswordConfirmScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final _p1Controller = TextEditingController();
  final _p2Controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? uid;
  String? token;

  // Colors
  static const Color headerPink = Color(0xFFF82A87);
  static const Color accentPink = Color(0xFFC42AF8);

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args != null && args is Map) {
      uid = args['uid'];
      token = args['token'];
    }
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (uid == null || token == null) {
        Get.snackbar(
            "Error", "Invalid link. Please try resetting your password again.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      _authController.confirmPasswordReset(
          uid!, token!, _p1Controller.text, _p2Controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFC0CB), // light pink
              Color(0xFFADD8E6), // light blue
              Color(0xFFE6E6FA), // lavender
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "RESET PASSWORD",
                    style: TextStyle(
                      fontFamily: 'Digitalt',
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: headerPink,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Enter your new password below",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Digitalt',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // New Password
                  TextFormField(
                    controller: _p1Controller,
                    obscureText: true,
                    style: const TextStyle(
                        fontFamily: 'Digitalt', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "NEW PASSWORD",
                      labelStyle: const TextStyle(
                          color: accentPink, fontFamily: 'Digitalt'),
                      prefixIcon: const Icon(Icons.lock, color: accentPink),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: accentPink, width: 2)),
                    ),
                    validator: (val) => (val == null || val.length < 6)
                        ? "Minimum 6 characters"
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextFormField(
                    controller: _p2Controller,
                    obscureText: true,
                    style: const TextStyle(
                        fontFamily: 'Digitalt', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "CONFIRM PASSWORD",
                      labelStyle: const TextStyle(
                          color: accentPink, fontFamily: 'Digitalt'),
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: accentPink),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: accentPink, width: 2)),
                    ),
                    validator: (val) {
                      if (val != _p1Controller.text)
                        return "Passwords do not match";
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  Obx(() => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPink,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed:
                            _authController.isLoading.value ? null : _submit,
                        child: _authController.isLoading.value
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                "RESET PASSWORD",
                                style: TextStyle(
                                  fontFamily: 'Digitalt',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

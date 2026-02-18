import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jol_app/screens/auth/controllers/auth_controller.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthController _authController = Get.find<AuthController>();

  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  final _c4 = TextEditingController();

  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _f3 = FocusNode();
  final _f4 = FocusNode();

  // Colors
  static const Color headerPink = Color(0xFFF82A87);
  static const Color accentPink = Color(0xFFC42AF8);

  bool _isAutoVerifying = false;

  @override
  void initState() {
    super.initState();
    // Check if we came from a deep link
    final key = Get.arguments?['key'];
    if (key != null) {
      _verifyWithKey(key);
    }
  }

  Future<void> _verifyWithKey(String key) async {
    setState(() => _isAutoVerifying = true);
    final success = await _authController.verifyEmail(key);
    if (success) {
      // Navigate to login or home
      // Get.offAllNamed(AppRoutes.login); // AuthController might handle user state
      // For now, stay here to show success or let user navigate manually
    }
    setState(() => _isAutoVerifying = false);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _c4.dispose();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    _f4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          child: Stack(
            children: [
              if (_isAutoVerifying)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: headerPink),
                      SizedBox(height: 16),
                      Text("Verifying Email...",
                          style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontSize: 18,
                              color: headerPink)),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    const SizedBox(height: 40),

                    // Title
                    const Text(
                      "VERIFY EMAIL",
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: headerPink,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          Text(
                            "ENTER 4 DIGIT OTP CODE SENT TO YOUR",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: headerPink,
                            ),
                          ),
                          Text(
                            Get.arguments?['email'] ?? "YOUR EMAIL",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // OTP fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _otpBox(_c1, _f1, nextFocus: _f2),
                        const SizedBox(width: 12),
                        _otpBox(_c2, _f2, prevFocus: _f1, nextFocus: _f3),
                        const SizedBox(width: 12),
                        _otpBox(_c3, _f3, prevFocus: _f2, nextFocus: _f4),
                        const SizedBox(width: 12),
                        _otpBox(_c4, _f4, prevFocus: _f3),
                      ],
                    ),
                  ],
                ),

              // Bottom area: Submit button and Resend text
              if (!_isAutoVerifying)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Column(
                    children: [
                      // Submit
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Obx(() => ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentPink,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _authController.isLoading.value
                                  ? null
                                  : () {
                                      final otp = _c1.text +
                                          _c2.text +
                                          _c3.text +
                                          _c4.text;
                                      if (otp.length == 4) {
                                        // Assuming the OTP is the key if manually entered
                                        // Or there might be a different endpoint for numeric OTP.
                                        // For now, we assume the user might paste a key or the backend supports OTP.
                                        // If OTP is not supported, this might fail, but for now we wire it to verifyEmail
                                        _authController.verifyEmail(otp);
                                      } else {
                                        Get.snackbar(
                                            "Error", "Please enter 4 digits",
                                            backgroundColor: Colors.orange,
                                            colorText: Colors.white);
                                      }
                                    },
                              child: _authController.isLoading.value
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      "SUBMIT",
                                      style: TextStyle(
                                        fontFamily: 'Digitalt',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            )),
                      ),
                      const SizedBox(height: 14),

                      // Resend row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "DIDN’T RECEIVE A CODE?",
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              // TODO: Implement resend logic
                              Get.snackbar("Info", "Resend feature coming soon",
                                  backgroundColor: Colors.blue,
                                  colorText: Colors.white);
                            },
                            child: const Text(
                              "RESEND",
                              style: TextStyle(
                                fontFamily: 'Digitalt',
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: accentPink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // OTP box with auto-advance and backspace handling.
  Widget _otpBox(
    TextEditingController controller,
    FocusNode focusNode, {
    FocusNode? nextFocus,
    FocusNode? prevFocus,
  }) {
    return SizedBox(
      width: 60,
      child: RawKeyboardListener(
        focusNode: FocusNode(), // dedicated listener node
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty &&
              prevFocus != null) {
            FocusScope.of(context).requestFocus(prevFocus);
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType
              .text, // Changed to text to allow potential alphanumeric keys if needed
          maxLength: 1,
          style: const TextStyle(
            fontFamily: 'Digitalt',
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            counterText: "",
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: accentPink, width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: accentPink, width: 1.8),
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (nextFocus != null) {
                FocusScope.of(context).requestFocus(nextFocus);
              } else {
                focusNode.unfocus();
              }
            }
          },
          onTap: () {
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          },
        ),
      ),
    );
  }
}

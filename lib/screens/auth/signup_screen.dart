import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jol_app/screens/auth/controllers/auth_controller.dart';
import 'package:jol_app/screens/auth/login_screen.dart';
import 'package:jol_app/utils/app_routes.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFC42AF8);
  static const Color accentPink = Color(0xFFF82A87);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // final AuthService _authService = AuthService(); // Removed, using AuthController
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        height: double.infinity,
        width: double.infinity,
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
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                const Text(
                  'CREATE NEW ACCOUNT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Digitalt',
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: SignupScreen.accentPink,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 35),

                // Username
                _inputField(
                  icon: Icons.person_pin_circle_outlined,
                  hint: "USERNAME",
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),

                // Email
                _inputField(
                  icon: Icons.email_outlined,
                  hint: "EMAIL",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),

                // Password
                _inputField(
                  icon: Icons.lock_outline,
                  hint: "PASSWORD",
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  toggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 18),

                // Confirm Password
                _inputField(
                  icon: Icons.lock_reset_outlined,
                  hint: "CONFIRM PASSWORD",
                  controller: _confirmPasswordController,
                  obscure: _obscureConfirmPassword,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  toggleObscure: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                const SizedBox(height: 20),

                // Terms text
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "BY CONTINUING TO USE SALSIVO, YOU AGREE WITH THE JOLPUZZLE TERMS AND PRIVACY NOTICE.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Digitalt',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Register button with shadow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: SignupScreen.textPink.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SignupScreen.textPink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            "REGISTER",
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // OR Divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            thickness: 1.2,
                            color: SignupScreen.textPink.withOpacity(0.4))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: SignupScreen.textPink,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            thickness: 1.2,
                            color: SignupScreen.textPink.withOpacity(0.4))),
                  ],
                ),
                const SizedBox(height: 24),

                // Google Signup Button
                _socialButton(
                  text: _isGoogleLoading
                      ? "SIGNING UP..."
                      : "CONTINUE WITH GOOGLE",
                  icon: Image.asset("lib/assets/images/google.png", height: 22),
                  onTap: _isGoogleLoading ? null : _handleGoogleSignup,
                ),
                const SizedBox(height: 20),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "ALREADY HAVE AN ACCOUNT?",
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        "SIGN IN",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: SignupScreen.textPink,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40), // Space for bottom fixed elements
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Handle register logic
  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields.')));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    // Use AuthController
    // Loading state is handled by Obx in the button helper or locally if we want mixed approach
    // But since we are converting to GetX partially or fully:
    final authController = Get.find<AuthController>();

    // We can still use local setState for button loading visual if we don't wrap the whole screen in Obx
    setState(() => _isLoading = true);

    final success = await authController.register(
        username, email, password, confirmPassword);

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              "Check Your Email",
              style: TextStyle(
                fontFamily: 'Digitalt',
                fontWeight: FontWeight.w800,
                color: SignupScreen.textPink,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    size: 60, color: SignupScreen.textGreen),
                const SizedBox(height: 16),
                Text(
                  "A verification link has been sent to $email. Please click the link to verify your account.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Digitalt',
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close dialog
                  Get.offAllNamed(AppRoutes.login); // Go to login
                },
                child: const Text(
                  "GO TO LOGIN",
                  style: TextStyle(
                    fontFamily: 'Digitalt',
                    fontWeight: FontWeight.w800,
                    color: SignupScreen.textPink,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  // Handle Google signup
  Future<void> _handleGoogleSignup() async {
    final authController = Get.find<AuthController>();
    setState(() => _isGoogleLoading = true);
    final success = await authController.googleSignIn();
    setState(() => _isGoogleLoading = false);

    if (success) {
      Get.offAllNamed(AppRoutes.home);
    }
  }

  // Professional Input field
  Widget _inputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    bool isPassword = false,
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: TextCapitalization.none,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: SignupScreen.textPink, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                      color: SignupScreen.textPink.withOpacity(0.6)),
                  onPressed: toggleObscure,
                )
              : null,
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Digitalt',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: SignupScreen.textPink.withOpacity(0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: SignupScreen.textPink.withOpacity(0.5), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: SignupScreen.textPink, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Social button with Ripple
  Widget _socialButton({
    required String text,
    required Widget icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            border: Border.all(
                color: SignupScreen.textPink.withOpacity(0.6), width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 14),
              Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Digitalt',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: SignupScreen.textPink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSocialDialog(BuildContext context, String provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "$provider Sign Up",
            style: const TextStyle(
                fontFamily: 'Digitalt',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: SignupScreen.textPink),
          ),
          content: Text(
            "This is where $provider authentication will happen.",
            style: const TextStyle(
                fontFamily: 'Digitalt', fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("CLOSE",
                  style: TextStyle(
                      fontFamily: 'Digitalt',
                      fontWeight: FontWeight.w700,
                      color: SignupScreen.textPink)),
            ),
          ],
        );
      },
    );
  }
}

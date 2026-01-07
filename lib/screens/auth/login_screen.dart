import 'package:flutter/material.dart';
import 'package:jol_app/screens/auth/services/auth_services.dart';
import 'package:jol_app/screens/auth/signup_screen.dart';
import 'package:jol_app/screens/bnb/home_screen.dart';

import 'forget_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFC42AF8);
  static const Color accentPink = Color(0xFFF82A87);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Improved: Resize ensures content remains scrollable when keyboard is open
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
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 80),
                    const Text(
                      'LOGIN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        color: LoginScreen.accentPink,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Username / Email
                    _inputField(
                      icon: Icons.person_outline_rounded,
                      hint: "USERNAME OR EMAIL",
                      controller: _usernameController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 18),

                    // Password with toggle visibility
                    _inputField(
                      icon: Icons.lock_open_rounded,
                      hint: "PASSWORD",
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      toggleObscure: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "FORGOT PASSWORD?",
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: LoginScreen.accentPink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 1.2, color: LoginScreen.textPink.withOpacity(0.4))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: LoginScreen.textPink,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(thickness: 1.2, color: LoginScreen.textPink.withOpacity(0.4))),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Google Login Button
                    _socialButton(
                      text: _isGoogleLoading ? "SIGNING IN..." : "CONTINUE WITH GMAIL",
                      icon: Image.asset("lib/assets/images/google.png", height: 22),
                      onTap: _isGoogleLoading ? null : _handleGoogleLogin,
                    ),
                    const SizedBox(height: 16),

                    // Apple Button
                    _socialButton(
                      text: "CONTINUE WITH APPLE",
                      icon: Image.asset("lib/assets/images/apple.png", height: 22),
                      onTap: () => _showSocialDialog(context, "Apple"),
                    ),
                    const SizedBox(height: 140), // Spacer for bottom fixed content
                  ],
                ),
              ),

              // Bottom fixed section
              Positioned(
                left: 28,
                right: 28,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sign in button with shadow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: LoginScreen.textPink.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LoginScreen.textPink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          "SIGN IN",
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
                    const SizedBox(height: 20),

                    // Signup link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "DON'T HAVE AN ACCOUNT?",
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupScreen()),
                            );
                          },
                          child: const Text(
                            "SIGN UP",
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: LoginScreen.textPink,
                              decoration: TextDecoration.underline,
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

  // Handle standard login (Logic preserved)
  Future<void> _handleLogin() async {
    final input = _usernameController.text.trim();
    if (input.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    final bool isEmail = input.contains('@');
    final String username = isEmail ? '' : input;
    final String email = isEmail ? input : '';

    setState(() => _isLoading = true);
    final result = await _authService.login(
      username,
      email,
      _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Login failed.')),
      );
    }
  }

  // Handle Google login (Logic preserved)
  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    final result = await _authService.googleSignIn();
    setState(() => _isGoogleLoading = false);

    if (result.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Google login failed.')),
      );
    }
  }

  // Professional Input field helper
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
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: LoginScreen.textPink, size: 22),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: LoginScreen.textPink.withOpacity(0.6)),
            onPressed: toggleObscure,
          )
              : null,
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Digitalt',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: LoginScreen.textPink.withOpacity(0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: LoginScreen.textPink.withOpacity(0.5), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LoginScreen.textPink, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Social button helper with Ripple Effect
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
            border: Border.all(color: LoginScreen.textPink.withOpacity(0.6), width: 1.5),
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
                  color: LoginScreen.textPink,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "$provider Login",
            style: const TextStyle(fontFamily: 'Digitalt', fontWeight: FontWeight.w800, fontSize: 22, color: LoginScreen.textPink),
          ),
          content: Text(
            "This is where $provider authentication will happen.",
            style: const TextStyle(fontFamily: 'Digitalt', fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("CLOSE", style: TextStyle(fontFamily: 'Digitalt', fontWeight: FontWeight.w700, color: LoginScreen.textPink)),
            ),
          ],
        );
      },
    );
  }
}
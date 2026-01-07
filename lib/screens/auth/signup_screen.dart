import 'package:flutter/material.dart';
import 'package:jol_app/screens/auth/login_screen.dart';
import 'package:jol_app/screens/auth/services/auth_services.dart';
import 'package:jol_app/screens/bnb/home_screen.dart';

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
  final AuthService _authService = AuthService();
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
          child: Stack(
            children: [
              SingleChildScrollView(
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
                      toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
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
                      toggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 1.2, color: SignupScreen.textPink.withOpacity(0.4))),
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
                        Expanded(child: Divider(thickness: 1.2, color: SignupScreen.textPink.withOpacity(0.4))),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Social Buttons
                    _socialButton(
                      text: _isGoogleLoading ? "SIGNING UP..." : "CONTINUE WITH GMAIL",
                      icon: Image.asset("lib/assets/images/google.png", height: 22),
                      onTap: _isGoogleLoading ? null : _handleGoogleSignup,
                    ),
                    const SizedBox(height: 16),
                    _socialButton(
                      text: "CONTINUE WITH APPLE",
                      icon: Image.asset("lib/assets/images/apple.png", height: 22),
                      onTap: () => _showSocialDialog(context, "Apple"),
                    ),
                    const SizedBox(height: 160), // Space for bottom fixed elements
                  ],
                ),
              ),

              // Bottom fixed elements
              Positioned(
                left: 28,
                right: 28,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle register logic (Logic preserved from your original code)
  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields.')));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.register(username, email, password, confirmPassword);
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Registration failed. Try again.')),
      );
    }
  }

  // Handle Google signup
  Future<void> _handleGoogleSignup() async {
    setState(() => _isGoogleLoading = true);
    final result = await _authService.googleSignIn();
    setState(() => _isGoogleLoading = false);

    if (result.success) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Google signup failed.')),
      );
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
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: SignupScreen.textPink, size: 22),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: SignupScreen.textPink.withOpacity(0.6)),
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
            borderSide: BorderSide(color: SignupScreen.textPink.withOpacity(0.5), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SignupScreen.textPink, width: 2),
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
            border: Border.all(color: SignupScreen.textPink.withOpacity(0.6), width: 1.5),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "$provider Sign Up",
            style: const TextStyle(fontFamily: 'Digitalt', fontWeight: FontWeight.w800, fontSize: 22, color: SignupScreen.textPink),
          ),
          content: Text(
            "This is where $provider authentication will happen.",
            style: const TextStyle(fontFamily: 'Digitalt', fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("CLOSE", style: TextStyle(fontFamily: 'Digitalt', fontWeight: FontWeight.w700, color: SignupScreen.textPink)),
            ),
          ],
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jol_app/screens/auth/controllers/auth_controller.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _authController = Get.find<AuthController>();
  final _oldPassController = TextEditingController();
  final _newPass1Controller = TextEditingController();
  final _newPass2Controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const Color headerPink = Color(0xFFF82A87);
  static const Color accentPink = Color(0xFFC42AF8);

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPass1Controller.dispose();
    _newPass2Controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.changePassword(
        _oldPassController.text,
        _newPass1Controller.text,
        _newPass2Controller.text,
      );

      if (success) {
        _oldPassController.clear();
        _newPass1Controller.clear();
        _newPass2Controller.clear();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Success",
                  style: TextStyle(fontFamily: 'Digitalt', color: headerPink)),
              content: const Text(
                  "Your password has been changed successfully.",
                  style: TextStyle(fontFamily: 'Digitalt')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK",
                      style: TextStyle(
                          fontFamily: 'Digitalt',
                          color: accentPink,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CHANGE PASSWORD",
            style: TextStyle(fontFamily: 'Digitalt', color: headerPink)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: headerPink),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Old Password
                  TextFormField(
                    controller: _oldPassController,
                    obscureText: true,
                    style: const TextStyle(
                        fontFamily: 'Digitalt', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "CURRENT PASSWORD",
                      labelStyle: const TextStyle(
                          color: accentPink, fontFamily: 'Digitalt'),
                      prefixIcon:
                          const Icon(Icons.lock_open, color: accentPink),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: accentPink, width: 2)),
                    ),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? "Required" : null,
                  ),
                  const SizedBox(height: 16),

                  // New Password
                  TextFormField(
                    controller: _newPass1Controller,
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
                    controller: _newPass2Controller,
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
                      if (val != _newPass1Controller.text)
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
                                "UPDATE PASSWORD",
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

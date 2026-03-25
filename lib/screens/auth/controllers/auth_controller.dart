import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jol_app/screens/auth/services/auth_services.dart';
import '../models/user.dart';
import '../login_screen.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  final Rx<User?> user = Rx<User?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isAuthenticated = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    isLoading.value = true;
    try {
      final isLoggedIn = await _authService.isAuthenticated();
      if (isLoggedIn) {
        final currentUser = await _authService.fetchUserProfile();
        if (currentUser != null) {
          user.value = currentUser;
          isAuthenticated.value = true;
        } else {
          // Token might be invalid if we can't fetch profile
          await logout();
        }
      } else {
        isAuthenticated.value = false;
        user.value = null;
      }
    } catch (e) {
      print("Error checking auth status: $e");
      isAuthenticated.value = false;
      user.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> login(String username, String email, String password) async {
    isLoading.value = true;
    try {
      final result = await _authService.login(username, email, password);
      if (result.success && result.user != null) {
        user.value = result.user;
        isAuthenticated.value = true;
        return true;
      } else {
        _showSnackbar("Login Failed", result.error ?? "Unknown error occurred");
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register(String username, String email, String password,
      String confirmPassword) async {
    isLoading.value = true;
    try {
      final result = await _authService.register(
          username, email, password, confirmPassword);
      if (result.success && result.user != null) {
        // Do NOT log in immediately. Verification is required.
        // Clear any token saved by AuthService to prevent auto-login on restart
        await logout();

        return true;
      } else {
        _showSnackbar(
            "Registration Failed", result.error ?? "Unknown error occurred");
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> googleSignIn() async {
    isLoading.value = true;
    try {
      final result = await _authService.googleSignIn();
      if (result.success && result.user != null) {
        user.value = result.user!;
        isAuthenticated.value = true;
        return true;
      } else {
        _showSnackbar(
            "Google Sign-In Failed", result.error ?? "Unknown error occurred");
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    isLoading.value = true;
    try {
      await _authService.logout();
      user.value = null;
      isAuthenticated.value = false;

      // Navigate to login
      Get.offAll(() => const LoginScreen());
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyEmail(String key) async {
    isLoading.value = true;
    try {
      final result = await _authService.verifyEmail(key);
      if (result.success) {
        _showSnackbar("Success", "Email verified successfully", isError: false);
        return true;
      }
      _showSnackbar("Error", result.error ?? "Verification failed");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    isLoading.value = true;
    try {
      final result = await _authService.requestPasswordReset(email);
      if (result.success) {
        _showSnackbar("Success", "Password reset email sent", isError: false);
        return true;
      }
      _showSnackbar("Error", result.error ?? "Failed to send reset email");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> confirmPasswordReset(
      String uid, String token, String p1, String p2) async {
    isLoading.value = true;
    try {
      final result =
          await _authService.confirmPasswordReset(uid, token, p1, p2);
      if (result.success) {
        _showSnackbar("Success", "Password reset successfully", isError: false);
        // Navigate to login
        Get.offAll(() => const LoginScreen());
        return true;
      }
      _showSnackbar("Error", result.error ?? "Reset failed");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> changePassword(String oldP, String newP1, String newP2) async {
    isLoading.value = true;
    try {
      final result = await _authService.changePassword(oldP, newP1, newP2);
      if (result.success) {
        _showSnackbar("Success", "Password changed successfully",
            isError: false);
        return true;
      }
      _showSnackbar("Error", result.error ?? "Change failed");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deactivateAccount(String password) async {
    print("AuthController: deactivateAccount called");
    isLoading.value = true;
    try {
      final result = await _authService.deactivateAccount(password);
      print(
          "AuthController: result success=${result.success}, error=${result.error}");
      if (result.success) {
        user.value = null;
        isAuthenticated.value = false;
        Get.offAll(() => const LoginScreen());
        _showSnackbar("Success", "Account deactivated", isError: false);
        return true;
      }
      _showSnackbar("Error", result.error ?? "Deactivation failed");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void _showSnackbar(String title, String message, {bool isError = true}) {
    final context = Get.context;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $message',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: isError ? Colors.red.withOpacity(0.8) : Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      Get.rawSnackbar(
        title: title,
        message: message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: isError ? Colors.red.withOpacity(0.8) : Colors.green,
        margin: const EdgeInsets.all(16),
      );
    }
  }
}

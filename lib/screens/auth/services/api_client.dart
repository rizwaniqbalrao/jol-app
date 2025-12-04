import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../login_screen.dart';
import 'secure_storage_service.dart';

class ApiClient {
  static const String baseUrl = 'https://nonabstemiously-stocky-cynthia.ngrok-free.dev/api';
  static final SecureStorageService _storage = SecureStorageService();

  // Track if we're already handling logout to prevent multiple calls
  static bool _isHandlingLogout = false;

  /// Centralized GET request with auto-logout on 401
  static Future<http.Response> get(
      String endpoint, {
        Map<String, String>? additionalHeaders,
        bool requiresAuth = true,
      }) async {
    try {
      final headers = <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

      if (requiresAuth) {
        final token = await _storage.getToken();
        if (token != null) {
          headers['Authorization'] = 'Token $token';
        }
      }

      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      print('GET ${endpoint} - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('GET ${endpoint} - Status: ${response.statusCode}');
      print('GET ${endpoint} - Body: ${response.body}');

      // Check for 401 Unauthorized
      if (response.statusCode == 401) {
        await _handleUnauthorized();
      }

      return response;
    } catch (e) {
      print('GET ${endpoint} - Error: $e');
      rethrow;
    }
  }

  /// Centralized POST request with auto-logout on 401
  static Future<http.Response> post(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? additionalHeaders,
        bool requiresAuth = true,
      }) async {
    try {
      final headers = <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

      if (requiresAuth) {
        final token = await _storage.getToken();
        if (token != null) {
          headers['Authorization'] = 'Token $token';
        }
      }

      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      print('POST ${endpoint} - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));

      print('POST ${endpoint} - Status: ${response.statusCode}');
      print('POST ${endpoint} - Body: ${response.body}');

      // Check for 401 Unauthorized
      if (response.statusCode == 401) {
        await _handleUnauthorized();
      }

      return response;
    } catch (e) {
      print('POST ${endpoint} - Error: $e');
      rethrow;
    }
  }

  /// Centralized PUT request with auto-logout on 401
  static Future<http.Response> put(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? additionalHeaders,
        bool requiresAuth = true,
      }) async {
    try {
      final headers = <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

      if (requiresAuth) {
        final token = await _storage.getToken();
        if (token != null) {
          headers['Authorization'] = 'Token $token';
        }
      }

      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      print('PUT ${endpoint} - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));

      print('PUT ${endpoint} - Status: ${response.statusCode}');
      print('PUT ${endpoint} - Body: ${response.body}');

      // Check for 401 Unauthorized
      if (response.statusCode == 401) {
        await _handleUnauthorized();
      }

      return response;
    } catch (e) {
      print('PUT ${endpoint} - Error: $e');
      rethrow;
    }
  }

  /// Centralized DELETE request with auto-logout on 401
  static Future<http.Response> delete(
      String endpoint, {
        Map<String, String>? additionalHeaders,
        bool requiresAuth = true,
      }) async {
    try {
      final headers = <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

      if (requiresAuth) {
        final token = await _storage.getToken();
        if (token != null) {
          headers['Authorization'] = 'Token $token';
        }
      }

      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      print('DELETE ${endpoint} - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('DELETE ${endpoint} - Status: ${response.statusCode}');
      print('DELETE ${endpoint} - Body: ${response.body}');

      // Check for 401 Unauthorized
      if (response.statusCode == 401) {
        await _handleUnauthorized();
      }

      return response;
    } catch (e) {
      print('DELETE ${endpoint} - Error: $e');
      rethrow;
    }
  }

  /// Handle 401 Unauthorized - Auto logout and navigate to login
  static Future<void> _handleUnauthorized() async {
    // Prevent multiple simultaneous logout calls
    if (_isHandlingLogout) return;
    _isHandlingLogout = true;

    try {
      print('🔒 Token expired (401) - Logging out automatically...');

      // Clear all stored data
      await _storage.clearAll();

      // Show a brief message to user
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Small delay to let snackbar show
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to login screen and clear navigation stack
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
            (route) => false, // Remove all previous routes
      );

      print('✅ Logged out successfully - Redirected to login');
    } catch (e) {
      print('❌ Error during auto-logout: $e');
    } finally {
      _isHandlingLogout = false;
    }
  }

  /// Get current auth token (helper method)
  static Future<String?> getCurrentToken() async {
    return await _storage.getToken();
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await _storage.isLoggedIn();
  }
}
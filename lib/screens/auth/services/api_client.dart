import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../login_screen.dart';
import 'secure_storage_service.dart';

class ApiClient {
  static const String baseUrl = 'http://13.53.102.145/api';
  static final SecureStorageService _storage = SecureStorageService();

  // Track if we're already handling logout to prevent multiple calls
  static bool _isHandlingLogout = false;

  /// Check if response indicates an invalid/expired token
  /// Handles both 401 Unauthorized AND 403 Forbidden with 'Invalid token' message
  static bool _isInvalidTokenResponse(http.Response response) {
    if (response.statusCode == 401) return true;

    // Server sometimes returns 403 with "Invalid token." message
    if (response.statusCode == 403) {
      try {
        final body = jsonDecode(response.body);
        final detail = body['detail']?.toString().toLowerCase() ?? '';
        if (detail.contains('invalid token')) {
          return true;
        }
      } catch (_) {
        // JSON parse failed, not an invalid token response
      }
    }
    return false;
  }

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

      debugPrint(
          'GET $endpoint - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('GET $endpoint - Status: ${response.statusCode}');
      debugPrint('GET $endpoint - Body: ${response.body}');

      // Check for invalid/expired token (401 or 403 with 'Invalid token')
      if (_isInvalidTokenResponse(response)) {
        await handleUnauthorized();
      }

      return response;
    } catch (e) {
      debugPrint('GET $endpoint - Error: $e');
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

      debugPrint(
          'POST $endpoint - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('POST $endpoint - Status: ${response.statusCode}');
      debugPrint('POST $endpoint - Body: ${response.body}');

      // Check for invalid/expired token (401 or 403 with 'Invalid token')
      if (_isInvalidTokenResponse(response)) {
        await handleUnauthorized();
      }

      return response;
    } catch (e) {
      debugPrint('POST $endpoint - Error: $e');
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

      debugPrint(
          'PUT $endpoint - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('PUT $endpoint - Status: ${response.statusCode}');
      debugPrint('PUT $endpoint - Body: ${response.body}');

      // Check for invalid/expired token (401 or 403 with 'Invalid token')
      if (_isInvalidTokenResponse(response)) {
        await handleUnauthorized();
      }

      return response;
    } catch (e) {
      debugPrint('PUT $endpoint - Error: $e');
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

      debugPrint(
          'DELETE $endpoint - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('DELETE $endpoint - Status: ${response.statusCode}');
      debugPrint('DELETE $endpoint - Body: ${response.body}');

      // Check for invalid/expired token (401 or 403 with 'Invalid token')
      if (_isInvalidTokenResponse(response)) {
        await handleUnauthorized();
      }

      return response;
    } catch (e) {
      debugPrint('DELETE $endpoint - Error: $e');
      rethrow;
    }
  }

  /// Centralized PATCH request with auto-logout on 401
  static Future<http.Response> patch(
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

      debugPrint(
          'PATCH $endpoint - Token: ${headers['Authorization']?.substring(0, 10) ?? 'None'}...');

      final response = await http
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('PATCH $endpoint - Status: ${response.statusCode}');
      debugPrint('PATCH $endpoint - Body: ${response.body}');

      // Check for invalid/expired token (401 or 403 with 'Invalid token')
      if (_isInvalidTokenResponse(response)) {
        await handleUnauthorized();
      }

      return response;
    } catch (e) {
      debugPrint('PATCH $endpoint - Error: $e');
      rethrow;
    }
  }

  /// Handle 401 Unauthorized - Auto logout and navigate to login
  /// This is public so it can be called from services that use direct HTTP
  /// (e.g., multipart file uploads that can't use the standard methods)
  static Future<void> handleUnauthorized() async {
    // Prevent multiple simultaneous logout calls
    if (_isHandlingLogout) return;
    _isHandlingLogout = true;

    try {
      debugPrint('🔒 Token expired (401) - Logging out automatically...');

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

      debugPrint('✅ Logged out successfully - Redirected to login');
    } catch (e) {
      debugPrint('❌ Error during auto-logout: $e');
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

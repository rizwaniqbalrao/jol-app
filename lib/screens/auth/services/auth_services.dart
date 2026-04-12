import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/password_reset_request.dart';
import '../models/user.dart';
import '../models/register_request.dart';
import '../models/login_request.dart';
import '../models/user_wallet.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult({required this.success, this.user, this.error});
}

class AuthService {
  final String baseUrl = 'http://13.53.102.145/api';
  final SecureStorageService _storage = SecureStorageService();

  /// Process referral after successful authentication
  Future<void> _processReferralAfterAuth(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/user/process-referral/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Referral processed successfully');
      } else {
        print('⚠️ Referral processing failed: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Referral processing error: $e');
      // Don't fail the auth flow if referral fails
    }
  }

  /// ✅ Correct implementation for new google_sign_in API
  Future<AuthResult> googleSignIn() async {
    try {
      // ✅ Initialize Google Sign-In (once)
      await GoogleSignIn.instance.initialize(
        clientId:
            '513851405319-8s9jl10luc5v0vm8s8agu1mr47hh38p9.apps.googleusercontent.com',
        serverClientId:
            '513851405319-87gfavvccvimg3ici170j9o6cvlpb95n.apps.googleusercontent.com',
      );

      // ✅ Start authentication
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['openid', 'email', 'profile'],
      );

      // ✅ Get ID token (used by backend)
      final String? idToken = account.authentication.idToken;

      // ✅ Get Access Token (optional)
      final GoogleSignInClientAuthorization? authz =
          await account.authorizationClient.authorizationForScopes(
        const <String>['email', 'profile', 'openid'],
      );
      final String? accessToken = authz?.accessToken;

      if (idToken == null) {
        return AuthResult(
            success: false,
            error:
                'Unable to connect with Google. Please check your account and try again.');
      }

      // ✅ Send token to Django backend for verification & login
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id_token': idToken,
          'access_token': accessToken ?? '',
          'code': '',
        }),
      );
      print(
          "***********************************************************************");
      print(response.body);
      // ✅ Handle backend response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['key'] ?? data['token'];

        if (token != null) {
          await _storage.saveToken(token);

          // 🔥 Process referral after successful Google sign-in
          await _processReferralAfterAuth(token);
        }

        final userData = data['user'] ?? {};
        final user = userData.isNotEmpty
            ? User.fromJson(userData)
            : User(
                id: 0,
                email: account.email,
                username: account.displayName ?? account.email,
                firstName: account.displayName,
                lastName: null,
              );

        return AuthResult(success: true, user: user);
      } else {
        // Parse server errors for user-friendly display
        String errorMsg = _parseError(response);
        return AuthResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print("❌ Google sign-in error: $e");
      return AuthResult(
          success: false,
          error:
              'Google sign-in unavailable right now. Check your connection and try again.');
    }
  }
  /// ✅ Apple Sign In — native iOS flow
  Future<AuthResult> appleSignIn() async {
    try {
      // Guard: Apple Sign In only works on iOS
      if (!Platform.isIOS) {
        return AuthResult(
            success: false,
            error: 'Apple Sign In is only available on iOS devices.');
      }

      // ✅ Trigger native Apple Sign In sheet
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? identityToken = credential.identityToken;
      final String? authorizationCode = credential.authorizationCode;

      if (identityToken == null) {
        return AuthResult(
            success: false,
            error:
                'Unable to connect with Apple. Please check your account and try again.');
      }

      // ✅ Build request body for backend
      final Map<String, dynamic> body = {
        'access_token': identityToken,
      };
      if (authorizationCode != null) {
        body['code'] = authorizationCode;
      }

      // ✅ Send token to Django backend for verification & login
      final response = await http.post(
        Uri.parse('$baseUrl/auth/apple/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print("Apple Sign-In response: ${response.body}");

      // ✅ Handle backend response (same pattern as Google)
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['key'] ?? data['token'];

        if (token != null) {
          await _storage.saveToken(token);

          // 🔥 Process referral after successful Apple sign-in
          await _processReferralAfterAuth(token);
        }

        final userData = data['user'] ?? {};

        // Build user from response or from Apple credential
        final String? firstName = credential.givenName;
        final String? lastName = credential.familyName;
        final String? email = credential.email;

        final user = userData.isNotEmpty
            ? User.fromJson(userData)
            : User(
                id: 0,
                email: email ?? '',
                username: email ?? 'apple_user',
                firstName: firstName,
                lastName: lastName,
              );

        return AuthResult(success: true, user: user);
      } else {
        String errorMsg = _parseError(response);
        return AuthResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print("❌ Apple sign-in error: $e");

      // Handle user cancellation gracefully
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          return AuthResult(
              success: false, error: 'Apple Sign In was cancelled.');
        }
      }

      return AuthResult(
          success: false,
          error:
              'Apple sign-in unavailable right now. Check your connection and try again.');
    }
  }


  Future<AuthResult> login(
      String username, String email, String password) async {
    try {
      print('🔹 Starting login for: username="$username", email="$email"');

      // Fetch CSRF token (may not be needed for token login)
      final csrfToken = await _getCsrfToken();
      print('🔹 CSRF token fetched: ${csrfToken ?? "NULL"}');

      // Prepare login request
      final request =
          LoginRequest(username: username, email: email, password: password);
      final requestBody = jsonEncode(request.toJson());
      print('🔹 Request body JSON: $requestBody');

      // Headers
      final headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      print(
          '🔹 Sending POST request to $baseUrl/auth/login/ with headers: $headers');

      // Send request
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: headers,
        body: requestBody,
      );

      print('🔹 Response status code: ${response.statusCode}');
      print('🔹 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Login successful, parsing response...');
        final data = jsonDecode(response.body);

        final token = data['key'];
        print('🔹 Token from server: $token');

        if (token == null) {
          print('❌ No token in response, login failed');
          return AuthResult(
              success: false, error: 'No token received from server.');
        }

        // Save token
        await _storage.saveToken(token);
        print('********************************Saving token: $token');

        // Save user ID only if available
        if (data['user'] != null && data['user']['id'] != null) {
          await _storage.saveUserId(data['user']['id'].toString());
        }

        // Process referral
        await _processReferralAfterAuth(token);

        // Create user object safely
        final user = data['user'] != null
            ? User.fromJson(data['user'])
            : User(
                id: 0,
                email: email,
                username: username,
              );

        print('✅ User object created: ${user.username}');
        return AuthResult(success: true, user: user);
      } else {
        // Handle server errors
        print('⚠️ Login failed with status ${response.statusCode}');
        String errorMsg = _parseError(response);
        print('⚠️ Parsed error: $errorMsg');
        return AuthResult(success: false, error: errorMsg);
      }
    } catch (e, st) {
      print('❌ Exception during login: $e');
      print('❌ Stacktrace: $st');
      return AuthResult(
        success: false,
        error:
            'Unable to connect. Check your internet or server status.\nError: $e',
      );
    }
  }

  // ------------------ REGISTER ------------------ //
  Future<AuthResult> register(
      String username, String email, String password1, String password2) async {
    try {
      print('Starting registration for username: $username, email: $email');
      final csrfToken = await _getCsrfToken();
      print('Fetched CSRF token: ${csrfToken ?? "NULL (missing)"}');

      final request = RegisterRequest(
        username: username,
        email: email,
        password1: password1,
        password2: password2,
      );
      final requestBody = jsonEncode(request.toJson());
      print('Request body: $requestBody');

      final headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      print('Headers: $headers');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/registration/'),
        headers: headers,
        body: requestBody,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Decoded data: $data');
        final token = data['key'];
        if (token != null) {
          await _storage.saveToken(token);

          // 🔥 Process referral after successful registration
          await _processReferralAfterAuth(token);

          final user = data['user'] != null
              ? User.fromJson(data['user'])
              : User(
                  id: 0,
                  email: email,
                  username: username,
                );
          print('Registration success: Token saved, user: ${user.username}');
          return AuthResult(success: true, user: user);
        } else {
          print('No token in response');
        }
      } else {
        // Parse server errors for user-friendly display
        String errorMsg = _parseError(response);
        print('Parsed error: $errorMsg');
        return AuthResult(success: false, error: errorMsg);
      }
      return AuthResult(
          success: false,
          error:
              'Unable to create account. Please check your details (e.g., strong password, unique username/email) and try again.');
    } catch (e) {
      print('Exception in register: $e');
      return AuthResult(
          success: false,
          error: 'Connection issue. Please check your internet and try again.');
    }
  }

  // ------------------ PASSWORD RESET ------------------ //
  Future<AuthResult> requestPasswordReset(String email) async {
    try {
      print('Requesting password reset for email: $email');
      final csrfToken = await _getCsrfToken();
      print('Fetched CSRF token: ${csrfToken ?? "NULL (missing)"}');

      final request = PasswordResetRequest(email: email);
      final requestBody = jsonEncode(request.toJson());
      print('Request body: $requestBody');

      final headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      print('Headers: $headers');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password/reset/'),
        headers: headers,
        body: requestBody,
      );

      print('Password reset response status: ${response.statusCode}');
      print('Password reset response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(success: true);
      } else {
        // Parse server errors for user-friendly display
        String errorMsg = _parseError(response);
        print('Parsed error: $errorMsg');
        return AuthResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in requestPasswordReset: $e');
      return AuthResult(
          success: false,
          error: 'Connection issue. Please check your internet and try again.');
    }
  }

  // ------------------ LOGOUT ------------------ //
  Future<AuthResult> logout() async {
    try {
      final token = await getCurrentToken();
      final csrfToken = await _getCsrfToken();

      if (token == null) {
        // Already logged out locally
        await _storage.clearAll();
        return AuthResult(success: true);
      }

      final headers = {
        'accept': 'application/json',
        'Authorization': 'Token $token',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      final response = await http.get(
        Uri.parse('$baseUrl/auth/logout/'),
        headers: headers,
      );

      print('Logout response status: ${response.statusCode}');
      print('Logout response body: ${response.body}');

      // Clear local storage regardless of server response
      await _storage.clearAll();

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AuthResult(success: true);
      } else {
        // Still return success if local storage cleared
        // but log the server error
        String errorMsg = _parseError(response);
        print('Logout warning: $errorMsg');
        return AuthResult(success: true); // Still successful locally
      }
    } catch (e) {
      print('Exception in logout: $e');
      // Clear local storage even if server call fails
      await _storage.clearAll();
      return AuthResult(success: true); // Local logout successful
    }
  }

  // ------------------ OTHER HELPERS ------------------ //
  Future<String?> _getCsrfToken() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/csrf/'),
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['csrfToken'] ?? data['csrf_token'];
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getCurrentToken() async {
    return await _storage.getToken();
  }

  Future<bool> isAuthenticated() async {
    return await _storage.isLoggedIn();
  }

  Future<User?> fetchUserProfile() async {
    try {
      final token = await getCurrentToken();
      if (token == null) return null;

      // ✅ Use ApiClient - it handles 401 automatically with navigation to login
      final response = await ApiClient.get('/v1/user/detail/');

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        // Parse server errors for logging (no UI error since not AuthResult)
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            final errors = <String>[];
            errorData.forEach((key, value) {
              if (value is List) {
                errors.addAll(value.map((e) => '$key: ${e.toString()}'));
              } else if (value is String) {
                errors.add('$key: $value');
              }
            });
            if (errors.isNotEmpty) {
              print('Profile fetch error: ${errors.join('\n')}');
            }
          }
        } catch (_) {
          print('Profile fetch error body: ${response.body}');
        }
      }
    } catch (e) {
      print('Exception in fetchUserProfile: $e');
    }
    return null;
  }

  // ------------------ EMAIL VERIFICATION ------------------ //
  Future<AuthResult> verifyEmail(String key) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/registration/verify-email/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'key': key}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(success: true);
      } else {
        return AuthResult(success: false, error: _parseError(response));
      }
    } catch (e) {
      return AuthResult(success: false, error: 'Connection error: $e');
    }
  }

  // ------------------ PASSWORD RESET CONFIRM ------------------ //
  Future<AuthResult> confirmPasswordReset(String uid, String token,
      String newPassword1, String newPassword2) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password/reset/confirm/$uid/$token/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(
            {'new_password1': newPassword1, 'new_password2': newPassword2}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(success: true);
      } else {
        return AuthResult(success: false, error: _parseError(response));
      }
    } catch (e) {
      return AuthResult(success: false, error: 'Connection error: $e');
    }
  }

  // ------------------ CHANGE PASSWORD ------------------ //
  Future<AuthResult> changePassword(
      String oldPassword, String newPassword1, String newPassword2) async {
    try {
      final token = await getCurrentToken();
      if (token == null)
        return AuthResult(success: false, error: 'Not authenticated');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/password/change/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password1': newPassword1,
          'new_password2': newPassword2,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(success: true);
      } else {
        return AuthResult(success: false, error: _parseError(response));
      }
    } catch (e) {
      return AuthResult(success: false, error: 'Connection error: $e');
    }
  }

  // ------------------ ACCOUNT DEACTIVATION ------------------ //
  Future<AuthResult> deactivateAccount(String password) async {
    try {
      print("AuthService: deactivateAccount start");
      final token = await getCurrentToken();
      if (token == null) {
        print("AuthService: No token found");
        return AuthResult(success: false, error: 'Not authenticated');
      }

      print("AuthService: Sending request to $baseUrl/auth/deactivate/");
      final response = await http.post(
        Uri.parse('$baseUrl/auth/deactivate/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({'password': password}),
      );

      print("AuthService: Deactivate response status: ${response.statusCode}");
      print("AuthService: Deactivate response body: ${response.body}");

      if (response.statusCode == 204 || response.statusCode == 200) {
        await _storage.clearAll();
        return AuthResult(success: true);
      } else {
        return AuthResult(success: false, error: _parseError(response));
      }
    } catch (e) {
      print("AuthService: Exception in deactivateAccount: $e");
      return AuthResult(success: false, error: 'Connection error: $e');
    }
  }

  String _parseError(http.Response response) {
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map<String, dynamic>) {
        final errors = <String>[];
        errorData.forEach((key, value) {
          if (value is List) {
            errors.addAll(value.map((e) => '$key: ${e.toString()}'));
          } else if (value is String) {
            errors.add('$key: $value');
          }
        });
        if (errors.isNotEmpty) return errors.join('\n');
      }
      return response.body.isNotEmpty
          ? _sanitizeError(response.body)
          : 'Unknown error';
    } catch (_) {
      return response.body.isNotEmpty
          ? _sanitizeError(response.body)
          : 'Unknown error';
    }
  }

  String _sanitizeError(String rawBody) {
    final lowerBody = rawBody.toLowerCase();
    if (lowerBody.contains("integrityerror") ||
        lowerBody.contains("unique constraint")) {
      if (lowerBody.contains("email")) {
        return "An account with this email already exists.";
      }
      if (lowerBody.contains("username")) {
        return "This username is already taken.";
      }
      return "Account already exists.";
    }
    // If it's an HTML page, completely hide raw HTML
    if (lowerBody.contains("<!doctype html>") || lowerBody.contains("<html")) {
      return "A server error occurred. Please try again later.";
    }
    // Truncate long error messages
    if (rawBody.length > 200) {
      return rawBody.substring(0, 200) + "...";
    }
    return rawBody;
  }
}

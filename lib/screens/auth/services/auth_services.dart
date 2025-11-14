import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../models/register_request.dart';
import '../models/login_request.dart';
import '../models/user_wallet.dart';
import 'secure_storage_service.dart';

class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult({required this.success, this.user, this.error});
}

class AuthService {
  final String baseUrl = 'https://nonabstemiously-stocky-cynthia.ngrok-free.dev/api';
  final SecureStorageService _storage = SecureStorageService();

  /// ✅ Correct implementation for new google_sign_in API
  Future<AuthResult> googleSignIn() async {
    try {
      // ✅ Initialize Google Sign-In (once)
      await GoogleSignIn.instance.initialize(
        clientId:
        '513851405319-87gfavvccvimg3ici170j9o6cvlpb95n.apps.googleusercontent.com',
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
        return AuthResult(success: false, error: 'Unable to connect with Google. Please check your account and try again.');
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

      // ✅ Handle backend response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['key'] ?? data['token'];

        if (token != null) {
          await _storage.saveToken(token);
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
        String errorMsg = 'Login with Google failed. Please try again or use another method.';
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
              errorMsg = errors.join('\n');
            }
          }
        } catch (_) {
          // If JSON parse fails, use raw body or generic
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return AuthResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print("❌ Google sign-in error: $e");
      return AuthResult(success: false, error: 'Google sign-in unavailable right now. Check your connection and try again.');
    }
  }

  // ------------------ NORMAL LOGIN ------------------ //
  Future<AuthResult> login(String username, String email, String password) async {
    try {
      final csrfToken = await _getCsrfToken();
      final request = LoginRequest(username: username, email: email, password: password);
      final requestBody = jsonEncode(request.toJson());

      final headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['key'];
        if (token != null) {
          await _storage.saveToken(token);
          await _storage.saveUserId(data['user']['id'].toString());
          final user = data['user'] != null
              ? User.fromJson(data['user'])
              : User(
            id: 0,
            email: email,
            username: username,
          );
          return AuthResult(success: true, user: user);
        }
      } else {
        // Parse server errors for user-friendly display
        String errorMsg = 'Incorrect username, email, or password. Please double-check and try again.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            final errors = <String>[];
            errorData.forEach((key, value) {
              if (value is List) {
                errors.addAll(value.map((e) => value.toString()));
              } else if (value is String) {
                errors.add(value);
              }
            });
            if (errors.isNotEmpty) {
              errorMsg = errors.join('\n');
            }
          }
        } catch (_) {
          // If JSON parse fails, use raw body or generic
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return AuthResult(success: false, error: errorMsg);
      }
      return AuthResult(success: false, error: 'Incorrect username, email, or password. Please double-check and try again.');
    } catch (e) {
      return AuthResult(success: false, error: 'Unable to connect. Please check your internet and try again.');
    }
  }

  // ------------------ REGISTER ------------------ //
  Future<AuthResult> register(
      String username, String email, String password1, String password2) async {
    try {
      print('Starting registration for username: $username, email: $email');  // Debug: Inputs
      final csrfToken = await _getCsrfToken();
      print('Fetched CSRF token: ${csrfToken ?? "NULL (missing)"}');  // Debug: CSRF

      final request = RegisterRequest(
        username: username,
        email: email,
        password1: password1,
        password2: password2,
      );
      final requestBody = jsonEncode(request.toJson());
      print('Request body: $requestBody');  // Debug: Payload

      final headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      print('Headers: $headers');  // Debug: Headers
      final response = await http.post(
        Uri.parse('$baseUrl/auth/registration/'),
        headers: headers,
        body: requestBody,
      );

      print('Response status: ${response.statusCode}');  // Debug: Status
      print('Response body: ${response.body}');  // Debug: Full body (key here!)

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Decoded data: $data');  // Debug: Parsed JSON
        final token = data['key'];
        if (token != null) {
          await _storage.saveToken(token);
          final user = data['user'] != null
              ? User.fromJson(data['user'])
              : User(
            id: 0,
            email: email,
            username: username,
          );
          print('Registration success: Token saved, user: ${user.username}');  // Debug: Success
          return AuthResult(success: true, user: user);
        } else {
          print('No token in response');  // Debug: Missing token
        }
      } else {
        // Parse server errors for user-friendly display
        String errorMsg = 'Unable to create account. Please check your details (e.g., strong password, unique username/email) and try again.';
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
              errorMsg = errors.join('\n');
            }
          }
        } catch (_) {
          // If JSON parse fails, use raw body or generic
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        print('Parsed error: $errorMsg');  // Debug: Formatted error
        return AuthResult(success: false, error: errorMsg);
      }
      return AuthResult(success: false, error: 'Unable to create account. Please check your details (e.g., strong password, unique username/email) and try again.');
    } catch (e) {
      print('Exception in register: $e');  // Debug: Any crash
      return AuthResult(success: false, error: 'Connection issue. Please check your internet and try again.');
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

  Future<void> logout() async {
    await _storage.deleteToken();
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
      final response = await http.get(
        Uri.parse('$baseUrl/auth/user/'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Token $token',
        },
      );
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
}
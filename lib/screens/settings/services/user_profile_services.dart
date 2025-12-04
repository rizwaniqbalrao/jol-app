import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../auth/models/user.dart';
import '../../auth/services/api_client.dart';
import '../../auth/services/secure_storage_service.dart';

class ProfileResult {
  final bool success;
  final UserProfile? profile;
  final String? error;

  ProfileResult({required this.success, this.profile, this.error});
}

class UserResult {
  final bool success;
  final User? user;
  final String? error;

  UserResult({required this.success, this.user, this.error});
}

class UserProfileService {
  final SecureStorageService _storage = SecureStorageService();

  // ═══════════════════════════════════════════════════════════════
  // USER DETAIL ENDPOINTS (/api/v1/user/detail/)
  // ═══════════════════════════════════════════════════════════════

  /// Get user details
  Future<UserResult> getUserDetail() async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return UserResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // ✅ Use ApiClient - it handles 401 automatically
      final response = await ApiClient.get('/v1/user/detail/');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data);
        return UserResult(success: true, user: user);
      } else {
        return UserResult(
          success: false,
          error: 'Unable to load user details. Please try again.',
        );
      }
    } catch (e) {
      print('Exception in getUserDetail: $e');
      return UserResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  /// Update user details (PUT)
  Future<UserResult> updateUserDetail({
    required String username,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return UserResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      final body = {
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
      };

      print('PUT User Detail - Body: ${jsonEncode(body)}');

      // ✅ Use ApiClient - it handles 401 automatically
      final response = await ApiClient.put(
        '/v1/user/detail/',
        body: body,
      );

      print('PUT User Detail - Status: ${response.statusCode}');
      print('PUT User Detail - Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data);
        return UserResult(success: true, user: user);
      } else {
        String errorMsg = 'Unable to update user details. Please try again.';
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
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return UserResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in updateUserDetail: $e');
      return UserResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  /// Partially update user details (PATCH)
  Future<UserResult> patchUserDetail({
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return UserResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Only include non-null fields
      final body = <String, dynamic>{};
      if (username != null) body['username'] = username;
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;

      print('PATCH User Detail - Body: ${jsonEncode(body)}');

      // ✅ Use ApiClient - it handles 401 automatically
      // Note: You'll need to add a PATCH method to ApiClient
      final response = await http.patch(
        Uri.parse('${ApiClient.baseUrl}/v1/user/detail/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );

      print('PATCH User Detail - Status: ${response.statusCode}');
      print('PATCH User Detail - Response: ${response.body}');

      // Manual 401 check since we're not using ApiClient.patch yet
      if (response.statusCode == 401) {
        await _storage.clearAll();
        return UserResult(
          success: false,
          error: 'Session expired. Please log in again.',
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data);
        return UserResult(success: true, user: user);
      } else {
        String errorMsg = 'Unable to update user details. Please try again.';
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
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return UserResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in patchUserDetail: $e');
      return UserResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // USER PROFILE ENDPOINTS (/api/v1/user/profile/)
  // ═══════════════════════════════════════════════════════════════

  /// Get user profile
  Future<ProfileResult> getUserProfile() async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return ProfileResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // ✅ Use ApiClient - it handles 401 automatically
      final response = await ApiClient.get('/v1/user/profile/');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = UserProfile.fromJson(data);
        return ProfileResult(success: true, profile: profile);
      } else {
        String errorMsg = 'Unable to load profile. Please try again.';
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
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return ProfileResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in getUserProfile: $e');
      return ProfileResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  /// Update user profile with avatar upload support (PATCH - multipart/form-data)
  Future<ProfileResult> patchUserProfileWithAvatar({
    File? avatar,
    String? bio,
    String? location,
    DateTime? birthDate,
  }) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return ProfileResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Create multipart request (must use http directly for file uploads)
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiClient.baseUrl}/v1/user/profile/'),
      );

      // Add headers
      request.headers['Authorization'] = 'Token $token';
      request.headers['accept'] = 'application/json';
      request.headers['ngrok-skip-browser-warning'] = 'true';

      // Add avatar file if provided
      if (avatar != null) {
        var stream = http.ByteStream(avatar.openRead());
        var length = await avatar.length();
        var multipartFile = http.MultipartFile(
          'avatar',
          stream,
          length,
          filename: avatar.path.split('/').last,
        );
        request.files.add(multipartFile);
        print('Adding avatar file: ${avatar.path}');
      }

      // Add text fields if provided
      if (bio != null) request.fields['bio'] = bio;
      if (location != null) request.fields['location'] = location;
      if (birthDate != null) {
        request.fields['birth_date'] = birthDate.toIso8601String().split('T')[0];
      }

      print('PATCH Profile (Multipart) - Fields: ${request.fields}');
      print('PATCH Profile (Multipart) - Files: ${request.files.length}');

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('PATCH Profile (Multipart) - Status: ${response.statusCode}');
      print('PATCH Profile (Multipart) - Response: ${response.body}');

      // Manual 401 check for multipart requests
      if (response.statusCode == 401) {
        await _storage.clearAll();
        return ProfileResult(
          success: false,
          error: 'Session expired. Please log in again.',
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = UserProfile.fromJson(data);
        return ProfileResult(success: true, profile: profile);
      } else {
        String errorMsg = 'Unable to update profile. Please try again.';
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
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return ProfileResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in patchUserProfileWithAvatar: $e');
      return ProfileResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  /// Update user profile (JSON-only - legacy method)
  Future<ProfileResult> patchUserProfile({
    String? bio,
    String? location,
    DateTime? birthDate,
  }) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return ProfileResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Only include non-null fields
      final body = <String, dynamic>{};
      if (bio != null) body['bio'] = bio;
      if (location != null) body['location'] = location;
      if (birthDate != null) {
        body['birth_date'] = birthDate.toIso8601String().split('T')[0];
      }

      print('PATCH Profile - Body: ${jsonEncode(body)}');

      // Manual PATCH request (ApiClient doesn't have PATCH method yet)
      final response = await http.patch(
        Uri.parse('${ApiClient.baseUrl}/v1/user/profile/'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );

      print('PATCH Profile - Status: ${response.statusCode}');
      print('PATCH Profile - Response: ${response.body}');

      // Manual 401 check
      if (response.statusCode == 401) {
        await _storage.clearAll();
        return ProfileResult(
          success: false,
          error: 'Session expired. Please log in again.',
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = UserProfile.fromJson(data);
        return ProfileResult(success: true, profile: profile);
      } else {
        String errorMsg = 'Unable to update profile. Please try again.';
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
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return ProfileResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in patchUserProfile: $e');
      return ProfileResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }
}
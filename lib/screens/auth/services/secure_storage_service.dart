import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Saves the auth token securely.
  Future<void> saveToken(String token) async {
    print('********************************Saving token: $token'); // Debug print
    await _storage.write(key: 'auth_token', value: token);
  }

  /// Retrieves the stored auth token.
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  /// Deletes the stored auth token.
  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  /// Checks if a user is logged in by verifying the token exists and is non-empty.
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Saves user ID securely (call this during login)
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: 'user_id', value: userId);
  }

  /// Retrieves the stored user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  /// Saves complete user data after login
  Future<void> saveUserData({
    required String token,
    required String userId,
    String? username,
    String? email,
  }) async {
    await saveToken(token);
    await saveUserId(userId);
    if (username != null) await _storage.write(key: 'username', value: username);
    if (email != null) await _storage.write(key: 'email', value: email);
  }

  /// Clears all stored data during logout
  Future<void> clearAll() async {
    await deleteToken();
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'email');
  }
}
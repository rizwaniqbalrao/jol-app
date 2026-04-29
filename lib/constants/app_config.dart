/// Centralized app configuration.
///
/// All API / media URLs live here so they can be changed in a single place.
/// If the backend domain ever changes again, update ONLY this file.
class AppConfig {
  AppConfig._(); // prevent instantiation

  /// Root backend URL (no trailing slash).
  static const String baseUrl = 'https://backend.jolpuzzles.com';

  /// API base URL (no trailing slash).
  static const String apiBaseUrl = '$baseUrl/api';

  /// API v1 base URL (no trailing slash).
  static const String apiV1BaseUrl = '$baseUrl/api/v1';

  /// Helper: build a full media URL from a relative path returned by the API
  /// (e.g. "/media/avatars/pic.jpg").
  ///
  /// If the path is already absolute (starts with http/https), it is returned
  /// as-is.  A `null` or empty path returns `null`.
  static String? mediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}

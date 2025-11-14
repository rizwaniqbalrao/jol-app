// File: services/leaderboard_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/services/secure_storage_service.dart';
import '../models/leadboard_entry.dart';

class LeaderboardResult {
  final bool success;
  final LeaderboardResponse? data;
  final String? error;

  LeaderboardResult({
    required this.success,
    this.data,
    this.error,
  });
}

class LeaderboardService {
  final String baseUrl = 'https://nonabstemiously-stocky-cynthia.ngrok-free.dev/api/v1';
  final SecureStorageService _storage = SecureStorageService();

  /// Fetch leaderboard with filters
  ///
  /// Parameters:
  /// - period: 'today', 'this_week', 'this_month', 'all_time' (default)
  /// - page: Page number (default: 1)
  /// - pageSize: Items per page (default: 50)
  Future<LeaderboardResult> getLeaderboard({
    String period = 'all_time',
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return LeaderboardResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Build query parameters
      final queryParams = {
        'period': period,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      final uri = Uri.parse('$baseUrl/game/leaderboard/').replace(
        queryParameters: queryParams,
      );

      print('GET Leaderboard - URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'accept': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      print('GET Leaderboard - Status: ${response.statusCode}');
      print('GET Leaderboard - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leaderboardResponse = LeaderboardResponse.fromJson(data);
        return LeaderboardResult(
          success: true,
          data: leaderboardResponse,
        );
      } else if (response.statusCode == 401) {
        return LeaderboardResult(
          success: false,
          error: 'Session expired. Please log in again.',
        );
      } else {
        String errorMsg = 'Unable to load leaderboard. Please try again.';
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
        return LeaderboardResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in getLeaderboard: $e');
      return LeaderboardResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  /// Convenience methods for specific periods

  Future<LeaderboardResult> getTodayLeaderboard({int page = 1, int pageSize = 50}) {
    return getLeaderboard(period: 'today', page: page, pageSize: pageSize);
  }

  Future<LeaderboardResult> getWeekLeaderboard({int page = 1, int pageSize = 50}) {
    return getLeaderboard(period: 'this_week', page: page, pageSize: pageSize);
  }

  Future<LeaderboardResult> getMonthLeaderboard({int page = 1, int pageSize = 50}) {
    return getLeaderboard(period: 'this_month', page: page, pageSize: pageSize);
  }

  Future<LeaderboardResult> getAllTimeLeaderboard({int page = 1, int pageSize = 50}) {
    return getLeaderboard(period: 'all_time', page: page, pageSize: pageSize);
  }
}
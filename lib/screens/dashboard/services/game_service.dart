/// File: services/game_service.dart

import 'dart:convert';
import '../../auth/services/api_client.dart';
import '../../auth/services/secure_storage_service.dart';
import '../models/game_models.dart';

class SaveGameResult {
  final bool success;
  final SaveGameResponse? data;
  final String? error;

  SaveGameResult({
    required this.success,
    this.data,
    this.error,
  });
}

class GameHistoryResult {
  final bool success;
  final GameHistoryResponse? data;
  final String? error;

  GameHistoryResult({
    required this.success,
    this.data,
    this.error,
  });
}

class GameService {
  final SecureStorageService _storage = SecureStorageService();

  // ═══════════════════════════════════════════════════════════════
  // POST /api/v1/game/add-game/ - Save Game
  // ═══════════════════════════════════════════════════════════════

  /// Save a finished game
  ///
  /// IMPORTANT RULES:
  /// - If game_mode is "timed", completionTime is REQUIRED
  /// - If game_mode is "untimed", completionTime should be null
  /// - If game_type is "solo", roomCode, position, totalPlayers should be null
  /// - If game_type is "multiplayer", roomCode, position, totalPlayers are REQUIRED
  /// - player_id must match the authenticated user's ID
  Future<SaveGameResult> saveGame(Game game) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return SaveGameResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Validate game data before sending
      final validationError = _validateGameData(game);
      if (validationError != null) {
        return SaveGameResult(success: false, error: validationError);
      }

      final body = game.toJson();

      print('POST Add Game - Body: ${jsonEncode(body)}');

      // ✅ Use ApiClient - it handles 401 automatically
      final response = await ApiClient.post(
        '/v1/game/add-game/',
        body: body,
      );

      print('POST Add Game - Status: ${response.statusCode}');
      print('POST Add Game - Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final saveResponse = SaveGameResponse.fromJson(data);
        return SaveGameResult(success: true, data: saveResponse);
      } else {
        String errorMsg = 'Unable to save game. Please try again.';
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
        return SaveGameResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in saveGame: $e');
      return SaveGameResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GET /api/v1/game/list/ - Get Game History
  // ═══════════════════════════════════════════════════════════════

  /// Fetch user's personal game history (paginated)
  ///
  /// Parameters:
  /// - page: Page number (default: 1)
  /// - pageSize: Items per page (default: 20, max: 100)
  Future<GameHistoryResult> getGameHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return GameHistoryResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Ensure page_size doesn't exceed 100
      if (pageSize > 100) pageSize = 100;

      final endpoint = '/v1/game/list/?page=$page&page_size=$pageSize';

      print('GET Game List - Endpoint: $endpoint');

      // ✅ Use ApiClient - it handles 401 automatically
      final response = await ApiClient.get(endpoint);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final historyResponse = GameHistoryResponse.fromJson(data);
        return GameHistoryResult(
          success: true,
          data: historyResponse,
        );
      } else {
        String errorMsg = 'Unable to load game history. Please try again.';
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
        return GameHistoryResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in getGameHistory: $e');
      return GameHistoryResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Validate game data before sending to API
  String? _validateGameData(Game game) {
    // Validate timed mode requirements
    if (game.gameMode == 'timed' && game.completionTime == null) {
      return 'Completion time is required for timed games.';
    }

    // Validate multiplayer requirements
    if (game.gameType == 'multiplayer') {
      if (game.roomCode == null || game.roomCode!.isEmpty) {
        return 'Room code is required for multiplayer games.';
      }
      if (game.roomCode!.length != 6) {
        return 'Room code must be exactly 6 characters.';
      }
      if (game.position == null) {
        return 'Position is required for multiplayer games.';
      }
      if (game.totalPlayers == null) {
        return 'Total players is required for multiplayer games.';
      }
    }

    // Validate score range
    if (game.finalScore < 0 || game.finalScore > 100) {
      return 'Final score must be between 0 and 100.';
    }

    // Validate accuracy range
    if (game.accuracyPercentage < 0 || game.accuracyPercentage > 100) {
      return 'Accuracy percentage must be between 0 and 100.';
    }

    // Validate hints
    if (game.hintsUsed < 0) {
      return 'Hints used cannot be negative.';
    }

    return null; // No validation errors
  }
}
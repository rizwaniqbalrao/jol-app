// File: helpers/multiplayer_game_save_helper.dart

import 'package:uuid/uuid.dart';
import '../../dashboard/models/game_models.dart';
import '../../dashboard/services/game_service.dart';
import '../../settings/services/user_profile_services.dart';
import '../controller/multiplayer_game_controller.dart';
import '../models/room_models.dart';

class MultiplayerGameSaveHelper {
  final GameService _gameService = GameService();
  final UserProfileService _userService = UserProfileService();
  final _uuid = Uuid();

  /// Save a completed multiplayer game to the backend
  ///
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'matchId': String? (if successful)
  Future<Map<String, dynamic>> saveMultiplayerGame({
    required MultiplayerGameController controller,
    required Room room,
    required String gameStatus, // "completed", "abandoned", or "timed_out"
  }) async {
    try {
      // Step 1: Get user ID
      final userResult = await _userService.getUserDetail();

      if (!userResult.success || userResult.user == null) {
        return {
          'success': false,
          'message': userResult.error ?? 'Unable to get user information',
        };
      }

      final userId = userResult.user!.id.toString();

      // Step 2: Determine player position and total players
      final leaderboard = controller.getLeaderboard();
      final playerIndex = leaderboard.indexWhere((p) => p.id == controller.playerId);

      if (playerIndex == -1) {
        return {
          'success': false,
          'message': 'Could not find player in leaderboard',
        };
      }

      final position = playerIndex + 1; // 1-indexed
      final totalPlayers = leaderboard.length;

      // Step 3: Calculate completion time
      int? completionTime = controller.completionTimeSeconds;

      // For timed mode, use the calculated completion time
      // For untimed mode, still track the time but backend won't require it
      if (room.settings.mode == 'untimed' && controller.gameStartTime != null) {
        completionTime = DateTime.now().difference(controller.gameStartTime!).inSeconds;
      }

      // Step 4: Determine final game status
      String finalStatus = gameStatus;
      if (room.settings.mode == 'timed' && controller.timeLeft.inSeconds <= 0) {
        finalStatus = 'timed_out';
      }

      // Step 5: Build Game object
      final game = Game(
        matchId: _uuid.v4(), // Generate unique match ID
        playerId: userId,
        gameType: 'multiplayer',
        gameMode: room.settings.mode == 'timed' ? 'timed' : 'untimed',
        operation: room.settings.operation == 'addition' ? 'addition' : 'subtraction',
        gridSize: room.settings.gridSize,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        status: finalStatus,
        finalScore: controller.localScore,
        accuracyPercentage: controller.accuracyPercentage,
        hintsUsed: controller.currentPlayer?.hintsUsed ?? 0,
        completionTime: room.settings.mode == 'timed' ? completionTime : null,
        roomCode: room.id,
        position: position,
        totalPlayers: totalPlayers,
      );

      // Step 6: Validate game data
      final validationError = _validateMultiplayerGameData(game, room);
      if (validationError != null) {
        return {
          'success': false,
          'message': validationError,
        };
      }

      // Step 7: Save to backend
      final saveResult = await _gameService.saveGame(game);

      if (saveResult.success && saveResult.data != null) {
        return {
          'success': true,
          'message': saveResult.data!.detail,
          'matchId': saveResult.data!.matchId,
        };
      } else {
        return {
          'success': false,
          'message': saveResult.error ?? 'Failed to save game',
        };
      }
    } catch (e) {
      print('Exception in saveMultiplayerGame: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  /// Validate multiplayer game data before saving
  String? _validateMultiplayerGameData(Game game, Room room) {
    // Ensure room code exists and is 6 characters
    if (game.roomCode == null || game.roomCode!.isEmpty) {
      return 'Room code is required for multiplayer games.';
    }

    if (game.roomCode!.length != 6) {
      return 'Invalid room code length: ${game.roomCode!.length}. Must be 6 characters.';
    }

    // Ensure position exists
    if (game.position == null) {
      return 'Position is required for multiplayer games.';
    }

    // Ensure total players exists
    if (game.totalPlayers == null) {
      return 'Total players is required for multiplayer games.';
    }

    // Validate position is within range
    if (game.position! < 1 || game.position! > game.totalPlayers!) {
      return 'Invalid position: ${game.position}. Must be between 1 and ${game.totalPlayers}.';
    }

    // Ensure score is within 0-100 range
    if (game.finalScore < 0 || game.finalScore > 100) {
      return 'Invalid score: ${game.finalScore}. Must be between 0-100.';
    }

    // Ensure accuracy is within 0-100 range
    if (game.accuracyPercentage < 0 || game.accuracyPercentage > 100) {
      return 'Invalid accuracy: ${game.accuracyPercentage}%. Must be between 0-100.';
    }

    // For timed mode, completion time should exist
    if (game.gameMode == 'timed' && game.completionTime == null) {
      return 'Completion time is required for timed games.';
    }

    // Hints used cannot be negative or exceed max
    if (game.hintsUsed < 0 || game.hintsUsed > room.settings.maxHints) {
      return 'Invalid hints used: ${game.hintsUsed}. Must be between 0-${room.settings.maxHints}.';
    }

    return null; // No errors
  }

  /// Helper method to determine game status based on controller state
  String determineMultiplayerGameStatus(
      MultiplayerGameController controller,
      Room room,
      bool wasSubmitted,
      ) {
    // Check if timed out
    if (room.settings.mode == 'timed' && controller.timeLeft.inSeconds <= 0) {
      return 'timed_out';
    }

    // Check if properly completed
    if (wasSubmitted && controller.isSubmitted) {
      return 'completed';
    }

    // Otherwise abandoned
    return 'abandoned';
  }
}
// File: helpers/game_save_helper.dart

import 'package:uuid/uuid.dart';
import '../../dashboard/models/game_models.dart';
import '../../dashboard/services/game_service.dart';
import '../../settings/services/user_profile_services.dart';
import '../controller/game_controller.dart';

class GameSaveHelper {
  final GameService _gameService = GameService();
  final UserProfileService _userService = UserProfileService();
  final _uuid = Uuid();

  /// Save a completed solo game to the backend
  ///
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'matchId': String? (if successful)
  Future<Map<String, dynamic>> saveSoloGame({
    required GameController controller,
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

      // Step 2: Calculate completion time for untimed mode
      int? completionTime;
      if (controller.mode == GameMode.timed) {
        completionTime = controller.completionTimeSeconds;
      } else {
        // For untimed mode, still track how long they took
        if (controller.gameStartTime != null) {
          completionTime = DateTime.now().difference(controller.gameStartTime!).inSeconds;
        }
      }

      // Step 3: Determine game status
      String finalStatus = gameStatus;
      if (controller.mode == GameMode.timed && controller.timeLeft.inSeconds <= 0) {
        finalStatus = 'timed_out';
      }

      // Step 4: Build Game object
      final game = Game(
        matchId: _uuid.v4(), // Generate unique match ID
        playerId: userId,
        gameType: 'solo',
        gameMode: controller.mode == GameMode.timed ? 'timed' : 'untimed',
        operation: controller.operation == PuzzleOperation.addition ? 'addition' : 'subtraction',
        gridSize: controller.gridSize,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        status: finalStatus,
        finalScore: controller.score,
        accuracyPercentage: controller.accuracyPercentage,
        hintsUsed: controller.hintsUsed,
        completionTime: controller.mode == GameMode.timed ? completionTime : null,
        roomCode: null, // Solo game
        position: null, // Solo game
        totalPlayers: null, // Solo game
      );

      // Step 5: Validate game data
      final validationError = _validateGameData(game, controller);
      if (validationError != null) {
        return {
          'success': false,
          'message': validationError,
        };
      }

      // Step 6: Save to backend
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
      print('Exception in saveSoloGame: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  /// Validate game data before saving
  String? _validateGameData(Game game, GameController controller) {
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
    if (game.hintsUsed < 0 || game.hintsUsed > controller.maxHints) {
      return 'Invalid hints used: ${game.hintsUsed}. Must be between 0-${controller.maxHints}.';
    }

    return null; // No errors
  }

  /// Helper method to determine game status based on controller state
  String determineGameStatus(GameController controller, bool wasCompleted) {
    if (controller.mode == GameMode.timed && controller.timeLeft.inSeconds <= 0) {
      return 'timed_out';
    }

    if (wasCompleted) {
      return 'completed';
    }

    return 'abandoned';
  }
}
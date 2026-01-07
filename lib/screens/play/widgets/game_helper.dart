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

      // Step 2: Calculate completion time safely
      int? completionTime;

// Priority 1: Use the controller's recorded completion time
      if (controller.completionTimeSeconds != null) {
        completionTime = controller.completionTimeSeconds;
      }
// Priority 2: Calculate it manually if the game is being stopped/abandoned
      else if (controller.gameStartTime != null) {
        completionTime = DateTime.now().difference(controller.gameStartTime!).inSeconds;
      }
// Priority 3: Default to 0 if the game hasn't started but is being saved
      else {
        completionTime = 0;
      }

      // Step 3: Determine game status
      String finalStatus = gameStatus;
      if (controller.mode == GameMode.timed && controller.timeLeft.inSeconds <= 0) {
        finalStatus = 'timed_out';
      }

      // Step 4: Build Game object
      final game = Game(
        matchId: _uuid.v4(),
        playerId: userId,
        gameType: 'solo',
        gameMode: controller.mode == GameMode.timed ? 'timed' : 'untimed',
        operation: controller.operation == PuzzleOperation.addition ? 'addition' : 'subtraction',
        gridSize: controller.gridSize,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        status: finalStatus,
        finalScore: controller.score,
        accuracyPercentage: controller.accuracyPercentage,

        // ALWAYS GIVE 0 AS HINTS USED (Backend Compatibility)
        hintsUsed: 0,

        completionTime: completionTime,
        roomCode: null,
        position: null,
        totalPlayers: null,
      );

      // Step 5: Validate game data
      final validationError = _validateGameData(game);
      if (validationError != null) {
        return {
          'success': false,
          'message': validationError,
        };
      }

      // Step 6: Save to backend
      final saveResult = await _gameService.saveGame(game);

      if (saveResult.success && saveResult.data != null) {
        final savedGame = _convertResponseToGame(saveResult.data!);

        return {
          'success': true,
          'message': 'Game saved successfully! You earned ${saveResult.data!.pointsEarned} points.',
          'matchId': saveResult.data!.matchId,
          'pointsEarned': saveResult.data!.pointsEarned,
          'game': savedGame,
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

  Game _convertResponseToGame(SaveGameResponse response) {
    return Game(
      matchId: response.matchId,
      playerId: response.playerId ?? 'N/A',
      gameType: response.gameType,
      gameMode: response.gameMode,
      operation: response.operation,
      gridSize: response.gridSize,
      timestamp: response.timestamp,
      status: response.status,
      finalScore: response.finalScore,
      accuracyPercentage: response.accuracyPercentage,
      hintsUsed: response.hintsUsed,
      completionTime: response.completionTime,
      roomCode: response.roomCode,
      position: response.position,
      totalPlayers: response.totalPlayers,
    );
  }

  /// Updated Validation: Removed hint-specific logic
  String? _validateGameData(Game game) {
    if (game.finalScore < 0 || game.finalScore > 100) {
      return 'Invalid score: ${game.finalScore}. Must be between 0-100.';
    }

    if (game.accuracyPercentage < 0 || game.accuracyPercentage > 100) {
      return 'Invalid accuracy: ${game.accuracyPercentage}%. Must be between 0-100.';
    }

    // Relaxed constraint: In some abandoned scenarios, completionTime might be null
    // but the backend usually expects it if status is 'completed'
    if (game.status == 'completed' && game.completionTime == null) {
      // We can log this or handle it, but for solo we usually have it.
    }

    return null;
  }

  String determineGameStatus(GameController controller, bool wasCompleted) {
    if (controller.mode == GameMode.timed && controller.timeLeft.inSeconds <= 0) {
      return 'timed_out';
    }
    return wasCompleted ? 'completed' : 'abandoned';
  }
}
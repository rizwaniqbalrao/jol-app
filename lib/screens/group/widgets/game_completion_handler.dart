// game_completion_handler.dart
// Helper to automatically save game results to group history

import 'package:firebase_database/firebase_database.dart';

import '../../play/models/room_models.dart';

class GameCompletionHandler {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Call this when a multiplayer game ends
  /// This will automatically record the game to the group's history
  Future<void> recordGameToGroup({
    required String roomCode,
    required Room room,
  }) async {
    try {
      // Get groupId from room
      final roomSnapshot = await _database.ref('rooms/$roomCode/groupId').get();

      if (!roomSnapshot.exists) {
        print('⚠️ No groupId found for room $roomCode');
        return;
      }

      final groupId = roomSnapshot.value as String;
      print('🎮 Recording game to group: $groupId');

      // Get all players who participated
      final playerIds = room.players.keys.toList();

      // Calculate scores for each player
      final scores = <String, int>{};
      room.players.forEach((id, player) {
        scores[id] = player.score;
      });

      // Determine winner (highest score)
      String? winnerId;
      int highestScore = 0;

      room.players.forEach((id, player) {
        if (player.score > highestScore) {
          highestScore = player.score;
          winnerId = id;
        }
      });

      // Create game record
      final gameRef = _database.ref('groups/$groupId/gameHistory').push();
      final gameId = gameRef.key!;

      await gameRef.set({
        'roomCode': roomCode,
        'playerIds': playerIds,
        'scores': scores,
        'winnerId': winnerId,
        'timestamp': ServerValue.timestamp,
        'settings': {
          'gridSize': room.settings.gridSize,
          'mode': room.settings.mode,
          'operation': room.settings.operation,
          'timeLimit': room.settings.timeLimit,
          'maxHints': room.settings.maxHints,
        },
      });

      print('✅ Game recorded to group history: $gameId');

      // Update group stats
      await _database.ref('groups/$groupId/stats').update({
        'totalGames': ServerValue.increment(1),
        'lastActivity': ServerValue.timestamp,
      });

      print('📊 Updated group stats');

      // Update member stats for all players
      for (String playerId in playerIds) {
        await _database.ref('groups/$groupId/members/$playerId').update({
          'gamesPlayed': ServerValue.increment(1),
        });
        print('✅ Updated stats for player: $playerId');
      }

      // Update winner stats
      if (winnerId != null) {
        await _database.ref('groups/$groupId/members/$winnerId').update({
          'wins': ServerValue.increment(1),
        });
        print('🏆 Incremented wins for: $winnerId');
      }

      print('🎉 Game successfully recorded to group!');

    } catch (e) {
      print('❌ Error recording game to group: $e');
    }
  }

  /// Check if room is linked to a group
  Future<bool> isGroupGame(String roomCode) async {
    try {
      final snapshot = await _database.ref('rooms/$roomCode/groupId').get();
      return snapshot.exists;
    } catch (e) {
      print('❌ Error checking if group game: $e');
      return false;
    }
  }

  /// Get group ID from room
  Future<String?> getGroupIdFromRoom(String roomCode) async {
    try {
      final snapshot = await _database.ref('rooms/$roomCode/groupId').get();
      if (snapshot.exists) {
        return snapshot.value as String;
      }
      return null;
    } catch (e) {
      print('❌ Error getting groupId from room: $e');
      return null;
    }
  }
}
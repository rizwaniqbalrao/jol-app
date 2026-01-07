// room_service.dart - FIXED VERSION
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

import '../models/room_models.dart';

class RoomService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    required RoomSettings settings,
    required PuzzleData puzzle,
  }) async {
    String roomCode;
    bool codeExists = true;

    do {
      roomCode = generateRoomCode();
      final snapshot = await _database.ref('rooms/$roomCode').get();
      codeExists = snapshot.exists;
    } while (codeExists);

    final roomData = {
      'settings': settings.toJson(),
      'puzzle': puzzle.toJson(),
      'gameState': GameState(
        status: 'waiting',
        hostId: hostId,
      ).toJson(),
      'players': {
        hostId: Player(
          id: hostId,
          name: hostName,
          isReady: true,
          isHost: true,
        ).toJson(),
      },
      'results': {
        'winnerId': null,
      },
      'createdAt': ServerValue.timestamp,
    };

    await _database.ref('rooms/$roomCode').set(roomData);
    return roomCode;
  }

  Future<bool> joinRoom({
    required String roomCode,
    required String playerId,
    required String playerName,
  }) async {
    try {
      final roomRef = _database.ref('rooms/$roomCode');
      final snapshot = await roomRef.get();

      if (!snapshot.exists) {
        throw Exception('Room not found');
      }

      final roomData = snapshot.value as Map;
      final gameState = GameState.fromJson(roomData['gameState']);

      if (gameState.status != 'waiting') {
        throw Exception('Game already started');
      }

      final players = roomData['players'] as Map? ?? {};
      final maxPlayers = roomData['settings']['maxPlayers'] ?? 4;

      if (players.length >= maxPlayers) {
        throw Exception('Room is full');
      }

      await roomRef.child('players/$playerId').set(
        Player(
          id: playerId,
          name: playerName,
        ).toJson(),
      );

      return true;
    } catch (e) {
      print('Error joining room: $e');
      return false;
    }
  }

  Future<void> togglePlayerReady(String roomCode, String playerId, bool isReady) async {
    await _database.ref('rooms/$roomCode/players/$playerId/isReady').set(isReady);
  }

  Future<void> startGame(String roomCode) async {
    await _database.ref('rooms/$roomCode/gameState').update({
      'status': 'playing',
      'startTime': ServerValue.timestamp,
    });
  }

  Future<void> updateScore(String roomCode, String playerId, int score) async {
    await _database.ref('rooms/$roomCode/players/$playerId/score').set(score);
  }

  Future<bool> useHint(String roomCode, String playerId, int maxHints) async {
    final playerRef = _database.ref('rooms/$roomCode/players/$playerId');
    final snapshot = await playerRef.child('hintsUsed').get();
    final hintsUsed = (snapshot.value as int?) ?? 0;

    if (hintsUsed >= maxHints) {
      return false;
    }

    await playerRef.update({
      'hintsUsed': hintsUsed + 1,
    });

    return true;
  }

  Future<void> markCompleted(String roomCode, String playerId, int score) async {
    print('🔥 Marking player $playerId as completed with score $score');

    await _database.ref('rooms/$roomCode/players/$playerId').update({
      'completedAt': ServerValue.timestamp,
      'score': score,
    });

    print('✅ Player marked as completed in Firebase');
  }

  Future<void> endGame(String roomCode) async {
    print('🏁 Ending game_screen for room $roomCode');

    final roomRef = _database.ref('rooms/$roomCode');

    // Check current status first
    final gameStateSnapshot = await roomRef.child('gameState/status').get();
    final currentStatus = gameStateSnapshot.value as String?;

    if (currentStatus == 'ended') {
      print('⚠️ Game already ended, skipping');
      return;
    }

    final playersSnapshot = await roomRef.child('players').get();
    if (!playersSnapshot.exists) {
      print('⚠️ No players found');
      return;
    }

    final players = playersSnapshot.value as Map<dynamic, dynamic>;
    List<MapEntry<String, dynamic>> playerEntries = players.entries
        .map((e) => MapEntry(e.key as String, e.value as Map))
        .toList();

    playerEntries.sort((a, b) {
      int scoreA = a.value['score'] ?? 0;
      int scoreB = b.value['score'] ?? 0;
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      int timeA = a.value['completedAt'] ?? DateTime.now().millisecondsSinceEpoch;
      int timeB = b.value['completedAt'] ?? DateTime.now().millisecondsSinceEpoch;
      return timeA.compareTo(timeB);
    });

    String? winnerId = playerEntries.isNotEmpty ? playerEntries.first.key : null;

    print('🏆 Winner: $winnerId');
    print('📊 Final scores:');
    for (var entry in playerEntries) {
      print('   ${entry.key}: ${entry.value['score']}');
    }

    await roomRef.update({
      'gameState/status': 'ended',
      'gameState/endTime': ServerValue.timestamp,
      'results/winnerId': winnerId,
    });

    print('✅ Game ended successfully');
  }

  Future<void> leaveRoom(String roomCode, String playerId) async {
    final roomRef = _database.ref('rooms/$roomCode');

    final gameStateSnapshot = await roomRef.child('gameState').get();
    final gameState = GameState.fromJson(gameStateSnapshot.value as Map);

    if (gameState.hostId == playerId) {
      await roomRef.update({
        'gameState/status': 'abandoned',
      });
    } else {
      await roomRef.child('players/$playerId').update({
        'isActive': false,
      });
    }
  }

  Stream<Room> listenToRoom(String roomCode) {
    return _database.ref('rooms/$roomCode').onValue.map((event) {
      if (!event.snapshot.exists) {
        throw Exception('Room not found');
      }
      return Room.fromJson(roomCode, event.snapshot.value as Map);
    });
  }

  Future<bool> roomExists(String roomCode) async {
    final snapshot = await _database.ref('rooms/$roomCode').get();
    return snapshot.exists;
  }

  Future<void> cleanupRoom(String roomCode) async {
    await _database.ref('rooms/$roomCode').remove();
  }

  Future<void> removePlayer(String roomCode, String playerId) async {
    await _database.ref('rooms/$roomCode/players/$playerId').remove();
  }

  Future<int> getPlayerCount(String roomCode) async {
    final snapshot = await _database.ref('rooms/$roomCode/players').get();
    if (!snapshot.exists) return 0;
    final players = snapshot.value as Map;
    return players.length;
  }

  Future<void> incrementHintUsage(String roomCode, String playerId) async {
    final playerRef = _database.ref('rooms/$roomCode/players/$playerId/hintsUsed');
    await playerRef.runTransaction((mutableData) {
      int current = (mutableData as num?)?.toInt() ?? 0;
      return Transaction.success(current + 1);
    });
  }
}
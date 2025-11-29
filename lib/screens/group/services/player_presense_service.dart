// player_presence_service.dart
// Tracks online/offline status of group members

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';

import '../models/group_metadata.dart';

class PlayerPresenceService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Set user as online when they open the app
  Future<void> setUserOnline(String userId) async {
    try {
      final userStatusRef = _database.ref('userPresence/$userId');

      // Set online status
      await userStatusRef.set({
        'status': 'online',
        'lastSeen': ServerValue.timestamp,
      });

      // Set up automatic offline on disconnect
      await userStatusRef.onDisconnect().set({
        'status': 'offline',
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint('✅ User $userId set to online');
    } catch (e) {
      debugPrint('❌ Error setting user online: $e');
    }
  }

  /// Set user as in-game when they join a room
  Future<void> setUserInGame(String userId, String roomCode) async {
    try {
      await _database.ref('userPresence/$userId').update({
        'status': 'in_game',
        'roomCode': roomCode,
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint('✅ User $userId in game: $roomCode');
    } catch (e) {
      debugPrint('❌ Error setting user in-game: $e');
    }
  }

  /// Set user back to online when they leave a room
  Future<void> setUserOnlineFromGame(String userId) async {
    try {
      await _database.ref('userPresence/$userId').update({
        'status': 'online',
        'roomCode': null,
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint('✅ User $userId back to online');
    } catch (e) {
      debugPrint('❌ Error setting user online from game: $e');
    }
  }

  /// Set user as offline explicitly
  Future<void> setUserOffline(String userId) async {
    try {
      await _database.ref('userPresence/$userId').set({
        'status': 'offline',
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint('✅ User $userId set to offline');
    } catch (e) {
      debugPrint('❌ Error setting user offline: $e');
    }
  }

  /// Get user's current status
  Future<Map<String, dynamic>?> getUserStatus(String userId) async {
    try {
      final snapshot = await _database.ref('userPresence/$userId').get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user status: $e');
      return null;
    }
  }

  /// Stream user status (for real-time updates)
  Stream<Map<String, dynamic>?> streamUserStatus(String userId) {
    return _database.ref('userPresence/$userId').onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Get online status for multiple users
  Future<Map<String, String>> getMultipleUserStatuses(List<String> userIds) async {
    Map<String, String> statuses = {};

    try {
      for (String userId in userIds) {
        final snapshot = await _database.ref('userPresence/$userId/status').get();

        if (snapshot.exists) {
          statuses[userId] = snapshot.value as String;
        } else {
          statuses[userId] = 'offline';
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting multiple statuses: $e');
    }

    return statuses;
  }

  /// Check if user is available to play (online or offline, but not in-game)
  Future<bool> isUserAvailable(String userId) async {
    try {
      final status = await getUserStatus(userId);

      if (status == null) return false;

      final userStatus = status['status'] as String?;
      return userStatus == 'online' || userStatus == 'offline';
    } catch (e) {
      debugPrint('❌ Error checking user availability: $e');
      return false;
    }
  }
}

// Add this to your GroupMember model (group_metadata.dart)
// You'll need to update the model to include status

class GroupMemberWithStatus {
  final GroupMember member;
  final String status; // 'online', 'offline', 'in_game'
  final String? currentRoomCode;

  GroupMemberWithStatus({
    required this.member,
    required this.status,
    this.currentRoomCode,
  });

  bool get isOnline => status == 'online';
  bool get isInGame => status == 'in_game';
  bool get isAvailable => status == 'online' || status == 'offline';
}
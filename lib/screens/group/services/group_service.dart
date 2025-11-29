// group_service.dart - Group Management Service
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';

import '../../play/models/room_models.dart';
import '../../play/services/room_service.dart';
import '../models/group_metadata.dart';

class GroupService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<void> diagnoseFirebaseStructure() async {
    try {
      debugPrint('🔍 === FIREBASE DIAGNOSTIC START ===');

      final snapshot = await _database.ref('groups').get();

      if (!snapshot.exists) {
        debugPrint('❌ No groups node exists in Firebase');
        return;
      }

      debugPrint('✅ Groups node exists');
      debugPrint('Data type: ${snapshot.value.runtimeType}');

      if (snapshot.value is Map) {
        final map = snapshot.value as Map;
        debugPrint('📊 Groups stored as Map');
        debugPrint('Total groups: ${map.length}');

        // Show first group structure
        if (map.isNotEmpty) {
          final firstKey = map.keys.first;
          final firstValue = map[firstKey];
          debugPrint('\n📝 First Group Sample:');
          debugPrint('Key: $firstKey');
          debugPrint('Value type: ${firstValue.runtimeType}');
          debugPrint('Value: $firstValue');
        }
      } else if (snapshot.value is List) {
        final list = snapshot.value as List;
        debugPrint('📊 Groups stored as List');
        debugPrint('Total items: ${list.length}');

        // Show first non-null item
        for (int i = 0; i < list.length; i++) {
          if (list[i] != null) {
            debugPrint('\n📝 First Non-Null Item:');
            debugPrint('Index: $i');
            debugPrint('Value type: ${list[i].runtimeType}');
            debugPrint('Value: ${list[i]}');
            break;
          }
        }
      } else {
        debugPrint('❌ Unknown data type: ${snapshot.value.runtimeType}');
        debugPrint('Value: ${snapshot.value}');
      }

      debugPrint('🔍 === FIREBASE DIAGNOSTIC END ===\n');
    } catch (e, stackTrace) {
      debugPrint('❌ Diagnostic failed: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Generate unique group code (format: GRPXXXX)
  String _generateGroupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return 'GRP${List.generate(4, (index) => chars[random.nextInt(chars.length)]).join()}';
  }

  /// Create a new group
  Future<String> createGroup({
    required String creatorId,
    required String creatorName,
    required String groupName,
    String? description,
    String? avatarUrl,
  }) async {
    String groupCode;
    bool codeExists = true;

    // Ensure unique code
    do {
      groupCode = _generateGroupCode();
      final snapshot = await _database
          .ref('groups')
          .orderByChild('metadata/code')
          .equalTo(groupCode)
          .get();
      codeExists = snapshot.exists;
    } while (codeExists);

    // Generate unique group ID
    final groupRef = _database.ref('groups').push();
    final groupId = groupRef.key!;

    final groupData = {
      'metadata': {
        'name': groupName,
        'code': groupCode,
        'createdBy': creatorId,
        'createdAt': ServerValue.timestamp,
        'description': description,
        'avatarUrl': avatarUrl,
      },
      'members': {
        creatorId: {
          'name': creatorName,
          'role': 'admin',
          'joinedAt': ServerValue.timestamp,
          'gamesPlayed': 0,
          'wins': 0,
        },
      },
      'stats': {
        'totalGames': 0,
        'totalMembers': 1,
        'lastActivity': ServerValue.timestamp,
      },
      'gameHistory': {},
    };

    await groupRef.set(groupData);
    print('✅ Group created: $groupId with code $groupCode');
    return groupId;
  }

  /// Join a group by code
  Future<bool> joinGroupByCode({
    required String groupCode,
    required String userId,
    required String userName,
  }) async {
    try {
      // Call this in your GroupController's init or loadMyGroups:
      await diagnoseFirebaseStructure();
      // Find group by code
      final snapshot = await _database
          .ref('groups')
          .orderByChild('metadata/code')
          .equalTo(groupCode)
          .get();

      if (!snapshot.exists) {
        print('❌ Group not found with code: $groupCode');
        return false;
      }

      // Get first matching group
      final groupsMap = snapshot.value as Map;
      final groupId = groupsMap.keys.first;
      final groupData = groupsMap[groupId];

      // Check if already a member
      if (groupData['members'] != null &&
          groupData['members'][userId] != null) {
        print('⚠️ User already in group');
        return true; // Already member, consider success
      }

      // Add member
      await _database.ref('groups/$groupId/members/$userId').set({
        'name': userName,
        'role': 'member',
        'joinedAt': ServerValue.timestamp,
        'gamesPlayed': 0,
        'wins': 0,
      });

      // Update stats
      await _database.ref('groups/$groupId/stats').update({
        'totalMembers': ServerValue.increment(1),
        'lastActivity': ServerValue.timestamp,
      });

      print('✅ User $userId joined group $groupId');
      return true;
    } catch (e) {
      print('❌ Error joining group: $e');
      return false;
    }
  }

  /// Join a group by ID (direct)
  Future<bool> joinGroup({
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    try {
      final groupRef = _database.ref('groups/$groupId');
      final snapshot = await groupRef.get();

      if (!snapshot.exists) {
        print('❌ Group not found: $groupId');
        return false;
      }

      final groupData = snapshot.value as Map;

      // Check if already a member
      if (groupData['members'] != null &&
          groupData['members'][userId] != null) {
        print('⚠️ User already in group');
        return true;
      }

      // Add member
      await groupRef.child('members/$userId').set({
        'name': userName,
        'role': 'member',
        'joinedAt': ServerValue.timestamp,
        'gamesPlayed': 0,
        'wins': 0,
      });

      // Update stats
      await groupRef.child('stats').update({
        'totalMembers': ServerValue.increment(1),
        'lastActivity': ServerValue.timestamp,
      });

      print('✅ User $userId joined group $groupId');
      return true;
    } catch (e) {
      print('❌ Error joining group: $e');
      return false;
    }
  }

  /// Browse all public groups (paginated)
  Future<List<Group>> browseGroups({int limit = 20}) async {
    try {
      final snapshot = await _database
          .ref('groups')
          .orderByChild('stats/lastActivity')
          .limitToLast(limit)
          .get();

      if (!snapshot.exists) {
        debugPrint('No groups found for browsing');
        return [];
      }

      // Handle both Map and List from Firebase
      Map<String, dynamic> groupsMap;

      if (snapshot.value is Map) {
        groupsMap = Map<String, dynamic>.from(snapshot.value as Map);
      } else if (snapshot.value is List) {
        // Convert List to Map
        final list = snapshot.value as List;
        groupsMap = {};
        for (int i = 0; i < list.length; i++) {
          if (list[i] != null) {
            groupsMap[i.toString()] = list[i];
          }
        }
      } else {
        debugPrint('❌ Unexpected data type: ${snapshot.value.runtimeType}');
        return [];
      }

      List<Group> groups = [];

      groupsMap.forEach((key, value) {
        if (value != null && value is Map) {
          try {
            groups.add(Group.fromJson(key, value));
          } catch (e) {
            debugPrint('❌ Error parsing group $key: $e');
          }
        }
      });

      // Sort by last activity (most recent first)
      groups.sort((a, b) =>
          b.stats.lastActivity.compareTo(a.stats.lastActivity)
      );

      debugPrint('✅ Loaded ${groups.length} groups for browsing');
      return groups;
    } catch (e, stackTrace) {
      debugPrint('❌ Error browsing groups: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Search groups by name - FIXED
  Future<List<Group>> searchGroups(String query) async {
    try {
      final snapshot = await _database.ref('groups').get();

      if (!snapshot.exists) {
        debugPrint('No groups found for search');
        return [];
      }

      // Handle both Map and List from Firebase
      Map<String, dynamic> groupsMap;

      if (snapshot.value is Map) {
        groupsMap = Map<String, dynamic>.from(snapshot.value as Map);
      } else if (snapshot.value is List) {
        // Convert List to Map
        final list = snapshot.value as List;
        groupsMap = {};
        for (int i = 0; i < list.length; i++) {
          if (list[i] != null) {
            groupsMap[i.toString()] = list[i];
          }
        }
      } else {
        debugPrint('❌ Unexpected data type: ${snapshot.value.runtimeType}');
        return [];
      }

      List<Group> groups = [];

      groupsMap.forEach((key, value) {
        if (value != null && value is Map) {
          try {
            final group = Group.fromJson(key, value);
            if (group.metadata.name.toLowerCase().contains(query.toLowerCase())) {
              groups.add(group);
            }
          } catch (e) {
            debugPrint('❌ Error parsing group $key: $e');
          }
        }
      });

      debugPrint('✅ Found ${groups.length} groups matching "$query"');
      return groups;
    } catch (e, stackTrace) {
      debugPrint('❌ Error searching groups: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get user's groups
  Future<List<Group>> getUserGroups(String userId) async {
    try {
      final snapshot = await _database.ref('groups').get();

      if (!snapshot.exists) {
        debugPrint('No groups found in database');
        return [];
      }

      // Handle both Map and List from Firebase
      Map<String, dynamic> groupsMap;

      if (snapshot.value is Map) {
        groupsMap = Map<String, dynamic>.from(snapshot.value as Map);
      } else if (snapshot.value is List) {
        // Convert List to Map
        final list = snapshot.value as List;
        groupsMap = {};
        for (int i = 0; i < list.length; i++) {
          if (list[i] != null) {
            groupsMap[i.toString()] = list[i];
          }
        }
      } else {
        debugPrint('❌ Unexpected data type: ${snapshot.value.runtimeType}');
        return [];
      }

      List<Group> userGroups = [];

      groupsMap.forEach((key, value) {
        if (value != null && value is Map) {
          try {
            final group = Group.fromJson(key, value);
            if (group.isMember(userId)) {
              userGroups.add(group);
            }
          } catch (e) {
            debugPrint('❌ Error parsing group $key: $e');
          }
        }
      });

      // Sort by last activity
      userGroups.sort((a, b) =>
          b.stats.lastActivity.compareTo(a.stats.lastActivity)
      );

      debugPrint('✅ User $userId is in ${userGroups.length} groups');
      return userGroups;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting user groups: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Start a game from group (creates temporary room)
  Future<String> startGroupGame({
    required String groupId,
    required String hostId,
    required String hostName,
    required RoomSettings settings,
    required PuzzleData puzzle,
  }) async {
    // Import your existing RoomService
    final roomService = RoomService();

    // Create temporary room (reuse existing logic)
    final roomCode = await roomService.createRoom(
      hostId: hostId,
      hostName: hostName,
      settings: settings,
      puzzle: puzzle,
    );

    // Link room to group
    await _database.ref('rooms/$roomCode').update({
      'groupId': groupId,
    });

    // Update group last activity
    await _database.ref('groups/$groupId/stats').update({
      'lastActivity': ServerValue.timestamp,
    });

    print('✅ Group game started: room $roomCode for group $groupId');
    return roomCode;
  }

  /// Record game result after completion
  Future<void> recordGameResult({
    required String groupId,
    required String roomCode,
    required List<String> playerIds,
    required Map<String, int> scores,
    required String? winnerId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      final gameRef = _database.ref('groups/$groupId/gameHistory').push();
      final gameId = gameRef.key!;

      await gameRef.set({
        'roomCode': roomCode,
        'playerIds': playerIds,
        'scores': scores,
        'winnerId': winnerId,
        'timestamp': ServerValue.timestamp,
        'settings': settings,
      });

      // Update group stats
      await _database.ref('groups/$groupId/stats').update({
        'totalGames': ServerValue.increment(1),
        'lastActivity': ServerValue.timestamp,
      });

      // Update member stats
      for (String playerId in playerIds) {
        await _database.ref('groups/$groupId/members/$playerId').update({
          'gamesPlayed': ServerValue.increment(1),
        });
      }

      // Update winner stats
      if (winnerId != null) {
        await _database.ref('groups/$groupId/members/$winnerId').update({
          'wins': ServerValue.increment(1),
        });
      }

      print('✅ Game result recorded: $gameId in group $groupId');
    } catch (e) {
      print('❌ Error recording game result: $e');
    }
  }

  /// Leave a group
  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      final groupRef = _database.ref('groups/$groupId');
      final memberRef = groupRef.child('members/$userId');

      // Check if user is admin
      final memberSnapshot = await memberRef.get();
      if (!memberSnapshot.exists) {
        print('⚠️ User not in group');
        return;
      }

      final memberData = memberSnapshot.value as Map;
      final isAdmin = memberData['role'] == 'admin';

      // Get member count
      final membersSnapshot = await groupRef.child('members').get();
      final membersMap = membersSnapshot.value as Map;
      final memberCount = membersMap.length;

      if (isAdmin && memberCount > 1) {
        // Transfer admin to another member
        final otherMemberId = membersMap.keys
            .firstWhere((key) => key != userId, orElse: () => null);

        if (otherMemberId != null) {
          await groupRef.child('members/$otherMemberId').update({
            'role': 'admin',
          });
          print('✅ Admin transferred to $otherMemberId');
        }
      }

      // Remove member
      await memberRef.remove();

      // Update stats
      await groupRef.child('stats').update({
        'totalMembers': ServerValue.increment(-1),
        'lastActivity': ServerValue.timestamp,
      });

      // Delete group if no members left
      if (memberCount == 1) {
        await groupRef.remove();
        print('✅ Group deleted (no members left)');
      } else {
        print('✅ User $userId left group $groupId');
      }
    } catch (e) {
      print('❌ Error leaving group: $e');
    }
  }

  /// Listen to group updates (real-time)
  Stream<Group> listenToGroup(String groupId) {
    return _database.ref('groups/$groupId').onValue.map((event) {
      if (!event.snapshot.exists) {
        throw Exception('Group not found');
      }
      return Group.fromJson(groupId, event.snapshot.value as Map);
    });
  }

  /// Check if group exists by code
  Future<String?> getGroupIdByCode(String code) async {
    try {
      final snapshot = await _database
          .ref('groups')
          .orderByChild('metadata/code')
          .equalTo(code)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      final groupsMap = snapshot.value as Map;
      return groupsMap.keys.first;
    } catch (e) {
      print('❌ Error finding group by code: $e');
      return null;
    }
  }

  /// Update group metadata (admin only)
  Future<void> updateGroupMetadata({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

      if (updates.isNotEmpty) {
        await _database.ref('groups/$groupId/metadata').update(updates);
        print('✅ Group metadata updated');
      }
    } catch (e) {
      print('❌ Error updating group metadata: $e');
    }
  }
}
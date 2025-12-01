// File: services/group_service.dart

import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../models/group_models.dart';

class GroupService {
  final DatabaseReference _groupsRef = FirebaseDatabase.instance.ref('groups');

  /// Generates a unique 6-character group code (no I, O, 0, 1 to avoid confusion)
  String _generateGroupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new group — ONLY ONE MEMBER (the owner)
  Future<String> createGroup({
    required String ownerId,
    required String ownerName,
    required String groupName,
    GroupSettings? settings,
  }) async {
    try {
      String groupCode;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Find unique code
      while (true) {
        groupCode = _generateGroupCode();
        final snapshot = await _groupsRef.child(groupCode).get();
        if (!snapshot.exists) {
          // Create group with owner only
          await _groupsRef.child(groupCode).set({
            'name': groupName,
            'ownerId': ownerId,
            'settings': (settings ?? GroupSettings()).toJson(),
            'members': {
              ownerId: {
                'id': ownerId,
                'name': ownerName,
                'role': 'owner',
                'joinedAt': now,
                'isActive': true,     // Owner starts as active
                'lastSeen': now,
              },
            },
            'createdAt': now,
            'lastActivity': now,
          });
          return groupCode;
        }
      }
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  /// Join a group by code
  Future<bool> joinGroup({
    required String groupCode,
    required String memberId,
    required String memberName,
  }) async {
    try {
      final groupRef = _groupsRef.child(groupCode);
      final snapshot = await groupRef.get();

      if (!snapshot.exists) throw Exception('Group not found');

      final data = snapshot.value as Map<dynamic, dynamic>;
      final settings = GroupSettings.fromJson(data['settings'] ?? {});
      final members = data['members'] as Map<dynamic, dynamic>? ?? {};

      if (members.length >= settings.maxMembers) {
        throw Exception('Group is full');
      }

      if (members.containsKey(memberId)) {
        // Already a member — update lastSeen and activity
        final now = DateTime.now().millisecondsSinceEpoch;
        await groupRef.child('members/$memberId').update({
          'isActive': true,
          'lastSeen': now,
        });
        await groupRef.child('lastActivity').set(now);
        return true;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await groupRef.child('members/$memberId').set({
        'id': memberId,
        'name': memberName,
        'role': 'member',
        'joinedAt': now,
        'isActive': true,
        'lastSeen': now,
      });

      await groupRef.child('lastActivity').set(now);
      return true;
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  /// Leave a group — handles ownership transfer & group deletion
  Future<void> leaveGroup(String groupCode, String memberId) async {
    try {
      final groupRef = _groupsRef.child(groupCode);
      final snapshot = await groupRef.get();

      if (!snapshot.exists) throw Exception('Group not found');

      final data = snapshot.value as Map<dynamic, dynamic>;
      final ownerId = data['ownerId'] as String;
      final members = Map<String, dynamic>.from(data['members'] ?? {});

      // Remove member
      await groupRef.child('members/$memberId').remove();

      final now = DateTime.now().millisecondsSinceEpoch;
      await groupRef.child('lastActivity').set(now);

      // If owner is leaving
      if (memberId == ownerId) {
        final remaining = members.keys.where((id) => id != memberId).toList();

        if (remaining.isEmpty) {
          // Last member → delete entire group is deleted
          await groupRef.remove();
        } else {
          // Transfer ownership: prefer admin → oldest member
          String? newOwner;
          int oldestJoinTime = now;

          for (final id in remaining) {
            final memberData = members[id] as Map<dynamic, dynamic>;
            if (memberData['role'] == 'admin') {
              newOwner = id;
              break;
            }
            final joinedAt = memberData['joinedAt'] as int? ?? now;
            if (joinedAt < oldestJoinTime) {
              oldestJoinTime = joinedAt;
              newOwner = id;
            }
          }

          newOwner ??= remaining.first;

          await groupRef.child('ownerId').set(newOwner);
          await groupRef.child('members/$newOwner/role').set('owner');
        }
      }
    } catch (e) {
      throw Exception('Failed to leave group: $e');
    }
  }

  /// Set member active/inactive (presence system)
  Future<void> setMemberActive(String groupCode, String memberId, bool isActive) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _groupsRef.child('$groupCode/members/$memberId').update({
        'isActive': isActive,
        'lastSeen': now,
      });
      await _groupsRef.child('$groupCode/lastActivity').set(now);
    } catch (e) {
      print('Error updating presence: $e');
    }
  }

  /// Update member role (only owner)
  Future<bool> updateMemberRole({
    required String groupCode,
    required String memberId,
    required String newRole,
    required String requesterId,
  }) async {
    try {
      final snapshot = await _groupsRef.child(groupCode).get();
      if (!snapshot.exists) throw Exception('Group not found');

      final data = snapshot.value as Map<dynamic, dynamic>;
      final ownerId = data['ownerId'] as String;

      if (requesterId != ownerId) throw Exception('Only owner can change roles');
      if (memberId == ownerId) throw Exception('Cannot change owner role');

      await _groupsRef.child('$groupCode/members/$memberId/role').set(newRole);
      await _groupsRef.child('$groupCode/lastActivity').set(DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      print('Error updating role: $e');
      return false;
    }
  }

  /// Remove/kick a member (owner or admin)
  Future<bool> removeMember({
    required String groupCode,
    required String memberId,
    required String requesterId,
  }) async {
    try {
      final snapshot = await _groupsRef.child(groupCode).get();
      if (!snapshot.exists) throw Exception('Group not found');

      final data = snapshot.value as Map<dynamic, dynamic>;
      final ownerId = data['ownerId'] as String;
      final members = data['members'] as Map<dynamic, dynamic>? ?? {};

      final requesterRole = (members[requesterId] as Map?)?['role'] ?? '';
      final targetRole = (members[memberId] as Map?)?['role'] ?? '';

      if (memberId == ownerId) throw Exception('Cannot remove owner');
      if (requesterId != ownerId && requesterRole != 'admin') {
        if (targetRole == 'admin') throw Exception('Admins cannot remove other admins');
      }

      await _groupsRef.child('$groupCode/members/$memberId').remove();
      await _groupsRef.child('$groupCode/lastActivity').set(DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  /// Listen to a group — returns null if deleted
  Stream<Group?> listenToGroup(String groupCode) {
    return _groupsRef.child(groupCode).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return Group.fromJson(groupCode, data);
    });
  }

  /// Get all groups the user is in
  Future<List<Group>> getUserGroups(String userId) async {
    try {
      final snapshot = await _groupsRef.get();
      if (!snapshot.exists) return [];

      final allGroups = snapshot.value as Map<dynamic, dynamic>;
      final userGroups = <Group>[];

      allGroups.forEach((code, data) {
        if (data is Map) {
          final members = data['members'] as Map<dynamic, dynamic>? ?? {};
          if (members.containsKey(userId)) {
            userGroups.add(Group.fromJson(code.toString(), data));
          }
        }
      });

      userGroups.sort((a, b) {
        final aTime = a.lastActivity ?? a.createdAt;
        final bTime = b.lastActivity ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return userGroups;
    } catch (e) {
      throw Exception('Failed to load your groups: $e');
    }
  }

  /// NEW: Get all public (non-private) groups for discovery
  Future<List<Group>> getPublicGroups() async {
    try {
      final snapshot = await _groupsRef.get();
      if (!snapshot.exists) return [];

      final allGroups = snapshot.value as Map<dynamic, dynamic>;
      final publicGroups = <Group>[];

      allGroups.forEach((code, data) {
        if (data is Map) {
          final settingsMap = data['settings'] as Map<dynamic, dynamic>? ?? {};
          final isPrivate = settingsMap['isPrivate'] ?? false;
          if (!isPrivate) {
            publicGroups.add(Group.fromJson(code.toString(), data));
          }
        }
      });

      publicGroups.sort((a, b) {
        final aTime = a.lastActivity ?? a.createdAt;
        final bTime = b.lastActivity ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return publicGroups;
    } catch (e) {
      throw Exception('Failed to load public groups: $e');
    }
  }

  /// Update group settings (owner only)
  Future<bool> updateGroupSettings({
    required String groupCode,
    required String requesterId,
    required GroupSettings newSettings,
  }) async {
    try {
      final snapshot = await _groupsRef.child(groupCode).get();
      if (!snapshot.exists) return false;

      final data = snapshot.value as Map<dynamic, dynamic>;
      if (data['ownerId'] != requesterId) return false;

      await _groupsRef.child('$groupCode/settings').set(newSettings.toJson());
      await _groupsRef.child('$groupCode/lastActivity').set(DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update group name (owner only)
  Future<bool> updateGroupName({
    required String groupCode,
    required String requesterId,
    required String newName,
  }) async {
    try {
      final snapshot = await _groupsRef.child(groupCode).get();
      if (!snapshot.exists) return false;

      final data = snapshot.value as Map<dynamic, dynamic>;
      if (data['ownerId'] != requesterId) return false;

      await _groupsRef.child('$groupCode/name').set(newName);
      await _groupsRef.child('$groupCode/lastActivity').set(DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      return false;
    }
  }
}
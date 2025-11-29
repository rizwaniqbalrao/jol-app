// group_controller.dart - Group Management Controller
import 'dart:async';
import 'package:flutter/material.dart';
import '../../play/models/room_models.dart';
import '../models/group_metadata.dart';
import '../services/group_service.dart';

class GroupController extends ChangeNotifier {
  final GroupService _groupService = GroupService();
  final String userId;
  final String userName;

  List<Group> _myGroups = [];
  List<Group> _browseGroups = [];
  Group? _currentGroup;
  StreamSubscription? _groupSubscription;

  bool _isLoadingMyGroups = false;
  bool _isLoadingBrowse = false;
  String? _error;

  GroupController({
    required this.userId,
    required this.userName,
  }) {
    loadMyGroups();
  }

  // Getters
  List<Group> get myGroups => _myGroups;
  List<Group> get browseGroups => _browseGroups;
  Group? get currentGroup => _currentGroup;
  bool get isLoadingMyGroups => _isLoadingMyGroups;
  bool get isLoadingBrowse => _isLoadingBrowse;
  String? get error => _error;

  bool isCurrentUserAdmin() {
    if (_currentGroup == null) return false;
    return _currentGroup!.isAdmin(userId);
  }

  bool isCurrentUserMember() {
    if (_currentGroup == null) return false;
    return _currentGroup!.isMember(userId);
  }

  // Load user's groups
  Future<void> loadMyGroups() async {
    _isLoadingMyGroups = true;
    _error = null;
    notifyListeners();

    try {
      _myGroups = await _groupService.getUserGroups(userId);
      _isLoadingMyGroups = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load groups: $e';
      _isLoadingMyGroups = false;
      notifyListeners();
    }
  }

  // Browse public groups
  Future<void> loadBrowseGroups({int limit = 20}) async {
    _isLoadingBrowse = true;
    _error = null;
    notifyListeners();

    try {
      _browseGroups = await _groupService.browseGroups(limit: limit);
      _isLoadingBrowse = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to browse groups: $e';
      _isLoadingBrowse = false;
      notifyListeners();
    }
  }

  // Search groups
  Future<void> searchGroups(String query) async {
    if (query.isEmpty) {
      await loadBrowseGroups();
      return;
    }

    _isLoadingBrowse = true;
    _error = null;
    notifyListeners();

    try {
      _browseGroups = await _groupService.searchGroups(query);
      _isLoadingBrowse = false;
      notifyListeners();
    } catch (e) {
      _error = 'Search failed: $e';
      _isLoadingBrowse = false;
      notifyListeners();
    }
  }

  // Create new group
  Future<String?> createGroup({
    required String groupName,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      final groupId = await _groupService.createGroup(
        creatorId: userId,
        creatorName: userName,
        groupName: groupName,
        description: description,
        avatarUrl: avatarUrl,
      );

      await loadMyGroups();
      return groupId;
    } catch (e) {
      _error = 'Failed to create group: $e';
      notifyListeners();
      return null;
    }
  }

  // Join group by code
  Future<bool> joinGroupByCode(String code) async {
    try {
      final success = await _groupService.joinGroupByCode(
        groupCode: code.toUpperCase(),
        userId: userId,
        userName: userName,
      );

      if (success) {
        await loadMyGroups();
      }

      return success;
    } catch (e) {
      _error = 'Failed to join group: $e';
      notifyListeners();
      return false;
    }
  }

  // Join group by ID
  Future<bool> joinGroup(String groupId) async {
    try {
      final success = await _groupService.joinGroup(
        groupId: groupId,
        userId: userId,
        userName: userName,
      );

      if (success) {
        await loadMyGroups();
      }

      return success;
    } catch (e) {
      _error = 'Failed to join group: $e';
      notifyListeners();
      return false;
    }
  }

  // Start listening to a specific group
  void listenToGroup(String groupId) {
    _groupSubscription?.cancel();
    _groupSubscription = _groupService.listenToGroup(groupId).listen(
          (group) {
        _currentGroup = group;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Group listener error: $e';
        notifyListeners();
      },
    );
  }

  // Stop listening to current group
  void stopListeningToGroup() {
    _groupSubscription?.cancel();
    _currentGroup = null;
  }

  // Start game from group
  Future<String?> startGroupGame({
    required String groupId,
    required RoomSettings settings,
    required PuzzleData puzzle,
  }) async {
    try {
      final roomCode = await _groupService.startGroupGame(
        groupId: groupId,
        hostId: userId,
        hostName: userName,
        settings: settings,
        puzzle: puzzle,
      );

      return roomCode;
    } catch (e) {
      _error = 'Failed to start game: $e';
      notifyListeners();
      return null;
    }
  }

  // Record game result (call this after game ends)
  Future<void> recordGameResult({
    required String groupId,
    required String roomCode,
    required List<String> playerIds,
    required Map<String, int> scores,
    required String? winnerId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      await _groupService.recordGameResult(
        groupId: groupId,
        roomCode: roomCode,
        playerIds: playerIds,
        scores: scores,
        winnerId: winnerId,
        settings: settings,
      );

      // Refresh current group if viewing it
      if (_currentGroup?.metadata.id == groupId) {
        // Group will auto-update via listener
      }
    } catch (e) {
      _error = 'Failed to record result: $e';
      notifyListeners();
    }
  }

  // Leave group
  Future<void> leaveGroup(String groupId) async {
    try {
      await _groupService.leaveGroup(groupId, userId);
      await loadMyGroups();

      if (_currentGroup?.metadata.id == groupId) {
        stopListeningToGroup();
      }
    } catch (e) {
      _error = 'Failed to leave group: $e';
      notifyListeners();
    }
  }

  // Update group metadata (admin only)
  Future<void> updateGroupMetadata({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      await _groupService.updateGroupMetadata(
        groupId: groupId,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      _error = 'Failed to update group: $e';
      notifyListeners();
    }
  }

  // Get leaderboard for current group
  List<GroupMember> getLeaderboard() {
    if (_currentGroup == null) return [];
    return _currentGroup!.sortedMembersByWins;
  }

  // Get recent games for current group
  List<GameRecord> getRecentGames({int limit = 10}) {
    if (_currentGroup == null) return [];
    final games = _currentGroup!.sortedGameHistory;
    return games.take(limit).toList();
  }


  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }
}


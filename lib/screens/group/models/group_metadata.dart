// group_models.dart - Group System Models

import 'package:flutter/cupertino.dart';

class GroupMetadata {
  final String id;
  final String name;
  final String code;
  final String createdBy;
  final int createdAt;
  final String? description;
  final String? avatarUrl;

  GroupMetadata({
    required this.id,
    required this.name,
    required this.code,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'code': code,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'description': description,
    'avatarUrl': avatarUrl,
  };

  factory GroupMetadata.fromJson(String id, Map<dynamic, dynamic> json) {
    return GroupMetadata(
      id: id,
      name: json['name'] ?? 'Unnamed Group',
      code: json['code'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt: json['createdAt'] ?? 0,
      description: json['description'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class GroupMember {
  final String id;
  final String name;
  final String role; // 'admin' or 'member'
  final int joinedAt;
  final int gamesPlayed;
  final int wins;

  GroupMember({
    required this.id,
    required this.name,
    required this.role,
    required this.joinedAt,
    this.gamesPlayed = 0,
    this.wins = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'joinedAt': joinedAt,
    'gamesPlayed': gamesPlayed,
    'wins': wins,
  };

  factory GroupMember.fromJson(String id, Map<dynamic, dynamic> json) {
    return GroupMember(
      id: id,
      name: json['name'] ?? 'Unknown',
      role: json['role'] ?? 'member',
      joinedAt: json['joinedAt'] ?? 0,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      wins: json['wins'] ?? 0,
    );
  }

  bool get isAdmin => role == 'admin';

  GroupMember copyWith({
    String? name,
    String? role,
    int? joinedAt,
    int? gamesPlayed,
    int? wins,
  }) {
    return GroupMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
    );
  }
}

class GameRecord {
  final String id;
  final String roomCode;
  final List<String> playerIds;
  final Map<String, int> scores;
  final String? winnerId;
  final int timestamp;
  final Map<String, dynamic> settings;

  GameRecord({
    required this.id,
    required this.roomCode,
    required this.playerIds,
    required this.scores,
    this.winnerId,
    required this.timestamp,
    required this.settings,
  });

  Map<String, dynamic> toJson() => {
    'roomCode': roomCode,
    'playerIds': playerIds,
    'scores': scores,
    'winnerId': winnerId,
    'timestamp': timestamp,
    'settings': settings,
  };

  factory GameRecord.fromJson(String id, Map<dynamic, dynamic> json) {
    Map<String, int> parsedScores = {};
    if (json['scores'] != null) {
      final scoresMap = json['scores'] as Map;
      scoresMap.forEach((key, value) {
        parsedScores[key.toString()] = (value is num) ? value.toInt() : 0;
      });
    }

    List<String> parsedPlayerIds = [];
    if (json['playerIds'] != null) {
      if (json['playerIds'] is List) {
        parsedPlayerIds = (json['playerIds'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    return GameRecord(
      id: id,
      roomCode: json['roomCode'] ?? '',
      playerIds: parsedPlayerIds,
      scores: parsedScores,
      winnerId: json['winnerId'],
      timestamp: json['timestamp'] ?? 0,
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'])
          : {},
    );
  }
}

class GroupStats {
  final int totalGames;
  final int totalMembers;
  final int lastActivity;

  GroupStats({
    required this.totalGames,
    required this.totalMembers,
    required this.lastActivity,
  });

  Map<String, dynamic> toJson() => {
    'totalGames': totalGames,
    'totalMembers': totalMembers,
    'lastActivity': lastActivity,
  };

  factory GroupStats.fromJson(Map<dynamic, dynamic> json) {
    return GroupStats(
      totalGames: json['totalGames'] ?? 0,
      totalMembers: json['totalMembers'] ?? 0,
      lastActivity: json['lastActivity'] ?? 0,
    );
  }
}

// Add this to your group_metadata.dart
// Replace the existing Group.fromJson method with this robust version

class Group {
  final GroupMetadata metadata;
  final Map<String, GroupMember> members;
  final Map<String, GameRecord> gameHistory;
  final GroupStats stats;

  Group({
    required this.metadata,
    required this.members,
    required this.gameHistory,
    required this.stats,
  });

  factory Group.fromJson(String id, Map<dynamic, dynamic> json) {
    try {
      // Parse metadata
      GroupMetadata metadata = GroupMetadata.fromJson(
        id,
        json['metadata'] ?? {},
      );

      // Parse members - Handle both Map and List
      Map<String, GroupMember> members = {};
      if (json['members'] != null) {
        if (json['members'] is Map) {
          final membersMap = json['members'] as Map;
          membersMap.forEach((key, value) {
            if (value is Map) {
              try {
                members[key.toString()] = GroupMember.fromJson(
                  key.toString(),
                  value,
                );
              } catch (e) {
                debugPrint('❌ Error parsing member $key: $e');
              }
            }
          });
        } else if (json['members'] is List) {
          // Handle if stored as List
          final membersList = json['members'] as List;
          for (int i = 0; i < membersList.length; i++) {
            if (membersList[i] != null && membersList[i] is Map) {
              try {
                final memberMap = membersList[i] as Map;
                // Use index as key if no ID present
                final memberId = memberMap['id']?.toString() ?? i.toString();
                members[memberId] = GroupMember.fromJson(
                  memberId,
                  memberMap,
                );
              } catch (e) {
                debugPrint('❌ Error parsing member at index $i: $e');
              }
            }
          }
        }
      }

      // Parse game history - Handle both Map and List
      Map<String, GameRecord> gameHistory = {};
      if (json['gameHistory'] != null) {
        if (json['gameHistory'] is Map) {
          final historyMap = json['gameHistory'] as Map;
          historyMap.forEach((key, value) {
            if (value is Map) {
              try {
                gameHistory[key.toString()] = GameRecord.fromJson(
                  key.toString(),
                  value,
                );
              } catch (e) {
                debugPrint('❌ Error parsing game $key: $e');
              }
            }
          });
        } else if (json['gameHistory'] is List) {
          // Handle if stored as List
          final historyList = json['gameHistory'] as List;
          for (int i = 0; i < historyList.length; i++) {
            if (historyList[i] != null && historyList[i] is Map) {
              try {
                final gameMap = historyList[i] as Map;
                final gameId = gameMap['id']?.toString() ?? i.toString();
                gameHistory[gameId] = GameRecord.fromJson(
                  gameId,
                  gameMap,
                );
              } catch (e) {
                debugPrint('❌ Error parsing game at index $i: $e');
              }
            }
          }
        }
      }

      // Parse stats
      GroupStats stats = GroupStats.fromJson(json['stats'] ?? {});

      return Group(
        metadata: metadata,
        members: members,
        gameHistory: gameHistory,
        stats: stats,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error in Group.fromJson for ID $id: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  int get memberCount => members.length;

  List<GameRecord> get sortedGameHistory {
    final games = gameHistory.values.toList();
    games.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return games;
  }

  List<GroupMember> get sortedMembersByWins {
    final membersList = members.values.toList();
    membersList.sort((a, b) {
      int winsCompare = b.wins.compareTo(a.wins);
      if (winsCompare != 0) return winsCompare;
      return b.gamesPlayed.compareTo(a.gamesPlayed);
    });
    return membersList;
  }

  bool isMember(String userId) => members.containsKey(userId);
  bool isAdmin(String userId) => members[userId]?.isAdmin ?? false;
}
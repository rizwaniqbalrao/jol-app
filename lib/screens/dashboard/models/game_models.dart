// Game Models - models/game.dart

class Game {
  final String matchId;
  final String playerId;
  final String gameType; // "solo" or "multiplayer"
  final String gameMode; // "timed" or "untimed"
  final String operation; // "addition" or "subtraction"
  final int gridSize;
  final String timestamp; // ISO8601 UTC format
  final String status; // "completed", "abandoned", "timed_out"
  final int finalScore; // 0-100
  final double accuracyPercentage; // 0.0-100.0
  final int hintsUsed;
  final int? completionTime; // Required only for timed mode
  final String? roomCode; // Required for multiplayer (6 chars)
  final int? position; // Required for multiplayer (1 = first)
  final int? totalPlayers; // Required for multiplayer

  Game({
    required this.matchId,
    required this.playerId,
    required this.gameType,
    required this.gameMode,
    required this.operation,
    required this.gridSize,
    required this.timestamp,
    required this.status,
    required this.finalScore,
    required this.accuracyPercentage,
    required this.hintsUsed,
    this.completionTime,
    this.roomCode,
    this.position,
    this.totalPlayers,
  });

  // From JSON
  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      matchId: json['match_id'] as String? ?? '',
      playerId: json['player_id'] as String? ?? 'N/A',  // Handle missing player_id in list response
      gameType: json['game_type'] as String? ?? 'solo',
      gameMode: json['game_mode'] as String? ?? 'untimed',
      operation: json['operation'] as String? ?? 'addition',
      gridSize: json['grid_size'] as int? ?? 4,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      status: json['status'] as String? ?? 'completed',
      finalScore: json['final_score'] as int? ?? 0,
      accuracyPercentage: (json['accuracy_percentage'] as num?)?.toDouble() ?? 0.0,
      hintsUsed: json['hints_used'] as int? ?? 0,
      completionTime: json['completion_time'] as int?,
      roomCode: json['room_code'] as String?,
      position: json['position'] as int?,
      totalPlayers: json['total_players'] as int?,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'match_id': matchId,
      'player_id': playerId,
      'game_type': gameType,
      'game_mode': gameMode,
      'operation': operation,
      'grid_size': gridSize,
      'timestamp': timestamp,
      'status': status,
      'final_score': finalScore,
      'accuracy_percentage': accuracyPercentage,
      'hints_used': hintsUsed,
    };

    // Conditionally add optional fields to avoid sending unnecessary nulls
    if (completionTime != null) {
      json['completion_time'] = completionTime;
    }
    if (roomCode != null) {
      json['room_code'] = roomCode;
    }
    if (position != null) {
      json['position'] = position;
    }
    if (totalPlayers != null) {
      json['total_players'] = totalPlayers;
    }

    return json;
  }

  // CopyWith method
  Game copyWith({
    String? matchId,
    String? playerId,
    String? gameType,
    String? gameMode,
    String? operation,
    int? gridSize,
    String? timestamp,
    String? status,
    int? finalScore,
    double? accuracyPercentage,
    int? hintsUsed,
    int? completionTime,
    String? roomCode,
    int? position,
    int? totalPlayers,
  }) {
    return Game(
      matchId: matchId ?? this.matchId,
      playerId: playerId ?? this.playerId,
      gameType: gameType ?? this.gameType,
      gameMode: gameMode ?? this.gameMode,
      operation: operation ?? this.operation,
      gridSize: gridSize ?? this.gridSize,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      finalScore: finalScore ?? this.finalScore,
      accuracyPercentage: accuracyPercentage ?? this.accuracyPercentage,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      completionTime: completionTime ?? this.completionTime,
      roomCode: roomCode ?? this.roomCode,
      position: position ?? this.position,
      totalPlayers: totalPlayers ?? this.totalPlayers,
    );
  }

  @override
  String toString() {
    return 'Game(matchId: $matchId, playerId: $playerId, gameType: $gameType, '
        'gameMode: $gameMode, operation: $operation, status: $status, '
        'finalScore: $finalScore, accuracy: $accuracyPercentage%)';
  }
}

// Response for game history list
class GameHistoryResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<Game> results;

  GameHistoryResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory GameHistoryResponse.fromJson(Map<String, dynamic> json) {
    return GameHistoryResponse(
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: (json['results'] as List<dynamic>?)
          ?.map((item) => Game.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'next': next,
      'previous': previous,
      'results': results.map((game) => game.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'GameHistoryResponse(count: $count, resultsCount: ${results.length})';
  }
}

// Response for saving a game
class SaveGameResponse {
  final String detail;
  final String matchId;

  SaveGameResponse({
    required this.detail,
    required this.matchId,
  });

  factory SaveGameResponse.fromJson(Map<String, dynamic> json) {
    return SaveGameResponse(
      detail: json['detail'] as String? ?? '',
      matchId: json['match_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detail': detail,
      'match_id': matchId,
    };
  }

  @override
  String toString() {
    return 'SaveGameResponse(detail: $detail, matchId: $matchId)';
  }
}
// room_models.dart - FIXED VERSION

class RoomSettings {
  final int gridSize;
  final String mode;
  final String operation;
  final int timeLimit;
  final int maxHints;
  final int maxPlayers;
  final bool useDecimals; // ADDED
  final bool hardMode; // ADDED

  RoomSettings({
    required this.gridSize,
    required this.mode,
    required this.operation,
    this.timeLimit = 300,
    this.maxHints = 2,
    this.maxPlayers = 4,
    this.useDecimals = false, // ADDED
    this.hardMode = false, // ADDED
  });

  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'mode': mode,
        'operation': operation,
        'timeLimit': timeLimit,
        'maxHints': maxHints,
        'maxPlayers': maxPlayers,
        'useDecimals': useDecimals, // ADDED
        'hardMode': hardMode,
      };

  factory RoomSettings.fromJson(Map<dynamic, dynamic> json) => RoomSettings(
        gridSize: json['gridSize'] ?? 4,
        mode: json['mode'] ?? 'untimed',
        operation: json['operation'] ?? 'addition',
        timeLimit: json['timeLimit'] ?? 300,
        maxHints: json['maxHints'] ?? 2,
        maxPlayers: json['maxPlayers'] ?? 4,
        useDecimals: json['useDecimals'] ?? false, // ADDED
        hardMode: json['hardMode'] ?? false,
      );
}

class PuzzleData {
  final List<List<double?>> grid;
  final List<List<double?>> solution;
  final List<List<bool>> isFixed;

  PuzzleData({
    required this.grid,
    required this.solution,
    required this.isFixed,
  });

  Map<String, dynamic> toJson() => {
        'grid': grid.map((row) => row.map((cell) => cell).toList()).toList(),
        'solution':
            solution.map((row) => row.map((cell) => cell).toList()).toList(),
        'isFixed':
            isFixed.map((row) => row.map((cell) => cell).toList()).toList(),
      };

  factory PuzzleData.fromJson(Map<dynamic, dynamic> json) {
    try {
      return PuzzleData(
        grid: _parseGrid(json['grid']),
        solution: _parseGrid(json['solution']),
        isFixed: _parseFixed(json['isFixed']),
      );
    } catch (e) {
      print('❌ Error parsing PuzzleData: $e');
      rethrow;
    }
  }

  static List<List<double?>> _parseGrid(dynamic data) {
    if (data == null) {
      print('⚠️ Grid data is null');
      return [];
    }

    List<dynamic> dataList;

    // Convert Map to List if necessary (Firebase behavior)
    if (data is Map) {
      print('🔄 Converting Map to List for grid');
      // Sort keys numerically to maintain order
      final sortedKeys = data.keys.toList()
        ..sort((a, b) {
          int aInt = int.tryParse(a.toString()) ?? 0;
          int bInt = int.tryParse(b.toString()) ?? 0;
          return aInt.compareTo(bInt);
        });
      dataList = sortedKeys.map((key) => data[key]).toList();
    } else if (data is List) {
      dataList = data;
    } else {
      print('❌ Unexpected data type: ${data.runtimeType}');
      return [];
    }

    // Parse rows
    final rows = <List<double?>>[];
    for (var i = 0; i < dataList.length; i++) {
      var row = dataList[i];

      if (row == null) {
        print('⚠️ Row $i is null');
        rows.add(<double?>[]);
        continue;
      }

      List<dynamic> rowList;

      // Convert row Map to List if necessary
      if (row is Map) {
        final sortedKeys = row.keys.toList()
          ..sort((a, b) {
            int aInt = int.tryParse(a.toString()) ?? 0;
            int bInt = int.tryParse(b.toString()) ?? 0;
            return aInt.compareTo(bInt);
          });
        rowList = sortedKeys.map((key) => row[key]).toList();
      } else if (row is List) {
        rowList = row;
      } else {
        print('❌ Unexpected row type at index $i: ${row.runtimeType}');
        rows.add(<double?>[]);
        continue;
      }

      // Parse cells
      final cells = <double?>[];
      for (var j = 0; j < rowList.length; j++) {
        final cell = rowList[j];
        if (cell == null) {
          cells.add(null);
        } else if (cell is num) {
          cells.add(cell.toDouble());
        } else if (cell is String) {
          cells.add(double.tryParse(cell));
        } else {
          print('⚠️ Unexpected cell type at [$i][$j]: ${cell.runtimeType}');
          cells.add(null);
        }
      }

      rows.add(cells);
    }

    print('✅ Parsed grid: ${rows.length} rows');
    return rows;
  }

  static List<List<bool>> _parseFixed(dynamic data) {
    if (data == null) {
      print('⚠️ isFixed data is null');
      return [];
    }

    List<dynamic> dataList;

    if (data is Map) {
      print('🔄 Converting Map to List for isFixed');
      final sortedKeys = data.keys.toList()
        ..sort((a, b) {
          int aInt = int.tryParse(a.toString()) ?? 0;
          int bInt = int.tryParse(b.toString()) ?? 0;
          return aInt.compareTo(bInt);
        });
      dataList = sortedKeys.map((key) => data[key]).toList();
    } else if (data is List) {
      dataList = data;
    } else {
      print('❌ Unexpected isFixed type: ${data.runtimeType}');
      return [];
    }

    final rows = <List<bool>>[];
    for (var i = 0; i < dataList.length; i++) {
      var row = dataList[i];

      if (row == null) {
        print('⚠️ isFixed row $i is null');
        rows.add(<bool>[]);
        continue;
      }

      List<dynamic> rowList;

      if (row is Map) {
        final sortedKeys = row.keys.toList()
          ..sort((a, b) {
            int aInt = int.tryParse(a.toString()) ?? 0;
            int bInt = int.tryParse(b.toString()) ?? 0;
            return aInt.compareTo(bInt);
          });
        rowList = sortedKeys.map((key) => row[key]).toList();
      } else if (row is List) {
        rowList = row;
      } else {
        print('❌ Unexpected isFixed row type at $i: ${row.runtimeType}');
        rows.add(<bool>[]);
        continue;
      }

      final cells = rowList.map((cell) => cell == true).toList();
      rows.add(cells);
    }

    print('✅ Parsed isFixed: ${rows.length} rows');
    return rows;
  }
}

class GameState {
  final String status;
  final String hostId;
  final int? startTime;
  final int? endTime;

  GameState({
    required this.status,
    required this.hostId,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'hostId': hostId,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory GameState.fromJson(Map<dynamic, dynamic> json) => GameState(
        status: json['status'] ?? 'waiting',
        hostId: json['hostId'] ?? '',
        startTime: json['startTime'],
        endTime: json['endTime'],
      );
}

class Player {
  final String id;
  final String name;
  final bool isReady;
  final int score;
  final int hintsUsed;
  final int? completedAt;
  final bool isActive;
  final bool isHost;
  final int? lastUpdated;

  Player({
    required this.id,
    required this.name,
    this.isReady = false,
    this.score = 0,
    this.hintsUsed = 0,
    this.completedAt,
    this.isActive = true,
    this.isHost = false,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isReady': isReady,
        'score': score,
        'hintsUsed': hintsUsed,
        'completedAt': completedAt,
        'isActive': isActive,
        'isHost': isHost,
        'lastUpdated': lastUpdated,
      };

  factory Player.fromJson(String id, Map<dynamic, dynamic> json) => Player(
        id: id,
        name: json['name'] ?? 'Unknown',
        isReady: json['isReady'] ?? false,
        score: (json['score'] is num) ? (json['score'] as num).toInt() : 0,
        hintsUsed:
            (json['hintsUsed'] is num) ? (json['hintsUsed'] as num).toInt() : 0,
        completedAt: json['completedAt'],
        isActive: json['isActive'] ?? true,
        isHost: json['isHost'] ?? false,
        lastUpdated: json['lastUpdated'],
      );

  Player copyWith({
    String? name,
    bool? isReady,
    int? score,
    int? hintsUsed,
    int? completedAt,
    bool? isActive,
    bool? isHost,
    int? lastUpdated,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      isReady: isReady ?? this.isReady,
      score: score ?? this.score,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      completedAt: completedAt ?? this.completedAt,
      isActive: isActive ?? this.isActive,
      isHost: isHost ?? this.isHost,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get isCompleted => completedAt != null || score >= 100;
}

class Room {
  final String id;
  final RoomSettings settings;
  final PuzzleData? puzzle;
  final GameState gameState;
  final Map<String, Player> players;
  final String? winnerId;

  Room({
    required this.id,
    required this.settings,
    this.puzzle,
    required this.gameState,
    required this.players,
    this.winnerId,
  });

  factory Room.fromJson(String id, Map<dynamic, dynamic> json) {
    Map<String, Player> parsePlayers = {};
    if (json['players'] != null) {
      final rawPlayers = json['players'];
      if (rawPlayers is Map) {
        rawPlayers.forEach((key, value) {
          if (value is Map) {
            parsePlayers[key.toString()] =
                Player.fromJson(key.toString(), value);
          }
        });
      }
    }

    return Room(
      id: id,
      settings: RoomSettings.fromJson(json['settings'] ?? {}),
      puzzle:
          json['puzzle'] != null ? PuzzleData.fromJson(json['puzzle']) : null,
      gameState: GameState.fromJson(json['gameState'] ?? {}),
      players: parsePlayers,
      winnerId: json['results']?['winnerId'],
    );
  }

  int get playerCount => players.length;
  bool get isFull => playerCount >= settings.maxPlayers;
  bool get allPlayersReady => players.values.every((p) => p.isReady);
  bool get canStart => allPlayersReady && playerCount >= 2;
}

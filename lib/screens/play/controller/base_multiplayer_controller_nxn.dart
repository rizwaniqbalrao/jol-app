import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';
import 'base_game_controller_nxn.dart'; // Import for PuzzleOperation and shared logic if needed

abstract class BaseMultiplayerControllerNxN extends ChangeNotifier {
  final RoomService _roomService = RoomService();
  final String roomCode;
  final String playerId;

  Room? _room;
  StreamSubscription? _roomSubscription;
  Timer? _timerCountdown;
  Duration timeLeft = const Duration(minutes: 10);

  // Local gameplay - dynamic size
  int gridSize = 4;
  List<List<double?>> grid = [];
  List<List<bool>> isWrong = [];
  List<List<bool>> isHinted = [];
  int localScore = 0;
  int hintPenalty = 0;
  bool isSubmitted = false;
  bool isPlaying = false;

  // Game metrics tracking
  DateTime? _gameStartTime;
  int? _completionTimeSeconds;
  int _correctAnswers = 0;
  int _totalPlayerCells = 0;
  double _accuracyPercentage = 0.0;

  BaseMultiplayerControllerNxN({
    required this.roomCode,
    required this.playerId,
  }) {
    _listenToRoom();
  }

  // Getters
  Room? get room => _room;
  Player? get currentPlayer => _room?.players[playerId];
  bool get isHost => _room?.gameState.hostId == playerId;
  bool get canStart => isHost && (_room?.canStart ?? false);
  int get hintsRemaining =>
      (_room?.settings.maxHints ?? 2) - (currentPlayer?.hintsUsed ?? 0);

  // Metrics getters
  int get correctAnswers => _correctAnswers;
  int get totalPlayerCells => _totalPlayerCells;
  double get accuracyPercentage => _accuracyPercentage;
  int? get completionTimeSeconds => _completionTimeSeconds;
  DateTime? get gameStartTime => _gameStartTime;

  // --------------------------------------------------
  // Listen to room updates
  // --------------------------------------------------
  void _listenToRoom() {
    _roomSubscription = _roomService.listenToRoom(roomCode).listen(
      (room) {
        _room = room;

        // Initialize grid when puzzle arrives
        if (room.puzzle != null && grid.isEmpty) {
          final initSuccess = _initializeLocalGrid(room.puzzle!);
          if (!initSuccess) {
            debugPrint("❌ Failed to initialize grid - puzzle data invalid");
            return;
          }
        }

        // Start timer when game starts
        if (room.gameState.status == 'playing' && !isPlaying) {
          _startGame();
        }

        // End game when status changes
        if (room.gameState.status == 'ended' && isPlaying) {
          _endGame();
        }

        // Check if all players completed whenever room updates
        if (isPlaying && room.gameState.status == 'playing') {
          final allDone = room.players.values.every((p) => p.isCompleted);
          if (allDone) {
            debugPrint("🔥 Room update detected: All players completed!");
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_room?.gameState.status == 'playing') {
                _roomService.endGame(roomCode);
              }
            });
          }
        }

        notifyListeners();
      },
      onError: (e) {
        debugPrint('❌ Room listener error: $e');
      },
    );
  }

  // --------------------------------------------------
  // Local grid setup
  // --------------------------------------------------
  bool _initializeLocalGrid(PuzzleData puzzle) {
    try {
      if (puzzle.grid.isEmpty) {
        debugPrint("❌ Puzzle grid is empty");
        return false;
      }

      gridSize = puzzle.grid.length;

      // Validate puzzle data structure
      if (puzzle.isFixed.isEmpty || puzzle.isFixed.length != gridSize) {
        debugPrint(
            "❌ Puzzle isFixed dimensions mismatch: expected $gridSize rows, got ${puzzle.isFixed.length}");
        return false;
      }
      if (puzzle.solution.isEmpty || puzzle.solution.length != gridSize) {
        debugPrint(
            "❌ Puzzle solution dimensions mismatch: expected $gridSize rows, got ${puzzle.solution.length}");
        return false;
      }

      grid = List.generate(
        gridSize,
        (i) => List.generate(gridSize, (j) => null),
      );
      isWrong = List.generate(
        gridSize,
        (_) => List.filled(gridSize, false),
      );
      isHinted = List.generate(
        gridSize,
        (_) => List.filled(gridSize, false),
      );

      for (int i = 0; i < gridSize; i++) {
        for (int j = 0; j < gridSize; j++) {
          if (i == 0 && j == 0) {
            grid[0][0] = -1;
            continue;
          }

          // Safe bounds checking with proper validation
          bool cellIsFixed = false;
          if (i < puzzle.isFixed.length && j < puzzle.isFixed[i].length) {
            cellIsFixed = puzzle.isFixed[i][j];
          }

          if (cellIsFixed) {
            if (i < puzzle.grid.length && j < puzzle.grid[i].length) {
              final rawValue = puzzle.grid[i][j];
              // Round to 1 decimal place to avoid floating-point errors
              grid[i][j] =
                  rawValue != null ? (rawValue * 10).round() / 10.0 : null;
            }
            if (grid[i][j] == null || grid[i][j] == -1) {
              if (i < puzzle.solution.length && j < puzzle.solution[i].length) {
                final rawValue = puzzle.solution[i][j];
                // Round to 1 decimal place to avoid floating-point errors
                grid[i][j] =
                    rawValue != null ? (rawValue * 10).round() / 10.0 : null;
              }
            }
          } else {
            grid[i][j] = null;
          }
        }
      }

      debugPrint(
          "✅ Local grid initialized successfully ($gridSize x $gridSize)");
      return true;
    } catch (e) {
      debugPrint("❌ Error initializing grid: $e");
      return false;
    }
  }

  // --------------------------------------------------
  // Game state and timer
  // --------------------------------------------------
  void _startGame() {
    isPlaying = true;
    _gameStartTime = DateTime.now();

    if (_room?.settings.mode == 'timed') {
      timeLeft = Duration(seconds: _room?.settings.timeLimit ?? 300);
      _startTimer();
    }

    debugPrint("🎮 Game started at $_gameStartTime");
    notifyListeners();
  }

  void _startTimer() {
    _timerCountdown?.cancel();
    final startTime = _room?.gameState.startTime;
    if (startTime == null) return;

    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = (now - startTime) ~/ 1000;
      final totalSeconds = _room!.settings.timeLimit;
      final remaining = totalSeconds - elapsed;

      if (remaining <= 0) {
        timeLeft = Duration.zero;
        timer.cancel();
        _handleTimeUp();
      } else {
        timeLeft = Duration(seconds: remaining);
      }

      notifyListeners();
    });
  }

  void _handleTimeUp() {
    isPlaying = false;
    if (_gameStartTime != null) {
      _completionTimeSeconds =
          DateTime.now().difference(_gameStartTime!).inSeconds;
    }
    if (isHost) _roomService.endGame(roomCode);
    notifyListeners();
  }

  void _endGame() {
    isPlaying = false;
    _timerCountdown?.cancel();
    if (_gameStartTime != null && _completionTimeSeconds == null) {
      _completionTimeSeconds =
          DateTime.now().difference(_gameStartTime!).inSeconds;
    }
    notifyListeners();
  }

  // --------------------------------------------------
  // Player actions
  // --------------------------------------------------
  Future<void> toggleReady() async {
    if (currentPlayer == null) return;
    await _roomService.togglePlayerReady(
      roomCode,
      playerId,
      !currentPlayer!.isReady,
    );
  }

  Future<void> startGame() async {
    if (!isHost || !canStart) return;
    await _roomService.startGame(roomCode);
  }

  // --------------------------------------------------
  // Gameplay Logic
  // --------------------------------------------------
  void updateCell(int row, int col, double? value) {
    if (!isPlaying || isSubmitted) return;

    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) return;
    if (row == 0 && col == 0) return;
    if (_room?.puzzle?.isFixed[row][col] == true) return;
    if (isHinted[row][col]) return;
    if (value != null && value < 0) return;

    if (value != null) {
      grid[row][col] = (value * 10).round() / 10.0;
    } else {
      grid[row][col] = null;
    }
    _validateGrid(progressOnly: true);
    notifyListeners();
  }

  bool _validateCellMath(int row, int col, double tolerance) {
    if (_room?.puzzle == null) return false;

    // Validate based on Headers (Row 0 or Col 0) or Middle Cells logic
    // NOTE: Validation logic:
    // Col Header (row=0, col>0): colhead = middle[n][col] ± rowhead[n]
    // Row Header (row>0, col=0): rowhead = middle[row][n] ± colhead[n]
    // Middle (row>0, col>0): middle = rowhead[row] ± colhead[col]

    final operation = _room!.settings.operation;

    if (row == 0 && col > 0) {
      // Validation for Column Header using ANY middle cell in this column
      for (int n = 1; n < gridSize; n++) {
        final middleNum = grid[n][col];
        final rowHead = grid[n][0];
        if (middleNum != null && rowHead != null) {
          double expected;
          if (operation == 'addition') {
            // colhead = middle + rowhead
            expected = middleNum + rowHead;
          } else {
            // colhead = |middle - rowhead|
            expected = (middleNum - rowHead).abs();
          }
          if ((grid[row][col]! - expected).abs() <= tolerance) return true;
        }
      }
    } else if (row > 0 && col == 0) {
      // Validation for Row Header using ANY middle cell in this row
      for (int n = 1; n < gridSize; n++) {
        final middleNum = grid[row][n];
        final colHead = grid[0][n];
        if (middleNum != null && colHead != null) {
          double expected;
          if (operation == 'addition') {
            // rowhead = middle + colhead
            expected = middleNum + colHead;
          } else {
            // rowhead = |middle - colhead|
            expected = (middleNum - colHead).abs();
          }
          if ((grid[row][col]! - expected).abs() <= tolerance) return true;
        }
      }
    } else if (row > 0 && col > 0) {
      // Middle Cell
      final rowHead = grid[row][0];
      final colHead = grid[0][col];
      if (rowHead != null && colHead != null) {
        double expected;
        if (operation == 'addition') {
          // middle = rowhead + colhead
          expected = rowHead + colHead;
        } else {
          // middle = |rowhead - colhead|
          expected = (rowHead - colHead).abs();
        }
        if ((grid[row][col]! - expected).abs() <= tolerance) return true;
      }
    }
    return false;
  }

  // --------------------------------------------------
  // Calculation Logic: Given 2 of 3 values, find the 3rd
  // rowhead = grid[row][0]
  // colhead = grid[0][col]
  // middlenum = grid[row][col]
  // --------------------------------------------------
  /// Calculates the third value when two of {rowhead, colhead, middlenum} are known
  /// Returns the calculated value, or null if insufficient data
  double? calculateMissingValue({
    double? rowhead,
    double? colhead,
    double? middlenum,
    required PuzzleOperation operation,
  }) {
    int knownCount = 0;
    if (rowhead != null) knownCount++;
    if (colhead != null) knownCount++;
    if (middlenum != null) knownCount++;

    // Need exactly 2 known values to calculate the 3rd
    if (knownCount != 2) return null;

    if (operation == PuzzleOperation.addition) {
      // Forward: middlenum = rowhead + colhead
      // Reverse: rowhead = middlenum - colhead
      // Reverse: colhead = middlenum - rowhead
      if (rowhead != null && colhead != null) {
        return rowhead + colhead;
      } else if (rowhead != null && middlenum != null) {
        return middlenum - rowhead;
      } else if (colhead != null && middlenum != null) {
        return middlenum - colhead;
      }
    } else {
      // Subtraction (absolute difference)
      // Forward: middlenum = |rowhead - colhead|
      // Reverse: rowhead = middlenum + colhead or middlenum - colhead (both possibilities)
      // Reverse: colhead = middlenum + rowhead or middlenum - rowhead (both possibilities)
      if (rowhead != null && colhead != null) {
        return (rowhead - colhead).abs();
      } else if (rowhead != null && middlenum != null) {
        // middlenum = |rowhead - colhead|
        // colhead could be: rowhead - middlenum or rowhead + middlenum
        // Return the first valid possibility
        return rowhead - middlenum;
      } else if (colhead != null && middlenum != null) {
        // middlenum = |rowhead - colhead|
        // rowhead could be: colhead - middlenum or colhead + middlenum
        // Return the first valid possibility
        return colhead - middlenum;
      }
    }
    return null;
  }

  void _validateGrid({bool progressOnly = false}) {
    if (_room?.puzzle == null) return;

    final puzzle = _room!.puzzle!;
    int correctCount = 0;
    int totalPlayerCells = 0;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        bool cellIsFixed = false;
        if (i < puzzle.isFixed.length && j < puzzle.isFixed[i].length) {
          cellIsFixed = puzzle.isFixed[i][j];
        }
        if (!cellIsFixed) totalPlayerCells++;
      }
    }

    _totalPlayerCells = totalPlayerCells;

    for (var i = 0; i < gridSize; i++) {
      for (var j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        bool cellIsFixed = false;
        if (i < puzzle.isFixed.length && j < puzzle.isFixed[i].length) {
          cellIsFixed = puzzle.isFixed[i][j];
        }
        if (cellIsFixed) continue;

        final current = grid[i][j];

        bool isCorrect = false;
        if (current != null) {
          const tolerance = 0.0001;
          isCorrect = _validateCellMath(i, j, tolerance);

          // DEBUG LOGGING
          if (!isCorrect) {
            debugPrint(
                "❌ Cell [$i][$j] Incorrect: User=$current (math validation failed)");
          }
        }

        if (isCorrect) correctCount++;
        if (current != null && !isCorrect) {
          isWrong[i][j] = true;
        }
      }
    }

    _correctAnswers = correctCount;
    if (_totalPlayerCells > 0) {
      _accuracyPercentage = (correctCount / _totalPlayerCells) * 100;
    } else {
      _accuracyPercentage = 0.0;
    }

    debugPrint(
        "📊 Validation Result: $correctCount / $_totalPlayerCells correct. Accuracy: ${_accuracyPercentage.toStringAsFixed(1)}%. Score: $localScore");
    debugPrint(
        "   Validation: Header-based math (${_room?.settings.operation})");

    int progressScore = totalPlayerCells > 0
        ? (correctCount / totalPlayerCells * 100).round()
        : 0;

    if (!progressOnly) {
      localScore = _calculateFinalScore(correctCount, totalPlayerCells);
      if (_gameStartTime != null) {
        _completionTimeSeconds =
            DateTime.now().difference(_gameStartTime!).inSeconds;
      }
      _roomService.updateScore(roomCode, playerId, localScore);
      _markSubmitted();
      if (_room?.settings.mode == 'untimed') {
        _checkIfAllCompleted();
      }
    } else {
      localScore = (progressScore - hintPenalty).clamp(0, 100);
      _roomService.updateScore(roomCode, playerId, localScore);
    }

    notifyListeners();
  }

  double _getMultiplier() {
    // 4×4 grid
    if (gridSize == 4) {
      if (!(_room?.settings.useDecimals ?? false) && !(_room?.settings.hardMode ?? false)) return 1.0;  // Integer Easy
      if ((_room?.settings.useDecimals ?? false) && !(_room?.settings.hardMode ?? false)) return 1.1;   // Decimal Easy
      if (!(_room?.settings.useDecimals ?? false) && (_room?.settings.hardMode ?? false)) return 1.1;   // Integer Hard
      if ((_room?.settings.useDecimals ?? false) && (_room?.settings.hardMode ?? false)) return 1.3;    // Decimal Hard
    }
    
    // 5×5 grid
    if (gridSize == 5) {
      if (!(_room?.settings.useDecimals ?? false) && !(_room?.settings.hardMode ?? false)) return 1.1;  // Integer Easy
      if ((_room?.settings.useDecimals ?? false) && !(_room?.settings.hardMode ?? false)) return 1.3;   // Decimal Easy
      if (!(_room?.settings.useDecimals ?? false) && (_room?.settings.hardMode ?? false)) return 1.3;   // Integer Hard
      if ((_room?.settings.useDecimals ?? false) && (_room?.settings.hardMode ?? false)) return 1.5;    // Decimal Hard
    }
    
    // 6×6 grid
    if (gridSize == 6) {
      if (!(_room?.settings.useDecimals ?? false) && !(_room?.settings.hardMode ?? false)) return 1.2;  // Integer Easy
      if ((_room?.settings.useDecimals ?? false) && !(_room?.settings.hardMode ?? false)) return 1.4;   // Decimal Easy
      if (!(_room?.settings.useDecimals ?? false) && (_room?.settings.hardMode ?? false)) return 1.4;   // Integer Hard
      if ((_room?.settings.useDecimals ?? false) && (_room?.settings.hardMode ?? false)) return 1.6;    // Decimal Hard
    }
    
    return 1.0; // Default fallback
  }

  int _calculateFinalScore(int correctCount, int totalPlayerCells) {
    // Base Score = Correct Answers × 5
    int baseScore = correctCount * 5;
    
    // Time Bonus = Seconds Remaining × 2 (only for timed mode AND if all correct)
    int timeBonus = 0;
    if (_room?.settings.mode == 'timed' && correctCount == totalPlayerCells && totalPlayerCells > 0) {
      timeBonus = timeLeft.inSeconds * 2;
    }
    
    // Total Score = (Base Score + Time Bonus) × Multiplier
    double multiplier = _getMultiplier();
    int score = ((baseScore + timeBonus) * multiplier).round();
    
    // Apply hint penalty
    return (score - hintPenalty).clamp(0, 999999);
  }

  Future<void> _checkIfAllCompleted() async {
    if (_room == null) return;
    final allDone = _room!.players.values.every((p) => p.isCompleted);
    if (allDone) {
      await _roomService.endGame(roomCode);
    }
  }

  Future<void> submitGame() async {
    if (isSubmitted || !isPlaying) return;
    if (_room?.settings.mode == 'timed') {
      _timerCountdown?.cancel();
    }
    _validateGrid(progressOnly: false);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_room != null && isSubmitted) {
        _checkIfAllCompleted();
      }
    });
  }

  void _markSubmitted() {
    isSubmitted = true;
    isPlaying = false; // Stop playing locally once submitted
    _roomService.markCompleted(roomCode, playerId, localScore);
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkIfAllCompleted();
    });
  }

  Future<bool> useHint(int row, int col) async {
    if (!isPlaying || _room?.puzzle == null || isSubmitted) return false;
    if (currentPlayer == null ||
        currentPlayer!.hintsUsed >= (_room!.settings.maxHints)) return false;
    if (row == 0 && col == 0) return false;

    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) return false;
    if (_room!.puzzle!.isFixed[row][col]) return false;

    double? correctValue;
    if (row < _room!.puzzle!.solution.length &&
        col < _room!.puzzle!.solution[row].length) {
      correctValue = _room!.puzzle!.solution[row][col];
    }
    if (correctValue == null) return false;

    grid[row][col] = correctValue;
    isHinted[row][col] = true;
    await _roomService.incrementHintUsage(roomCode, playerId);
    hintPenalty += 5;
    _validateGrid(progressOnly: true);
    return true;
  }

  List<Player> getLeaderboard() {
    if (_room == null) return [];
    final playersList = _room!.players.values.toList();
    playersList.sort((a, b) {
      int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      if (a.completedAt != null && b.completedAt != null) {
        return a.completedAt!.compareTo(b.completedAt!);
      }
      return 0;
    });
    return playersList;
  }

  bool get allPlayersSubmitted {
    if (_room == null) return false;
    return _room!.players.values.every((p) => p.isCompleted);
  }

  void resetMetrics() {
    _gameStartTime = null;
    _completionTimeSeconds = null;
    _correctAnswers = 0;
    _totalPlayerCells = 0;
    _accuracyPercentage = 0.0;
    hintPenalty = 0;
  }

  Future<void> leaveRoom() async {
    await _roomService.removePlayer(roomCode, playerId);
    _roomSubscription?.cancel();
    _timerCountdown?.cancel();
    isPlaying = false;
    resetMetrics();
    notifyListeners();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _timerCountdown?.cancel();
    super.dispose();
  }
}

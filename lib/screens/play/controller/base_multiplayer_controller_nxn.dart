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
  Duration timeLeft = const Duration(minutes: 5);

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
              grid[i][j] = puzzle.grid[i][j];
            }
            if (grid[i][j] == null || grid[i][j] == -1) {
              if (i < puzzle.solution.length && j < puzzle.solution[i].length) {
                grid[i][j] = puzzle.solution[i][j];
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

    grid[row][col] = value;
    _validateGrid(progressOnly: true);
    notifyListeners();
  }

  void _validateGrid({bool progressOnly = false}) {
    if (_room?.puzzle == null) return;

    final puzzle = _room!.puzzle!;
    int correctCount = 0;
    int filledCount = 0;
    int totalPlayerCells = 0;
    double tolerance = 0.01;

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
        double? correct;
        if (i < puzzle.solution.length && j < puzzle.solution[i].length) {
          correct = puzzle.solution[i][j];
        }

        if (current != null) filledCount++;

        bool isCorrect = false;
        if (current != null && correct != null) {
          isCorrect = (current - correct).abs() < tolerance;
        }

        if (isCorrect) correctCount++;
        if (current != null && correct != null && !isCorrect) {
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

  int _calculateFinalScore(int correctCount, int totalPlayerCells) {
    if (_room?.settings.mode == 'untimed') {
      int accuracyScore = totalPlayerCells > 0
          ? (correctCount / totalPlayerCells * 100).round()
          : 0;
      return (accuracyScore - hintPenalty).clamp(0, 100);
    }

    int accuracyScore = totalPlayerCells > 0
        ? (correctCount / totalPlayerCells * 100).round()
        : 0;
    int timeBonus = _calculateTimeBonus();
    int finalScore = ((accuracyScore * 0.7) + (timeBonus * 0.3)).round();
    return (finalScore - hintPenalty).clamp(0, 100);
  }

  int _calculateTimeBonus() {
    if (_room?.settings.mode != 'timed') return 0;
    final completedPlayers = _room!.players.values
        .where((player) => player.isCompleted && player.completedAt != null)
        .toList();
    if (completedPlayers.isEmpty || completedPlayers.length == 1) return 100;
    completedPlayers.sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
    int currentPlayerIndex =
        completedPlayers.indexWhere((player) => player.id == playerId);
    if (currentPlayerIndex == -1) return 0;
    int totalPlayers = completedPlayers.length;
    double positionFactor = 1.0 - (currentPlayerIndex / (totalPlayers - 1));
    return (positionFactor * 100).round();
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

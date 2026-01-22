// multiplayer_game_controller.dart - UPDATED VERSION
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';
import 'game_controller.dart'; // Import GameController for shared logic

class MultiplayerGameController extends ChangeNotifier {
  final RoomService _roomService = RoomService();
  final String roomCode;
  final String playerId;

  Room? _room;
  StreamSubscription? _roomSubscription;
  Timer? _timerCountdown;
  Duration timeLeft = const Duration(minutes: 5);

  // Local gameplay - dynamic size
  int gridSize = 4;
  List<List<double?>> grid = []; // CHANGED: int? -> double?
  List<List<bool>> isWrong = [];
  List<List<bool>> isHinted = []; // Track which cells were revealed by hints
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

  MultiplayerGameController({
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

        // Start timer when game_screen starts
        if (room.gameState.status == 'playing' && !isPlaying) {
          _startGame();
        }

        // End game_screen when status changes
        if (room.gameState.status == 'ended' && isPlaying) {
          _endGame();
        }

        // Check if all players completed whenever room updates
        if (isPlaying && room.gameState.status == 'playing') {
          final allDone = room.players.values.every((p) => p.isCompleted);
          if (allDone) {
            debugPrint("🔥 Room update detected: All players completed!");
            // Small delay to prevent race conditions
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

      debugPrint("🔍 Puzzle dimensions check:");
      debugPrint("   Grid: ${puzzle.grid.length} rows");
      for (int i = 0; i < puzzle.grid.length; i++) {
        debugPrint("   Row $i: ${puzzle.grid[i].length} cells");
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
          try {
            if (i == 0 && j == 0) {
              grid[0][0] = -1;
              debugPrint("Set reference cell [0][0] = -1");
              continue;
            }

            // Check bounds before accessing puzzle data
            if (i >= puzzle.grid.length) {
              debugPrint("Row $i out of bounds in puzzle.grid");
              continue;
            }

            if (j >= puzzle.grid[i].length) {
              debugPrint("Col $j out of bounds in puzzle.grid[$i]");
              // Try to fill from solution if available
              if (i < puzzle.solution.length &&
                  j < puzzle.solution[i].length &&
                  i < puzzle.isFixed.length &&
                  j < puzzle.isFixed[i].length) {
                if (puzzle.isFixed[i][j]) {
                  grid[i][j] = puzzle.solution[i][j];
                  debugPrint("Filled [$i][$j] from solution: ${grid[i][j]}");
                } else {
                  grid[i][j] = null;
                }
              }
              continue;
            }

            if (i >= puzzle.isFixed.length || j >= puzzle.isFixed[i].length) {
              debugPrint("Index [$i][$j] out of bounds in isFixed");
              continue;
            }

            // Copy data based on isFixed flag
            if (puzzle.isFixed[i][j]) {
              grid[i][j] = puzzle.grid[i][j];

              // If grid value is null/invalid, try solution
              if (grid[i][j] == null || grid[i][j] == -1) {
                if (i < puzzle.solution.length &&
                    j < puzzle.solution[i].length) {
                  grid[i][j] = puzzle.solution[i][j];
                  debugPrint(
                      "Fixed cell [$i][$j] was null, used solution: ${grid[i][j]}");
                } else {
                  debugPrint("Fixed cell [$i][$j] has no valid value!");
                }
              }
            } else {
              grid[i][j] = null;
            }
          } catch (e) {
            debugPrint("❌ Error at [$i][$j]: $e");
            grid[i][j] = null;
          }
        }
      }

      debugPrint(
          "✅ Local grid initialized successfully ($gridSize x $gridSize)");
      return true;
    } catch (e, stackTrace) {
      debugPrint("❌ Error initializing grid: $e");
      debugPrint("Stack trace: $stackTrace");
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

    // Calculate completion time even if timed out
    if (_gameStartTime != null) {
      _completionTimeSeconds =
          DateTime.now().difference(_gameStartTime!).inSeconds;
      debugPrint(
          "⏰ Time's up! Completion time: $_completionTimeSeconds seconds");
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
      debugPrint("🏁 Game ended. Total time: $_completionTimeSeconds seconds");
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
    // CHANGED: int? -> double?
    if (!isPlaying || isSubmitted) return;

    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) {
      debugPrint("⚠️ Invalid cell coordinates: ($row, $col)");
      return;
    }

    if (row == 0 && col == 0) return;
    if (_room?.puzzle?.isFixed[row][col] == true) return;

    // Don't allow editing hinted cells
    if (isHinted[row][col]) {
      debugPrint("⚠️ Cannot edit a hinted cell");
      return;
    }

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
    double tolerance = 0.01; // ADDED: Tolerance for double comparison

    // Count player cells (excluding fixed and reference cell)
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;

        bool cellIsFixed = false;
        if (i < puzzle.isFixed.length && j < puzzle.isFixed[i].length) {
          cellIsFixed = puzzle.isFixed[i][j];
        }

        if (!cellIsFixed) {
          totalPlayerCells++;
        }
      }
    }

    _totalPlayerCells = totalPlayerCells;

    // Reset wrong flags
    for (var i = 0; i < gridSize; i++) {
      for (var j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    // Check each player cell
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;

        bool cellIsFixed = false;
        if (i < puzzle.isFixed.length && j < puzzle.isFixed[i].length) {
          cellIsFixed = puzzle.isFixed[i][j];
        }
        if (cellIsFixed) continue;

        final current = grid[i][j];
        double? correct; // CHANGED: int? -> double?

        if (i < puzzle.solution.length && j < puzzle.solution[i].length) {
          correct = puzzle.solution[i][j];
        }

        if (current != null) filledCount++;

        // CHANGED: Use tolerance for double comparison
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

    // Store metrics
    _correctAnswers = correctCount;

    // Calculate accuracy percentage
    if (_totalPlayerCells > 0) {
      _accuracyPercentage = (correctCount / _totalPlayerCells) * 100;
    } else {
      _accuracyPercentage = 0.0;
    }

    // Calculate progress score
    int progressScore = totalPlayerCells > 0
        ? (correctCount / totalPlayerCells * 100).round()
        : 0;

    if (!progressOnly) {
      // Full validation on submission
      debugPrint("🎯 Submitting with score calculation...");
      debugPrint("   Correct: $correctCount/$totalPlayerCells");
      debugPrint("   Filled: $filledCount/$totalPlayerCells");
      debugPrint("   Accuracy: ${_accuracyPercentage.toStringAsFixed(1)}%");

      localScore = _calculateFinalScore(correctCount, totalPlayerCells);

      // Calculate completion time
      if (_gameStartTime != null) {
        _completionTimeSeconds =
            DateTime.now().difference(_gameStartTime!).inSeconds;
        debugPrint("   Completion Time: $_completionTimeSeconds seconds");
      }

      _roomService.updateScore(roomCode, playerId, localScore);
      _markSubmitted();

      if (_room?.settings.mode == 'untimed') {
        _checkIfAllCompleted();
      }
    } else {
      // Progressive score update
      localScore = (progressScore - hintPenalty).clamp(0, 100);
      _roomService.updateScore(roomCode, playerId, localScore);
    }

    notifyListeners();
  }

  // Scoring system - 70% accuracy + 30% time bonus
  int _calculateFinalScore(int correctCount, int totalPlayerCells) {
    if (_room?.settings.mode == 'untimed') {
      // Untimed: 100% accuracy based
      int accuracyScore = totalPlayerCells > 0
          ? (correctCount / totalPlayerCells * 100).round()
          : 0;
      return (accuracyScore - hintPenalty).clamp(0, 100);
    }

    // Timed mode: 70% accuracy + 30% time bonus
    int accuracyScore = totalPlayerCells > 0
        ? (correctCount / totalPlayerCells * 100).round()
        : 0;

    int timeBonus = _calculateTimeBonus();

    debugPrint("📊 Score Breakdown:");
    debugPrint("   Accuracy: $accuracyScore (70%)");
    debugPrint("   Time Bonus: $timeBonus (30%)");
    debugPrint("   Hint Penalty: $hintPenalty");

    int finalScore = ((accuracyScore * 0.7) + (timeBonus * 0.3)).round();
    return (finalScore - hintPenalty).clamp(0, 100);
  }

  int _calculateTimeBonus() {
    if (_room?.settings.mode != 'timed') return 0;

    // Get all players who have completed the game_screen
    final completedPlayers = _room!.players.values
        .where((player) => player.isCompleted && player.completedAt != null)
        .toList();

    // If no one else has completed, this player gets max time bonus
    if (completedPlayers.isEmpty || completedPlayers.length == 1) {
      return 100;
    }

    // Sort by completion time (earliest first)
    completedPlayers.sort((a, b) => a.completedAt!.compareTo(b.completedAt!));

    // Find current player's position
    int currentPlayerIndex =
        completedPlayers.indexWhere((player) => player.id == playerId);

    if (currentPlayerIndex == -1) {
      return 0;
    }

    // Calculate time bonus based on position
    // First place gets 100% of time bonus, last gets 0%
    int totalPlayers = completedPlayers.length;
    double positionFactor = 1.0 - (currentPlayerIndex / (totalPlayers - 1));

    // Maximum time bonus is 100 (which becomes 30% of final score)
    int timeBonus = (positionFactor * 100).round();

    debugPrint("⏱️ Time Bonus Calculation:");
    debugPrint("   Position: ${currentPlayerIndex + 1}/$totalPlayers");
    debugPrint("   Position Factor: ${positionFactor.toStringAsFixed(2)}");
    debugPrint("   Time Bonus: $timeBonus/100");

    return timeBonus;
  }

  Future<void> _checkIfAllCompleted() async {
    if (_room == null) return;

    // Check if all players have submitted
    final allDone = _room!.players.values.every((p) => p.isCompleted);
    debugPrint("🔍 Checking if all completed: $allDone");
    debugPrint("   Players: ${_room!.players.length}");

    for (var player in _room!.players.values) {
      debugPrint(
          "   ${player.name}: completed=${player.isCompleted}, completedAt=${player.completedAt}");
    }

    if (allDone) {
      debugPrint("✅ All players completed, ending game_screen");
      await _roomService.endGame(roomCode);
    }
  }

  Future<void> submitGame() async {
    if (isSubmitted || !isPlaying) {
      debugPrint("⚠️ Cannot submit: already submitted or not playing");
      return;
    }

    debugPrint("🎯 Submitting game_screen...");

    // Stop timer if timed mode
    if (_room?.settings.mode == 'timed') {
      _timerCountdown?.cancel();
      debugPrint("⏱️ Timer stopped");
    }

    _validateGrid(progressOnly: false);

    // Double-check after a short delay in case validation was async
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_room != null && isSubmitted) {
        _checkIfAllCompleted();
      }
    });
  }

  void _markSubmitted() {
    isSubmitted = true;
    _roomService.markCompleted(roomCode, playerId, localScore);
    debugPrint("✅ Game submitted and marked as completed");
    debugPrint("   Final Score: $localScore");
    debugPrint("   Accuracy: ${_accuracyPercentage.toStringAsFixed(1)}%");
    debugPrint("   Correct Answers: $_correctAnswers/$_totalPlayerCells");

    // Wait a bit for Firebase to update, then check if all completed
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkIfAllCompleted();
    });
  }

  // --------------------------------------------------
  // Hints
  // --------------------------------------------------
  Future<bool> useHint(int row, int col) async {
    if (!isPlaying || _room?.puzzle == null || isSubmitted) {
      debugPrint("⚠️ Cannot use hint: game_screen not active");
      return false;
    }

    if (currentPlayer == null ||
        currentPlayer!.hintsUsed >= (_room!.settings.maxHints)) {
      debugPrint("⚠️ No hints remaining");
      return false;
    }

    if (row == 0 && col == 0) return false;

    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) {
      debugPrint("⚠️ Invalid hint coordinates");
      return false;
    }

    // Don't allow hints on fixed cells
    if (_room!.puzzle!.isFixed[row][col]) {
      debugPrint("⚠️ Cannot use hint on fixed cell");
      return false;
    }

    double? correctValue; // CHANGED: int? -> double?
    if (row < _room!.puzzle!.solution.length &&
        col < _room!.puzzle!.solution[row].length) {
      correctValue = _room!.puzzle!.solution[row][col];
    }

    if (correctValue == null) {
      debugPrint("⚠️ No solution value for cell [$row][$col]");
      return false;
    }

    grid[row][col] = correctValue;
    isHinted[row][col] = true;
    await _roomService.incrementHintUsage(roomCode, playerId);
    hintPenalty += 5;
    _validateGrid(progressOnly: true);

    debugPrint("💡 Hint used at ($row, $col) = $correctValue");
    debugPrint("   Hints remaining: $hintsRemaining");
    debugPrint("   Total penalty: $hintPenalty points");

    return true;
  }

  // --------------------------------------------------
  // Leaderboard
  // --------------------------------------------------
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

  // Check if all players have submitted
  bool get allPlayersSubmitted {
    if (_room == null) return false;
    return _room!.players.values.every((p) => p.isCompleted);
  }

  // --------------------------------------------------
  // Reset and cleanup methods
  // --------------------------------------------------
  void resetMetrics() {
    _gameStartTime = null;
    _completionTimeSeconds = null;
    _correctAnswers = 0;
    _totalPlayerCells = 0;
    _accuracyPercentage = 0.0;
    hintPenalty = 0;
    debugPrint("🔄 Metrics reset");
  }

  Future<void> leaveRoom() async {
    await _roomService.removePlayer(roomCode, playerId);
    _roomSubscription?.cancel();
    _timerCountdown?.cancel();
    isPlaying = false;
    resetMetrics();
    debugPrint("👋 Left room and cleaned up");
    notifyListeners();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _timerCountdown?.cancel();
    super.dispose();
  }
}

// multiplayer_puzzle_generator.dart
// Use this to generate puzzles for multiplayer games
class MultiplayerPuzzleGenerator {
  /// Generates a puzzle using the shared logic from GameController
  static PuzzleData generatePuzzle({
    required int gridSize,
    required PuzzleOperation operation,
    bool useDecimals = false, // ADDED: Support for decimals
    bool hardMode = false,
  }) {
    debugPrint(
        "Generating Multiplayer puzzle using GameController shared logic");

    // Use default settings for multiplayer:
    // hardMode = false (unless room has setting, but currently not passed)

    final result = GameController.generateBoardData(
        gridSize: gridSize,
        useDecimals: useDecimals,
        hardMode: hardMode,
        operation: operation);

    final List<List<double?>> fullGrid = result['grid'];
    final List<List<double?>> solutionGrid = result['solutionGrid'];
    final List<List<bool>> isFixed = result['isFixed'];

    // Create player-visible grid (only fixed cells)
    // GameController.generateBoardData returns 'grid' which IS the player visible grid (contains seeds)
    // but 'solutionGrid' is the full solution.
    // Let's ensure we return what PuzzleData expects.

    // Note: GameController's 'grid' property already represents the player's starting state
    // (seeds filled, others null).

    return PuzzleData(
      grid: fullGrid,
      solution: solutionGrid,
      isFixed: isFixed,
    );
  }
}

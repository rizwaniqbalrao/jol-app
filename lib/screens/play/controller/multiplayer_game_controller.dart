// multiplayer_game_controller.dart - FIXED VERSION
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';

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
  List<List<int?>> grid = [];
  List<List<bool>> isWrong = [];
  int localScore = 0;
  int hintPenalty = 0;
  bool isSubmitted = false;
  bool isPlaying = false;

  MultiplayerGameController({
    required this.roomCode,
    required this.playerId,
  }) {
    _listenToRoom();
  }

  Room? get room => _room;
  Player? get currentPlayer => _room?.players[playerId];
  bool get isHost => _room?.gameState.hostId == playerId;
  bool get canStart => isHost && (_room?.canStart ?? false);

  int get hintsRemaining =>
      (_room?.settings.maxHints ?? 2) - (currentPlayer?.hintsUsed ?? 0);

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

        // NEW: Check if all players completed whenever room updates
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
                if (i < puzzle.solution.length && j < puzzle.solution[i].length) {
                  grid[i][j] = puzzle.solution[i][j];
                  debugPrint("Fixed cell [$i][$j] was null, used solution: ${grid[i][j]}");
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

      debugPrint("✅ Local grid initialized successfully ($gridSize x $gridSize)");
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
    if (_room?.settings.mode == 'timed') {
      timeLeft = Duration(seconds: _room?.settings.timeLimit ?? 300);
      _startTimer();
    }
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
    if (isHost) _roomService.endGame(roomCode);
    notifyListeners();
  }

  void _endGame() {
    isPlaying = false;
    _timerCountdown?.cancel();
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
  void updateCell(int row, int col, int? value) {
    if (!isPlaying || isSubmitted) return;

    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) {
      debugPrint("⚠️ Invalid cell coordinates: ($row, $col)");
      return;
    }

    if (row == 0 && col == 0) return;
    if (_room?.puzzle?.isFixed[row][col] == true) return;

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
        int? correct;

        if (i < puzzle.solution.length && j < puzzle.solution[i].length) {
          correct = puzzle.solution[i][j];
        }

        if (current != null) filledCount++;
        if (current == correct && correct != null) correctCount++;
        if (current != null && correct != null && current != correct) {
          isWrong[i][j] = true;
        }
      }
    }

    // Calculate progress score
    int progressScore = totalPlayerCells > 0
        ? (correctCount / totalPlayerCells * 100).round()
        : 0;

    if (!progressOnly) {
      // Full validation on submission - ALWAYS SUBMIT
      debugPrint("🎯 Submitting with score calculation...");
      debugPrint("   Correct: $correctCount/$totalPlayerCells");
      debugPrint("   Filled: $filledCount/$totalPlayerCells");

      // NEW SCORING SYSTEM: 70% accuracy + 30% time bonus
      localScore = _calculateFinalScore(correctCount, totalPlayerCells);

      _roomService.updateScore(roomCode, playerId, localScore);
      _markSubmitted();

      // Check if all players completed in untimed mode
      if (_room?.settings.mode == 'untimed') {
        _checkIfAllCompleted();
      }
    } else {
      // Progressive score update - just accuracy based
      localScore = (progressScore - hintPenalty).clamp(0, 100);
      _roomService.updateScore(roomCode, playerId, localScore);
    }

    notifyListeners();
  }

  // NEW SCORING SYSTEM - 70% accuracy + 30% time bonus
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

    // Get all players who have completed the game
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
    int currentPlayerIndex = completedPlayers.indexWhere(
            (player) => player.id == playerId
    );

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
      debugPrint("   ${player.name}: completed=${player.isCompleted}, completedAt=${player.completedAt}");
    }

    if (allDone) {
      debugPrint("✅ All players completed, ending game");
      await _roomService.endGame(roomCode);
    }
  }

  Future<void> submitGame() async {
    if (isSubmitted || !isPlaying) {
      debugPrint("⚠️ Cannot submit: already submitted or not playing");
      return;
    }

    debugPrint("🎯 Submitting game...");

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
      debugPrint("⚠️ Cannot use hint: game not active");
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

    int? correctValue;
    if (row < _room!.puzzle!.solution.length &&
        col < _room!.puzzle!.solution[row].length) {
      correctValue = _room!.puzzle!.solution[row][col];
    }

    if (correctValue == null) {
      debugPrint("⚠️ No solution value for cell [$row][$col]");
      return false;
    }

    grid[row][col] = correctValue;
    await _roomService.incrementHintUsage(roomCode, playerId);
    hintPenalty += 5;
    _validateGrid(progressOnly: true);

    debugPrint("💡 Hint used at ($row, $col) = $correctValue");
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
  // Leave room
  // --------------------------------------------------
  Future<void> leaveRoom() async {
    await _roomService.removePlayer(roomCode, playerId);
    _roomSubscription?.cancel();
    _timerCountdown?.cancel();
    isPlaying = false;
    notifyListeners();
  }

  // --------------------------------------------------
  // Cleanup
  // --------------------------------------------------
  @override
  void dispose() {
    _roomSubscription?.cancel();
    _timerCountdown?.cancel();
    super.dispose();
  }
}
// multiplayer_puzzle_generator.dart
// Use this to generate puzzles for multiplayer games
enum PuzzleOperation { addition, subtraction }

class MultiplayerPuzzleGenerator {
  /// Generates a puzzle using the same logic as single-player GameController
  /// Now with two-digit numbers (1-25) for seed numbers
  static PuzzleData generatePuzzle({
    required int gridSize,
    required PuzzleOperation operation,
  }) {
    debugPrint("Generating ${gridSize}x$gridSize puzzle (${operation.name}) with numbers 1-25");

    final random = Random();

    // Initialize structures
    List<List<int?>> solutionGrid = List.generate(
        gridSize,
            (_) => List.filled(gridSize, null)
    );
    List<List<bool>> isFixed = List.generate(
        gridSize,
            (_) => List.filled(gridSize, false)
    );

    // Reference cell [0][0] - always -1 and fixed
    solutionGrid[0][0] = -1;
    isFixed[0][0] = true;

    int seedNumbers = 0;

    // Generate puzzle
    bool success = _createBoard(
      solutionGrid,
      isFixed,
      gridSize,
      operation,
      random,
      seedNumbers,
    );

    if (!success) {
      debugPrint("Puzzle generation failed, retrying...");
      return generatePuzzle(gridSize: gridSize, operation: operation);
    }

    // Create player-visible grid (only fixed cells)
    List<List<int?>> playerGrid = List.generate(
      gridSize,
          (i) => List.generate(
        gridSize,
            (j) => isFixed[i][j] ? solutionGrid[i][j] : null,
      ),
    );

    debugPrint("Puzzle generated successfully with two-digit numbers");
    _debugPrintPuzzle(playerGrid, solutionGrid, isFixed, gridSize);

    return PuzzleData(
      grid: playerGrid,
      solution: solutionGrid,
      isFixed: isFixed,
    );
  }

  static bool _createBoard(
      List<List<int?>> solutionGrid,
      List<List<bool>> isFixed,
      int gridSize,
      PuzzleOperation operation,
      Random random,
      int seedNumbers,
      ) {
    try {
      List<int> availableRows = List.generate(gridSize, (i) => i);
      List<int> availableCols = List.generate(gridSize, (i) => i);

      // PHASE 1: Place first 4 seed numbers (now with numbers 1-25)
      for (int i = 0; i < 4; i++) {
        int randomRow, randomCol;

        do {
          if (seedNumbers == 0) {
            // First seed: row 0, random column (not column 0)
            randomRow = 0;
            randomCol = availableCols[random.nextInt(availableCols.length - 1) + 1];
          } else {
            // Next seeds: random positions
            randomRow = availableRows[random.nextInt(availableRows.length)];
            randomCol = availableCols[random.nextInt(availableCols.length)];
          }
        } while (randomRow == 0 && randomCol == 0); // Avoid top-left

        solutionGrid[randomRow][randomCol] =
            _randomNumberNotInRowCol(solutionGrid, randomRow, randomCol, gridSize, random);
        isFixed[randomRow][randomCol] = true;

        seedNumbers++;
        availableRows.remove(randomRow);
        availableCols.remove(randomCol);
      }

      // PHASE 2: Solve to fill deducible values
      if (operation == PuzzleOperation.addition) {
        _solvingBoard1Addition(solutionGrid, gridSize);
      } else {
        _solvingBoard1Subtraction(solutionGrid, gridSize);
      }

      // PHASE 3: Add 2 more seeds (total 6) - now with numbers 1-25
      _addAdditionalSeeds(solutionGrid, isFixed, gridSize, operation, random, seedNumbers);

      // PHASE 4: Final solve
      for (int n = 0; n < 20; n++) {
        if (operation == PuzzleOperation.addition) {
          _solvingBoardAddition(solutionGrid, gridSize);
        } else {
          _solvingBoardSubtraction(solutionGrid, gridSize);
        }
      }

      // Check if fully solved
      return !_checkBoardSolvable(solutionGrid, gridSize);

    } catch (e) {
      debugPrint("Error in board creation: $e");
      return false;
    }
  }

  /// UPDATED: Now generates numbers 1-25 (same as GameController)
  static int _randomNumberNotInRowCol(
      List<List<int?>> grid,
      int row,
      int col,
      int gridSize,
      Random random
      ) {
    int number;
    int attempts = 0;
    int maxAttempts = 50; // Prevent infinite loops

    do {
      // CHANGED: Generate numbers from 1 to 25 (single and double digits)
      number = random.nextInt(25) + 1;
      attempts++;

      if (attempts >= maxAttempts) {
        // Fallback: use a number that might not be unique but avoids infinite loop
        debugPrint("Warning: Could not find unique number after $maxAttempts attempts");
        break;
      }
    } while (_isNumberUsedInRowOrColumn(grid, number, row, col, gridSize));

    return number;
  }

  static bool _isNumberUsedInRowOrColumn(
      List<List<int?>> grid,
      int number,
      int row,
      int col,
      int gridSize
      ) {
    for (int i = 0; i < gridSize; i++) {
      if (grid[row][i] == number || grid[i][col] == number) {
        return true;
      }
    }
    return false;
  }

  static void _solvingBoard1Addition(List<List<int?>> grid, int size) {
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (i == 0 && j == 0) continue;

        if (i == 0 && j >= 1) {
          // Top row: B = sum of pairs in column
          if (grid[i][j] == null) {
            for (int n = 1; n < size; n++) {
              if (grid[n][i] != null && grid[n][j] != null) {
                grid[i][j] = grid[n][i]! + grid[n][j]!;
                break;
              }
            }
          }
        } else if (i >= 1 && j == 0) {
          // Left column: A = sum of pairs in row
          if (grid[i][j] == null) {
            for (int n = 1; n < size; n++) {
              if (grid[j][n] != null && grid[i][n] != null) {
                grid[i][j] = grid[j][n]! + grid[i][n]!;
                break;
              }
            }
          }
        } else {
          // Intersection: C = A + B
          if (grid[i][j] == null && grid[i][0] != null && grid[0][j] != null) {
            grid[i][j] = grid[i][0]! + grid[0][j]!;
          }
        }
      }
    }
  }

  static void _solvingBoardAddition(List<List<int?>> grid, int size) {
    _solvingBoard1Addition(grid, size);
  }

  static void _solvingBoard1Subtraction(List<List<int?>> grid, int size) {
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (i == 0 && j == 0) continue;

        if (i == 0 && j >= 1) {
          // Top row: B = |difference| of pairs
          if (grid[i][j] == null) {
            for (int n = 1; n < size; n++) {
              if (grid[n][i] != null && grid[n][j] != null) {
                grid[i][j] = (grid[n][i]! - grid[n][j]!).abs();
                break;
              }
            }
          }
        } else if (i >= 1 && j == 0) {
          // Left column: A = |difference|
          if (grid[i][j] == null) {
            for (int n = 1; n < size; n++) {
              if (grid[j][n] != null && grid[i][n] != null) {
                grid[i][j] = (grid[j][n]! - grid[i][n]!).abs();
                break;
              }
            }
          }
        } else {
          // Intersection: C = |A - B|
          if (grid[i][j] == null && grid[i][0] != null && grid[0][j] != null) {
            grid[i][j] = (grid[i][0]! - grid[0][j]!).abs();
          }
        }
      }
    }
  }

  static void _solvingBoardSubtraction(List<List<int?>> grid, int size) {
    _solvingBoard1Subtraction(grid, size);
  }

  /// UPDATED: Additional seeds now also use numbers 1-25
  static void _addAdditionalSeeds(
      List<List<int?>> grid,
      List<List<bool>> isFixed,
      int gridSize,
      PuzzleOperation operation,
      Random random,
      int seedNumbers,
      ) {
    List<int> availableRows = List.generate(gridSize, (i) => i);
    List<int> availableCols = List.generate(gridSize, (i) => i);

    int targetSeeds = 6;
    int attempts = 0;
    int maxAttempts = 100;

    while (seedNumbers < targetSeeds && attempts < maxAttempts) {
      attempts++;

      if (availableRows.isEmpty || availableCols.isEmpty) break;

      int randomRow = availableRows[random.nextInt(availableRows.length)];
      int randomCol = availableCols[random.nextInt(availableCols.length)];

      if (randomRow == 0 && randomCol == 0) continue;
      if (grid[randomRow][randomCol] != null) continue;

      // CHANGED: Use numbers 1-25 for additional seeds too
      grid[randomRow][randomCol] = random.nextInt(25) + 1;
      isFixed[randomRow][randomCol] = true;
      seedNumbers++;

      // Solve multiple times to propagate the new seed
      for (int n = 0; n < 20; n++) {
        if (operation == PuzzleOperation.addition) {
          _solvingBoardAddition(grid, gridSize);
        } else {
          _solvingBoardSubtraction(grid, gridSize);
        }
      }

      availableRows.remove(randomRow);
      availableCols.remove(randomCol);
    }

    if (seedNumbers < targetSeeds) {
      debugPrint("Warning: Only placed $seedNumbers seeds (target: $targetSeeds)");
    }
  }

  static bool _checkBoardSolvable(List<List<int?>> grid, int size) {
    int zeroCount = 0;
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (i == 0 && j == 0) continue;
        if (grid[i][j] == null) zeroCount++;
      }
    }
    return zeroCount > 0;
  }

  static void _debugPrintPuzzle(
      List<List<int?>> playerGrid,
      List<List<int?>> solution,
      List<List<bool>> isFixed,
      int size,
      ) {
    debugPrint("\nPuzzle Structure (Numbers 1-25):");
    debugPrint("Player Grid (fixed cells only):");
    for (int i = 0; i < size; i++) {
      String row = playerGrid[i].map((v) => v?.toString().padLeft(3) ?? '  -').join(' ');
      debugPrint("  $row");
    }

    debugPrint("\nFull Solution:");
    for (int i = 0; i < size; i++) {
      String row = solution[i].map((v) => v?.toString().padLeft(3) ?? '  -').join(' ');
      debugPrint("  $row");
    }

    int fixedCount = 0;
    for (var row in isFixed) {
      fixedCount += row.where((f) => f).length;
    }

    // Count two-digit numbers in fixed cells
    int twoDigitCount = 0;
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (isFixed[i][j] && solution[i][j] != null && solution[i][j]! > 9) {
          twoDigitCount++;
        }
      }
    }

    debugPrint("\nFixed cells: $fixedCount (with $twoDigitCount two-digit numbers)");
    debugPrint("Player cells: ${size * size - fixedCount}");
  }
}
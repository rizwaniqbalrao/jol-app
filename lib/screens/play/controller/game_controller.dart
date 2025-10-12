import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

enum GameMode { untimed, timed }

class GameController extends ChangeNotifier {
  int gridSize;
  GameMode _mode = GameMode.untimed; // private field
  late List<List<int?>> grid; // visible cells (null = empty)
  late List<List<int?>> _solutionGrid; // full solution
  late List<List<bool>> isFixed; // prefilled clues
  late List<List<int>> _relationshipRules; // 0=A+B=C, 1=B+C=A, 2=A+C=B
  late List<List<bool>> isWrong; // tracks incorrect cells for highlighting
  int score = 0;
  Duration timeLeft = const Duration(minutes: 5);
  Timer? _timer;
  bool isPlaying = false;

  GameController({this.gridSize = 4}) {
    _initGrid();
    if (mode == GameMode.timed) {
      startTimer();
    }
  }

  // ──────────────────────────────────────────────
  // INITIALIZATION
  // ──────────────────────────────────────────────
  void _initGrid() {
    final random = Random();
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    _relationshipRules = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    isWrong = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // Top-left cell fixed
    grid[0][0] = -1;
    _solutionGrid[0][0] = -1;
    isFixed[0][0] = true;
    _relationshipRules[0][0] = -1;

    _generateSolvablePuzzle(random);
    isPlaying = true;
    notifyListeners();
  }

  void _generateSolvablePuzzle(Random random) {
    const int maxAttempts = 100;
    bool success = false;
    for (int attempt = 0; attempt < maxAttempts && !success; attempt++) {
      for (int i = 1; i < gridSize; i++) {
        _solutionGrid[i][0] = random.nextInt(25) + 1;
      }
      for (int j = 1; j < gridSize; j++) {
        _solutionGrid[0][j] = random.nextInt(25) + 1;
      }

      for (int i = 1; i < gridSize; i++) {
        for (int j = 1; j < gridSize; j++) {
          int a = _solutionGrid[i][0]!;
          int b = _solutionGrid[0][j]!;
          List<int> validRules = [0];
          if (a > b) validRules.add(1);
          if (b > a) validRules.add(2);

          int rule;
          if (validRules.length > 1 && random.nextDouble() > 0.4) {
            rule = validRules[1 + random.nextInt(validRules.length - 1)];
          } else {
            rule = 0;
          }
          _relationshipRules[i][j] = rule;

          int c;
          switch (rule) {
            case 0:
              c = a + b;
              break;
            case 1:
              c = a - b;
              break;
            case 2:
              c = b - a;
              break;
            default:
              c = a + b;
          }
          _solutionGrid[i][j] = c;
        }
      }

      if (_selectOperandClues(random)) {
        success = true;
      }
    }
    if (!success) _useFallbackClues(random);
  }

  bool _selectOperandClues(Random random) {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (!(i == 0 && j == 0)) {
          grid[i][j] = null;
          isFixed[i][j] = false;
        }
      }
    }

    final operandCandidates = <List<int>>[];
    for (int i = 1; i < gridSize; i++) {
      if (_solutionGrid[i][0]! < 10) operandCandidates.add([i, 0]);
    }
    for (int j = 1; j < gridSize; j++) {
      if (_solutionGrid[0][j]! < 10) operandCandidates.add([0, j]);
    }

    for (int i = 1; i < gridSize; i++) {
      for (int j = 1; j < gridSize; j++) {
        final rule = _relationshipRules[i][j];
        if ((rule == 1 || rule == 2) && _solutionGrid[i][j]! < 10) {
          operandCandidates.add([i, j]);
        }
      }
    }

    if (operandCandidates.length < 6) return false;

    final partialTriplets = _selectTwoDisjointPartialTriplets(operandCandidates, random);
    if (partialTriplets.length != 2) return false;

    final hintOperands = <List<int>>[];
    for (final triplet in partialTriplets) {
      hintOperands.addAll(triplet.sublist(0, 2));
    }

    final remainingCandidates = operandCandidates
        .where((pos) => !hintOperands.any((h) => h[0] == pos[0] && h[1] == pos[1]))
        .toList();
    if (remainingCandidates.length < 2) return false;

    remainingCandidates.shuffle(random);
    final additionalClues = remainingCandidates.take(2).toList();
    final selectedClues = [...hintOperands, ...additionalClues];

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        grid[i][j] = null;
        isFixed[i][j] = false;
      }
    }
    for (final pos in selectedClues) {
      grid[pos[0]][pos[1]] = _solutionGrid[pos[0]][pos[1]];
      isFixed[pos[0]][pos[1]] = true;
    }

    return _isPuzzleSolvable();
  }

  List<List<List<int>>> _selectTwoDisjointPartialTriplets(
      List<List<int>> operandCandidates, Random random) {
    final possiblePartials = <List<List<int>>>[];
    for (int i = 1; i < gridSize; i++) {
      for (int j = 1; j < gridSize; j++) {
        final rule = _relationshipRules[i][j];
        final aPos = [i, 0];
        final bPos = [0, j];
        final cPos = [i, j];

        final aIsCandidate = operandCandidates.any((p) => p[0] == i && p[1] == 0);
        final bIsCandidate = operandCandidates.any((p) => p[0] == 0 && p[1] == j);
        final cIsOperand = (rule == 1 || rule == 2);
        final cIsCandidate = cIsOperand &&
            operandCandidates.any((p) => p[0] == i && p[1] == j);

        if (rule == 0 && aIsCandidate && bIsCandidate) {
          possiblePartials.add([aPos, bPos, cPos]);
        } else if (rule == 1 && bIsCandidate && cIsCandidate) {
          possiblePartials.add([bPos, cPos, aPos]);
        } else if (rule == 2 && aIsCandidate && cIsCandidate) {
          possiblePartials.add([aPos, cPos, bPos]);
        }
      }
    }

    if (possiblePartials.length < 2) return [];
    possiblePartials.shuffle(random);

    for (int i = 0; i < possiblePartials.length - 1; i++) {
      for (int j = i + 1; j < possiblePartials.length; j++) {
        final t1 = possiblePartials[i];
        final t2 = possiblePartials[j];
        final shared = t1.sublist(0, 2).any(
                (p1) => t2.sublist(0, 2).any((p2) => p1[0] == p2[0] && p1[1] == p2[1]));
        if (!shared) return [t1, t2];
      }
    }
    return [];
  }

  void _useFallbackClues(Random random) {
    final clues = <List<int>>[];
    for (int i = 1; i < gridSize; i++) {
      if (_solutionGrid[i][0]! < 10) clues.add([i, 0]);
    }
    for (int j = 1; j < gridSize; j++) {
      if (_solutionGrid[0][j]! < 10 && clues.length < 6) clues.add([0, j]);
    }

    for (final pos in clues) {
      grid[pos[0]][pos[1]] = _solutionGrid[pos[0]][pos[1]];
      isFixed[pos[0]][pos[1]] = true;
    }
  }

  bool _isPuzzleSolvable() {
    final tempGrid =
    List.generate(gridSize, (i) => List<int?>.from(grid[i]));
    bool madeProgress = true;
    int iterations = 0;

    while (madeProgress && iterations < 100) {
      madeProgress = false;
      iterations++;

      for (int i = 1; i < gridSize; i++) {
        for (int j = 1; j < gridSize; j++) {
          if (tempGrid[i][j] != null) continue;
          final a = tempGrid[i][0];
          final b = tempGrid[0][j];
          final rule = _relationshipRules[i][j];

          if (a != null && b != null) {
            int c;
            switch (rule) {
              case 0:
                c = a + b;
                break;
              case 1:
                c = a - b;
                break;
              case 2:
                c = b - a;
                break;
              default:
                c = a + b;
            }
            if (c > 0) {
              tempGrid[i][j] = c;
              madeProgress = true;
            }
          }
        }
      }
    }

    for (int i = 1; i < gridSize; i++) {
      for (int j = 1; j < gridSize; j++) {
        if (tempGrid[i][j] == null) return false;
      }
    }
    return true;
  }

  // ──────────────────────────────────────────────
  // GAME LOGIC
  // ──────────────────────────────────────────────
  void updateCell(int row, int col, int? value) {
    if (isFixed[row][col] || !isPlaying || (row == 0 && col == 0)) return;
    if (value == null || value < 0) return;
    grid[row][col] = value;
    notifyListeners();
    validateGrid();
  }

  void provideHint(int row, int col) {
    if (!isPlaying || isFixed[row][col] || (row == 0 && col == 0)) return;
    grid[row][col] = _solutionGrid[row][col];
    isFixed[row][col] = true;
    score = max(0, score - 5);
    notifyListeners();
    validateGrid();
  }

  bool validateGrid() {
    int correctCount = 0;
    bool isComplete = true;
    int totalCells = (gridSize * gridSize) - 1;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (grid[i][j] == null) {
          isComplete = false;
          continue;
        }
        if (grid[i][j] == _solutionGrid[i][j]) correctCount++;
      }
    }

    score = (correctCount / totalCells * 100).round();

    if (isComplete && correctCount == totalCells) {
      if (mode == GameMode.untimed) {
        score = 100;
      } else {
        int totalSeconds = 300;
        int remaining = timeLeft.inSeconds.clamp(0, totalSeconds);
        score = (remaining / totalSeconds * 100).round().clamp(0, 100);
      }
      isPlaying = false;
      if (mode == GameMode.timed) stopTimer();
    }
    notifyListeners();
    return isComplete && correctCount == totalCells;
  }

  void checkGrid() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (grid[i][j] != null && grid[i][j] != _solutionGrid[i][j]) {
          isWrong[i][j] = true;
        }
      }
    }
    notifyListeners();
  }

  /// ✅ UPDATED: Solving the puzzle now gives **0 score**
  void solvePuzzle() {
    if (!isPlaying) return;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        grid[i][j] = _solutionGrid[i][j];
        isFixed[i][j] = true;
      }
    }

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    // 🚨 Set score to zero because user didn’t solve it
    score = 0;

    isPlaying = false;
    if (mode == GameMode.timed) stopTimer();
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // TIMER
  // ──────────────────────────────────────────────
  void startTimer() {
    if (mode != GameMode.timed) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft.inSeconds > 0 && isPlaying) {
        timeLeft = timeLeft - const Duration(seconds: 1);
        notifyListeners();
      } else {
        stopTimer();
        isPlaying = false;
        notifyListeners();
      }
    });
  }

  void stopTimer() => _timer?.cancel();

  void resetGame() {
    stopTimer();
    score = 0;
    timeLeft = const Duration(minutes: 5);
    _initGrid();
    if (mode == GameMode.timed) startTimer();
  }

  void changeGridSize(int newSize) {
    gridSize = newSize;
    resetGame();
    notifyListeners();
  }

  GameMode get mode => _mode;

  set mode(GameMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    if (isPlaying) {
      if (newMode == GameMode.timed) {
        startTimer();
      } else {
        stopTimer();
      }
    }
    notifyListeners();
  }

  void toggleMode() {
    if (_mode == GameMode.untimed) {
      mode = GameMode.timed;
    } else {
      mode = GameMode.untimed;
    }
  }

  // ──────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────
  String getRuleSymbol(int row, int col) {
    if (row == 0 || col == 0) return '';
    final rule = _relationshipRules[row][col];
    return rule == 0 ? '+' : '−';
  }

  String getRuleDescription(int row, int col) {
    if (row == 0 || col == 0) return '';
    final rule = _relationshipRules[row][col];
    switch (rule) {
      case 0:
        return 'A + B = C';
      case 1:
        return 'B + C = A';
      case 2:
        return 'A + C = B';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}

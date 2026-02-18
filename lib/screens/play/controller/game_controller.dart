import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'base_game_controller_nxn.dart' show PuzzleOperation;

enum GameMode { untimed, timed }

class GameController extends ChangeNotifier {
  final int gridSize;
  GameMode _mode = GameMode.untimed;
  PuzzleOperation operation = PuzzleOperation.addition;
  bool _useDecimals = false;
  bool _hardMode = false;

  late List<List<double?>> grid;
  late List<List<double?>> _solutionGrid;
  late List<List<bool>> isFixed;
  late List<List<bool>> isWrong;
  final Map<String, String> rawInputs = {};

  int score = 0;
  Duration timeLeft =
      const Duration(minutes: 10); // 10 minutes are enough for 4x4 grid
  Timer? _timer;
  bool isPlaying = false;
  bool isGenerating = true;
  int seedNumbers = 0;

  // Game metrics
  DateTime? _gameStartTime;
  int? _completionTimeSeconds;
  int _correctAnswers = 0;
  int _totalPlayerCells = 0;
  double _accuracyPercentage = 0.0;

  // Getters
  List<List<double?>> get solutionGrid => _solutionGrid;
  int get correctAnswers => _correctAnswers;
  int get totalPlayerCells => _totalPlayerCells;
  double get accuracyPercentage => _accuracyPercentage;
  int? get completionTimeSeconds => _completionTimeSeconds;
  DateTime? get gameStartTime => _gameStartTime;
  GameMode get mode => _mode;
  bool get useDecimals => _useDecimals;
  bool get hardMode => _hardMode;

  GameController({this.gridSize = 4}) {
    _initializeGrids();
    _initGrid();
  }

  void _initializeGrids() {
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    isWrong = List.generate(gridSize, (_) => List.filled(gridSize, false));
  }

  // --- SETTINGS MANAGEMENT ---

  set mode(GameMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
  }

  void setOperation(PuzzleOperation newOperation) {
    if (operation == newOperation) return;
    operation = newOperation;
    resetGame();
  }

  void setUseDecimals(bool val) {
    if (_useDecimals == val) return;
    _useDecimals = val;
    resetGame();
  }

  void setHardMode(bool val) {
    if (_hardMode == val) return;
    _hardMode = val;
    resetGame();
  }

  void toggleMode() {
    if (isPlaying) return;
    _mode = (_mode == GameMode.untimed) ? GameMode.timed : GameMode.untimed;
    notifyListeners();
  }

  // --- PUZZLE GENERATION ---

  Future<void> _initGrid() async {
    isGenerating = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 50));
    _clearBoard();

    _createBoard(Random());

    isGenerating = false;
    notifyListeners();
  }

  void _clearBoard() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        grid[i][j] = null;
        _solutionGrid[i][j] = null;
        isFixed[i][j] = false;
        isWrong[i][j] = false;
      }
    }
    grid[0][0] = -1;
    _solutionGrid[0][0] = -1;
    isFixed[0][0] = true;
    rawInputs.clear();
  }

  void _createBoard(Random random, {int maxAttempts = 50}) {
    bool success = false;
    int attempts = 0;

    while (!success && attempts < maxAttempts) {
      attempts++;
      _clearBoard();

      try {
        // 1. Place 4 primary seeds
        List<Point<int>> available = [];
        for (int i = 0; i < gridSize; i++) {
          for (int j = 0; j < gridSize; j++) {
            if (i == 0 && j == 0) continue;
            available.add(Point(i, j));
          }
        }

        // Ensure first seed is in Row 0 or Col 0 for solvability start
        int firstSeedIdx = available.indexWhere((p) => p.x == 0 || p.y == 0);
        if (firstSeedIdx != -1) {
          final p = available.removeAt(firstSeedIdx);
          _placeSeed(p.x, p.y, random);
        }

        for (int i = 0; i < 3; i++) {
          if (available.isEmpty) break;
          final p = available.removeAt(random.nextInt(available.length));
          _placeSeed(p.x, p.y, random);
        }

        // Initial solve
        _solvingBoard1();

        // 2. Add 2 more seeds
        int added = 0;
        int localAttempts = 0;
        while (added < 2 && localAttempts < 100) {
          localAttempts++;
          int r = random.nextInt(gridSize);
          int c = random.nextInt(gridSize);
          if (r == 0 && c == 0) continue;
          if (_solutionGrid[r][c] == null && _checkSeedCondition(r, c)) {
            _placeSeed(r, c, random);
            added++;
            for (int i = 0; i < 10; i++) _solvingBoard();
          }
        }

        // Final ripple
        for (int i = 0; i < 20; i++) _solvingBoard();

        if (_isBoardSolvable()) {
          // Hide non-fixed cells from player grid
          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              if (isFixed[i][j]) {
                grid[i][j] = _solutionGrid[i][j];
              } else {
                grid[i][j] = null;
              }
            }
          }
          success = true;
        }
      } catch (e) {
        // Retry
      }
    }
  }

  void _placeSeed(int r, int c, Random random) {
    double val;
    bool valid = false;
    int attempts = 0;
    while (!valid && attempts < 100) {
      attempts++;
      val = _generateRandomNumber(random);
      if (!_isUsedInRowCol(val, r, c)) {
        _solutionGrid[r][c] = val;
        isFixed[r][c] = true;
        valid = true;
      }
    }
  }

  double _generateRandomNumber(Random random) {
    if (_useDecimals) {
      final int maxVal = _hardMode ? 332 : 99;
      return (random.nextInt(maxVal - 10) + 11) / 10.0;
    } else {
      final int maxVal = _hardMode ? 332 : (gridSize * gridSize);
      return (random.nextInt(maxVal) + 1).toDouble();
    }
  }

  bool _isUsedInRowCol(double val, int r, int c) {
    for (int i = 0; i < gridSize; i++) {
      if (_solutionGrid[r][i] == val) return true;
      if (_solutionGrid[i][c] == val) return true;
    }
    return false;
  }

  void _solvingBoard1() {
    _applySolvingLogic();
  }

  void _solvingBoard() {
    _applySolvingLogic();
  }

  void _applySolvingLogic() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (_solutionGrid[i][j] != null) continue;

        if (operation == PuzzleOperation.addition) {
          if (i > 0 && j > 0) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] =
                  _safeResult(_solutionGrid[i][0]! + _solutionGrid[0][j]!);
            }
          } else if (i == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][j] != null && _solutionGrid[n][0] != null) {
                _solutionGrid[i][j] =
                    _safeResult(_solutionGrid[n][j]! + _solutionGrid[n][0]!);
                break;
              }
            }
          } else if (j == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                _solutionGrid[i][j] =
                    _safeResult(_solutionGrid[i][n]! + _solutionGrid[0][n]!);
                break;
              }
            }
          }
        } else {
          if (i > 0 && j > 0) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] =
                  (_solutionGrid[i][0]! - _solutionGrid[0][j]!).abs();
            }
          } else if (i == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][j] != null && _solutionGrid[n][0] != null) {
                _solutionGrid[i][j] =
                    (_solutionGrid[n][j]! - _solutionGrid[n][0]!).abs();
                break;
              }
            }
          } else if (j == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                _solutionGrid[i][j] =
                    (_solutionGrid[i][n]! - _solutionGrid[0][n]!).abs();
                break;
              }
            }
          }
        }
      }
    }
  }

  double? _safeResult(double val) {
    if (_hardMode && val > 999) return null;
    return (val * 10).round() / 10.0;
  }

  bool _checkSeedCondition(int r, int c) {
    if (r == 0) {
      for (int n = 1; n < gridSize; n++)
        if (_solutionGrid[n][0] == null || _solutionGrid[n][c] == null)
          return true;
    } else if (c == 0) {
      for (int n = 1; n < gridSize; n++)
        if (_solutionGrid[0][n] == null || _solutionGrid[r][n] == null)
          return true;
    } else {
      if (_solutionGrid[r][0] == null || _solutionGrid[0][c] == null)
        return true;
    }
    return false;
  }

  bool _isBoardSolvable() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (_solutionGrid[i][j] == null) return false;
      }
    }
    return true;
  }

  // --- ACTIONS ---

  void startGame() {
    _gameStartTime = DateTime.now();
    isPlaying = true;
    notifyListeners();
  }

  void startTimer() {
    if (_mode != GameMode.timed || _timer != null) return;
    timeLeft = const Duration(minutes: 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft.inSeconds > 0) {
        timeLeft -= const Duration(seconds: 1);
        notifyListeners();
      } else {
        stopTimer();
        endGame();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void resetGame() {
    stopTimer();
    score = 0;
    _initializeGrids();
    _initGrid();
  }

  void updateRawInput(int row, int col, String rawText) {
    if (isFixed[row][col] || !isPlaying) return;
    rawInputs['$row-$col'] = rawText;
    final parsed = double.tryParse(rawText);
    if (parsed != null) grid[row][col] = (parsed * 10).round() / 10.0;
    notifyListeners();
  }

  void finalizeCellInput(int row, int col, String rawText) {
    if (isFixed[row][col] || !isPlaying) return;
    final val = safeParse(rawText);
    if (val != null) grid[row][col] = val;
    notifyListeners();
  }

  double? safeParse(String? text, {int decimalPlaces = 1}) {
    if (text == null || text.trim().isEmpty) return null;
    String clean = text.trim();
    if (clean.endsWith('.')) clean += '0';
    final parsed = double.tryParse(clean);
    if (parsed == null) return null;
    final factor = pow(10, decimalPlaces);
    return (parsed * factor).round() / factor;
  }

  // --- VALIDATION & SCORING ---

  bool validateGrid() {
    int correct = 0;
    int total = 0;
    const tolerance = 0.001;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (isFixed[i][j]) continue;

        total++;
        final val = grid[i][j];
        if (val == null) {
          isWrong[i][j] = true;
          continue;
        }

        bool valid = false;
        if (operation == PuzzleOperation.addition) {
          if (i > 0 && j > 0) {
            final expected = (grid[i][0] ?? 0) + (grid[0][j] ?? 0);
            if ((val - expected).abs() < tolerance) valid = true;
          } else if (i == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (grid[n][j] != null && grid[n][0] != null) {
                if ((val - (grid[n][j]! + grid[n][0]!)).abs() < tolerance) {
                  valid = true;
                  break;
                }
              }
            }
          } else if (j == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (grid[i][n] != null && grid[0][n] != null) {
                if ((val - (grid[i][n]! + grid[0][n]!)).abs() < tolerance) {
                  valid = true;
                  break;
                }
              }
            }
          }
        } else {
          if (i > 0 && j > 0) {
            final expected = ((grid[i][0] ?? 0) - (grid[0][j] ?? 0)).abs();
            if ((val - expected).abs() < tolerance) valid = true;
          } else if (i == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (grid[n][j] != null && grid[n][0] != null) {
                if ((val - (grid[n][j]! - grid[n][0]!).abs()).abs() <
                    tolerance) {
                  valid = true;
                  break;
                }
              }
            }
          } else if (j == 0) {
            for (int n = 1; n < gridSize; n++) {
              if (grid[i][n] != null && grid[0][n] != null) {
                if ((val - (grid[i][n]! - grid[0][n]!).abs()).abs() <
                    tolerance) {
                  valid = true;
                  break;
                }
              }
            }
          }
        }

        if (valid)
          correct++;
        else
          isWrong[i][j] = true;
      }
    }

    _correctAnswers = correct;
    _totalPlayerCells = total;
    _accuracyPercentage = total > 0 ? (correct / total) * 100 : 0;

    _calculateScore();

    notifyListeners();
    return correct == total;
  }

  bool endGame() {
    isPlaying = false;
    stopTimer();
    if (_gameStartTime != null) {
      _completionTimeSeconds =
          DateTime.now().difference(_gameStartTime!).inSeconds;
    }

    int correct = 0;
    int total = 0;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (isFixed[i][j]) continue;

        total++;
        final playerVal = grid[i][j];
        final solutionVal = _solutionGrid[i][j];

        if (playerVal != null && solutionVal != null) {
          if ((playerVal * 10).round() == (solutionVal * 10).round()) {
            correct++;
            isWrong[i][j] = false;
          } else {
            isWrong[i][j] = true;
          }
        } else {
          isWrong[i][j] = true;
        }
      }
    }

    _correctAnswers = correct;
    _totalPlayerCells = total;
    _accuracyPercentage = total > 0 ? (correct / total) * 100 : 0;

    _calculateScore();

    notifyListeners();
    return correct == total;
  }

  double getMultiplier() {
    // 4×4 grid only (this controller is specific to 4×4)
    if (!_useDecimals && !_hardMode) return 1.0; // Integer Easy
    if (_useDecimals && !_hardMode) return 1.1; // Decimal Easy
    if (!_useDecimals && _hardMode) return 1.1; // Integer Hard
    if (_useDecimals && _hardMode) return 1.3; // Decimal Hard

    return 1.0; // Default fallback
  }

  void _calculateScore() {
    // Base Score = Correct Answers × 10
    int baseScore = _correctAnswers * 10;

    // Time Bonus = Seconds Remaining / 15 (only for timed mode)
    int timeBonus = 0;
    if (_mode == GameMode.timed && _correctAnswers > 0) {
      timeBonus = (timeLeft.inSeconds / 15).floor();
    }

    // Total Score = (Base Score + Time Bonus) × Multiplier
    double multiplier = getMultiplier();
    score = ((baseScore + timeBonus) * multiplier).round();
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}

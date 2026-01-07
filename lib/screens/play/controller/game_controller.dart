import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

enum GameMode { untimed, timed }
enum PuzzleOperation { addition, subtraction }

class GameController extends ChangeNotifier {
  int gridSize;
  GameMode _mode = GameMode.untimed;
  PuzzleOperation operation = PuzzleOperation.addition;

  late List<List<int?>> grid;
  late List<List<int?>> _solutionGrid;
  late List<List<bool>> isFixed;
  late List<List<bool>> isWrong;

  int score = 0;
  Duration timeLeft = const Duration(minutes: 5);
  Timer? _timer;
  bool isPlaying = false;
  int seedNumbers = 0;
  bool _timerStarted = false;
  bool isGenerating = true; // Safety flag for UI loading

  // Game metrics for backend
  DateTime? _gameStartTime;
  int? _completionTimeSeconds;
  int _correctAnswers = 0;
  int _totalPlayerCells = 0;
  double _accuracyPercentage = 0.0;

  List<List<int?>> get solutionGrid => _solutionGrid;
  int get correctAnswers => _correctAnswers;
  int get totalPlayerCells => _totalPlayerCells;
  double get accuracyPercentage => _accuracyPercentage;
  int? get completionTimeSeconds => _completionTimeSeconds;
  DateTime? get gameStartTime => _gameStartTime;
  GameMode get mode => _mode;

  GameController({this.gridSize = 4}) {
    // Initialize all late fields immediately with default values
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    isWrong = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // Then start the async initialization
    _initGrid();
  }

  void setOperation(PuzzleOperation newOperation) {
    if (operation == newOperation) return;
    operation = newOperation;
    resetGame();
  }

  // UPDATED: Async initialization to prevent UI hang
  Future<void> _initGrid() async {
    isGenerating = true;
    notifyListeners();

    // Small delay to allow UI to render loader
    await Future.delayed(const Duration(milliseconds: 50));

    final random = Random();

    // Reset the grids instead of creating new ones
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

    _createBoard(random);

    isGenerating = false;
    isPlaying = true;
    notifyListeners();
  }

  // STATIC 4x4 BOARD GENERATION LOGIC
  void _createBoard(Random random) {
    List<int> availableRows = [];
    List<int> availableCols = [];

    for (int i = 0; i < gridSize; i++) {
      availableRows.add(i);
      availableCols.add(i);
    }

    seedNumbers = 0;

    try {
      // Original logic: Generate 4 primary seeds
      for (int i = 0; i < 4; i++) {
        int randomRow, randomCol;

        do {
          if (seedNumbers == 0) {
            randomRow = 0;
            randomCol = availableCols[random.nextInt(availableCols.length - 1) + 1];
          } else {
            randomRow = availableRows[random.nextInt(availableRows.length)];
            randomCol = availableCols[random.nextInt(availableCols.length)];
          }
        } while (randomRow == 0 && randomCol == 0);

        _solutionGrid[randomRow][randomCol] = _randomNumberNotInRowCol(randomRow, randomCol, random);
        grid[randomRow][randomCol] = _solutionGrid[randomRow][randomCol];
        isFixed[randomRow][randomCol] = true;

        seedNumbers++;
        availableRows.remove(randomRow);
        availableCols.remove(randomCol);
      }

      // Initial solving pass
      if (operation == PuzzleOperation.addition) {
        _solvingBoard1();
      } else {
        _solvingBoard1Subtraction();
      }

      // Original logic: Add up to 6 total seeds
      _addAdditionalSeeds(random);

      // Final solving ripple
      for (int n = 0; n < 20; n++) {
        if (operation == PuzzleOperation.addition) {
          _solvingBoard();
        } else {
          _solvingBoardSubtraction();
        }
      }

      if (!_checkBoardSolvable()) {
        _prepareGameBoard();
      } else {
        _clearBoard();
        _createBoard(random);
      }
    } catch (e) {
      _clearBoard();
      _createBoard(random);
    }
  }

  int _randomNumberNotInRowCol(int row, int col, Random random) {
    int number;
    do {
      number = random.nextInt(25) + 1; // Static range 1-25
    } while (_isNumberUsedInRowOrColumn(number, row, col));
    return number;
  }

  bool _isNumberUsedInRowOrColumn(int number, int row, int col) {
    for (int i = 0; i < gridSize; i++) {
      if (_solutionGrid[row][i] == number || _solutionGrid[i][col] == number) {
        return true;
      }
    }
    return false;
  }

  void _solvingBoard1() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = _solutionGrid[n][i]! + _solutionGrid[n][j]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[j][n] != null && _solutionGrid[i][n] != null) {
                _solutionGrid[i][j] = _solutionGrid[j][n]! + _solutionGrid[i][n]!;
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] = _solutionGrid[i][0]! + _solutionGrid[0][j]!;
            }
          }
        }
      }
    }
  }

  void _solvingBoard() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = _solutionGrid[n][i]! + _solutionGrid[n][j]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[j][n] != null) {
                _solutionGrid[i][j] = _solutionGrid[j][n]! + _solutionGrid[i][n]!;
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] = _solutionGrid[i][0]! + _solutionGrid[0][j]!;
            }
          }
        }
      }
    }
  }

  void _solvingBoard1Subtraction() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = (_solutionGrid[n][i]! - _solutionGrid[n][j]!).abs();
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[j][n] != null && _solutionGrid[i][n] != null) {
                _solutionGrid[i][j] = (_solutionGrid[j][n]! - _solutionGrid[i][n]!).abs();
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] = (_solutionGrid[i][0]! - _solutionGrid[0][j]!).abs();
            }
          }
        }
      }
    }
  }

  void _solvingBoardSubtraction() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = (_solutionGrid[n][i]! - _solutionGrid[n][j]!).abs();
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[j][n] != null) {
                _solutionGrid[i][j] = (_solutionGrid[j][n]! - _solutionGrid[i][n]!).abs();
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] = (_solutionGrid[i][0]! - _solutionGrid[0][j]!).abs();
            }
          }
        }
      }
    }
  }

  void _addAdditionalSeeds(Random random) {
    List<int> availableRows = List.generate(gridSize, (i) => i);
    List<int> availableCols = List.generate(gridSize, (i) => i);

    try {
      while (seedNumbers < 6) {
        int randomRow = availableRows[random.nextInt(availableRows.length)];
        int randomCol = availableCols[random.nextInt(availableCols.length)];

        if ((randomRow != 0 && randomCol != 0) &&
            _solutionGrid[randomRow][randomCol] == null &&
            _checkCondition(randomRow, randomCol)) {

          _solutionGrid[randomRow][randomCol] = random.nextInt(25) + 1;
          grid[randomRow][randomCol] = _solutionGrid[randomRow][randomCol];
          isFixed[randomRow][randomCol] = true;
          seedNumbers++;

          for (int n = 0; n < 20; n++) {
            if (operation == PuzzleOperation.addition) {
              _solvingBoard();
            } else {
              _solvingBoardSubtraction();
            }
          }
        }
      }
    } catch (e) {
      seedNumbers = 4;
      _addAdditionalSeeds(random);
    }
  }

  bool _checkCondition(int i, int j) {
    if (i == 0) {
      if (_solutionGrid[i][j] == null) {
        for (int n = 1; n < gridSize; n++) {
          if (_solutionGrid[n][i] == null || _solutionGrid[n][j] == null) {
            return true;
          }
        }
      }
    } else if (j == 0) {
      if (_solutionGrid[i][j] == null) {
        for (int n = 1; n < gridSize; n++) {
          if (_solutionGrid[n][i] == null || _solutionGrid[n][j] == null) {
            return true;
          }
        }
      }
    } else {
      if (_solutionGrid[i][j] == null) {
        if (_solutionGrid[i][0] == null || _solutionGrid[0][j] == null) {
          return true;
        }
      }
    }
    return false;
  }

  bool _checkBoardSolvable() {
    int zeroCount = 0;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (_solutionGrid[i][j] == null) {
          zeroCount++;
        }
      }
    }
    return zeroCount > 0;
  }

  void _prepareGameBoard() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (!isFixed[i][j]) {
          grid[i][j] = null;
        }
      }
    }
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
    seedNumbers = 0;
  }

  // ──────────────────────────────────────────────
  // GAME ACTIONS
  // ──────────────────────────────────────────────

  void startGame() {
    _gameStartTime = DateTime.now();
    isPlaying = true;
    notifyListeners();
  }

  void updateCell(int row, int col, int? value) {
    if (isFixed[row][col] || !isPlaying || (row == 0 && col == 0)) return;
    grid[row][col] = value;
    notifyListeners();
  }

  // LOOPHOLE-FREE VALIDATION (Checks math logic, not just hardcoded values)
  bool validateGrid() {
    int correctCount = 0;
    int totalPlayerCells = 0;

    // 1. Reset isWrong grid
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    // 2. Compare player grid against the solution grid
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        // Skip the operation cell at [0,0]
        if (i == 0 && j == 0) continue;

        // Only evaluate cells that weren't fixed seeds
        if (!isFixed[i][j]) {
          totalPlayerCells++;

          // If cell is empty OR the value doesn't match the solution exactly
          if (grid[i][j] == null || grid[i][j] != _solutionGrid[i][j]) {
            isWrong[i][j] = true;
          } else {
            correctCount++;
          }
        }
      }
    }

    // 3. Update Metrics
    _totalPlayerCells = totalPlayerCells;
    _correctAnswers = correctCount;

    // Accuracy is (Correct Player Cells / Total Player Cells) * 100
    _accuracyPercentage = (totalPlayerCells > 0)
        ? (correctCount / totalPlayerCells) * 100
        : 0.0;

    // 4. Calculate Final Score
    if (mode == GameMode.untimed) {
      score = _accuracyPercentage.round();
    } else {
      // Timed mode: 70% based on accuracy, 30% potential time bonus
      int baseScore = (_accuracyPercentage * 0.7).round();
      int timeBonus = (timeLeft.inSeconds > 240) ? 30 : (timeLeft.inSeconds > 120 ? 15 : 5);
      score = baseScore + timeBonus;
    }

    // 5. Final State Update
    bool isPerfect = correctCount == totalPlayerCells;
    if (isPerfect) {
      isPlaying = false;
      stopTimer();
      if (_gameStartTime != null) {
        _completionTimeSeconds = DateTime.now().difference(_gameStartTime!).inSeconds;
      }
    }

    notifyListeners();
    return isPerfect;
  }

  void startTimer() {
    if (mode != GameMode.timed || _timerStarted) return;
    _timerStarted = true;
    _gameStartTime ??= DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft.inSeconds > 0 && isPlaying) {
        timeLeft -= const Duration(seconds: 1);
        notifyListeners();
      } else {
        stopTimer();
        isPlaying = false;
        validateGrid(); // Final validation when time is up
        notifyListeners();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timerStarted = false;
  }

  void resetGame() {
    stopTimer();
    score = 0;
    timeLeft = const Duration(minutes: 5);
    _timerStarted = false;
    _gameStartTime = null;
    _completionTimeSeconds = null;
    _accuracyPercentage = 0.0;
    _initGrid();
  }

  void toggleMode() {
    _mode = (_mode == GameMode.untimed) ? GameMode.timed : GameMode.untimed;
    notifyListeners();
  }

  set mode(GameMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
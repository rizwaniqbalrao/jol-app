import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

enum GameMode { untimed, timed }

enum PuzzleOperation { addition, subtraction }

class GameController extends ChangeNotifier {
  final int gridSize;
  GameMode _mode = GameMode.untimed;
  PuzzleOperation operation = PuzzleOperation.addition;
  bool _useDecimals = false;

  late List<List<double?>> grid;
  late List<List<double?>> _solutionGrid;
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

  List<List<double?>> get solutionGrid => _solutionGrid;
  int get correctAnswers => _correctAnswers;
  int get totalPlayerCells => _totalPlayerCells;
  double get accuracyPercentage => _accuracyPercentage;
  int? get completionTimeSeconds => _completionTimeSeconds;
  DateTime? get gameStartTime => _gameStartTime;
  GameMode get mode => _mode;
  bool get useDecimals => _useDecimals;

  GameController({this.gridSize = 4}) {
    // Initialize all late fields immediately with default values
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    isWrong = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // Then start the async initialization
    _initGrid();
  }

  // SETTINGS MANAGEMENT

  bool _hardMode = false;
  bool get hardMode => _hardMode;

  void setHardMode(bool value) {
    if (_hardMode == value) return;
    _hardMode = value;
    resetGame();
  }

  int get _maxSeedValue => _hardMode ? 332 : gridSize * gridSize;

  double get _maxResultValue => _hardMode ? 999.0 : double.infinity;

  void setOperation(PuzzleOperation newOperation) {
    if (operation == newOperation) return;
    operation = newOperation;
    resetGame();
  }

  void setUseDecimals(bool useDecimals) {
    if (_useDecimals == useDecimals) return;
    _useDecimals = useDecimals;
    resetGame();
  }

  // Generate random number (integer or decimal based on _useDecimals flag)
  double _generateRandomNumber(Random random) {
    if (_useDecimals) {
      final max = _hardMode ? 332 : 9;
      return ((random.nextInt(max * 10 - 10) + 11) / 10.0);
    } else {
      return (random.nextInt(_maxSeedValue) + 1).toDouble();
    }
  }

  double? _safeResult(double value) {
    if (_hardMode && value > _maxResultValue) return null;
    return value;
  }

// Helper function to compare doubles with tolerance
  bool nearlyEqual(double a, double b, {double tolerance = 0.01}) {
    return (a - b).abs() <= tolerance;
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
  void _createBoard(Random random, {int maxAttempts = 25}) {
    List<int> availableRows = [];
    List<int> availableCols = [];

    for (int i = 0; i < gridSize; i++) {
      availableRows.add(i);
      availableCols.add(i);
    }

    seedNumbers = 0;

    try {
      // Original logic: Generate 4 primary seeds   //make changes for 5x5
      for (int i = 0; i < gridSize; i++) {
        int randomRow, randomCol;

        do {
          if (seedNumbers == 0) {
            randomRow = 0;
            randomCol =
                availableCols[random.nextInt(availableCols.length - 1) + 1];
          } else {
            randomRow = availableRows[random.nextInt(availableRows.length)];
            randomCol = availableCols[random.nextInt(availableCols.length)];
          }
        } while (randomRow == 0 && randomCol == 0);

        _solutionGrid[randomRow][randomCol] =
            _randomNumberNotInRowCol(randomRow, randomCol, random);
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

  double _randomNumberNotInRowCol(int row, int col, Random random) {
    double number;
    int attempts = 0;

    do {
      number = _generateRandomNumber(random);
      attempts++;
      if (attempts > 100) break;
    } while (_isNumberUsedInRowOrColumn(number, row, col) ||
        (_hardMode && number >= 333));

    return number;
  }

  bool _isNumberUsedInRowOrColumn(double number, int row, int col) {
    const tolerance = 0.001;
    for (int i = 0; i < gridSize; i++) {
      final rowVal = _solutionGrid[row][i];
      final colVal = _solutionGrid[i][col];
      if (rowVal != null && (rowVal - number).abs() < tolerance) return true;
      if (colVal != null && (colVal - number).abs() < tolerance) return true;
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
                _solutionGrid[i][j] =
                    _solutionGrid[n][i]! + _solutionGrid[n][j]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                _solutionGrid[i][j] =
                    _solutionGrid[i][n]! + _solutionGrid[0][n]!;
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              final result = _solutionGrid[i][0]! + _solutionGrid[0][j]!;
              _solutionGrid[i][j] = _safeResult(result);
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
                _solutionGrid[i][j] =
                    _solutionGrid[n][i]! + _solutionGrid[n][j]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                _solutionGrid[i][j] =
                    _solutionGrid[i][n]! + _solutionGrid[0][n]!;
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              final result = _solutionGrid[i][0]! + _solutionGrid[0][j]!;
              _solutionGrid[i][j] = _safeResult(result);
            }
          }
        }
      }
    }
  }

  // bool integerMode = false;

  // void setIntegerMode(bool value) {
  //   integerMode = value;
  //   notifyListeners();
  // }

  void _solvingBoard1Subtraction() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] =
                    (_solutionGrid[n][i]! - _solutionGrid[n][j]!).abs();
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                _solutionGrid[i][j] =
                    (_solutionGrid[i][n]! - _solutionGrid[0][n]!).abs();
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] =
                  (_solutionGrid[i][0]! - _solutionGrid[0][j]!).abs();
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
                _solutionGrid[i][j] =
                    (_solutionGrid[n][i]! - _solutionGrid[n][j]!).abs();
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                _solutionGrid[i][j] =
                    (_solutionGrid[i][n]! - _solutionGrid[0][n]!).abs();
                break;
              }
            }
          }
        } else {
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] =
                  (_solutionGrid[i][0]! - _solutionGrid[0][j]!).abs();
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
          _solutionGrid[randomRow][randomCol] = _generateRandomNumber(random);
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

  void updateCell(int row, int col, double? value) {
    if (isFixed[row][col]) return;

    grid[row][col] = value;
    //_validateCell(row, col);
    notifyListeners();
  }

  // Store raw input text (including partial decimals like "12.")
  final Map<String, String> rawInputs = {};

  void updateRawInput(int row, int col, String rawText) {
    if (isFixed[row][col]) return;
    final key = '$row-$col';
    rawInputs[key] = rawText;

    if (rawText.isEmpty) {
      grid[row][col] = null;
    } else {
      // Try to parse as double; if it fails (e.g., "12."), keep previous value
      final parsed = double.tryParse(rawText);
      if (parsed != null) {
        grid[row][col] = parsed;
      }
    }
    // if (areAllPlayerCellsFilled()) {
    //   validateGrid(); // <-- THIS TRIGGERS GAME END
    // }

    notifyListeners();
  }

  // Finalize a cell's raw input into the numeric grid value and run final validation
  void finalizeCellInput(int row, int col, String rawText) {
    if (isFixed[row][col]) return;

    final key = '$row-$col';
    rawInputs[key] = rawText;

    final parsed = safeParse(rawText, decimalPlaces: 1);
    if (parsed != null) {
      grid[row][col] = parsed;
    }
    // If parsing fails, keep existing grid value (do not overwrite with null)

    // NOTE: Removed per-cell and full-grid validation here to avoid
    // live validation (cells turning red while the player is entering values).
    // Final validation should only run when the game is ended by the user
    // (e.g., via `endGame()` or explicit Stop action).
    notifyListeners();
  }

  double? _computeExpectedValue(int row, int col) {
    final rowHeader = grid[row][0];
    final colHeader = grid[0][col];

    if (rowHeader == null || colHeader == null) return null;

    if (operation == PuzzleOperation.addition) {
      return rowHeader + colHeader;
    } else {
      return (rowHeader - colHeader).abs();
    }
  }

  void _validateCell(int row, int col) {
    if (isFixed[row][col]) return;

    const tolerance = 0.01;
    bool isValid = false;

    if (grid[row][col] == null) {
      isWrong[row][col] = false;
      return;
    }

    // Validate column header (row=0, col>0): colHead[col] = ANY middleNumber[n][col] + rowHead[n]
    if (row == 0 && col > 0) {
      for (int n = 1; n < gridSize; n++) {
        final middleNum = grid[n][col];
        final rowHead = grid[n][0];
        if (middleNum != null && rowHead != null) {
          double expected;
          if (operation == PuzzleOperation.addition) {
            expected = middleNum + rowHead;
          } else {
            expected = (middleNum - rowHead).abs();
          }
          if ((grid[row][col]! - expected).abs() <= tolerance) {
            isValid = true;
            break;
          }
        }
      }
    }
    // Validate row header (row>0, col=0): rowHead[row] = ANY middleNumber[row][n] + colHead[n]
    else if (row > 0 && col == 0) {
      for (int n = 1; n < gridSize; n++) {
        final middleNum = grid[row][n];
        final colHead = grid[0][n];
        if (middleNum != null && colHead != null) {
          double expected;
          if (operation == PuzzleOperation.addition) {
            expected = middleNum + colHead;
          } else {
            expected = (middleNum - colHead).abs();
          }
          if ((grid[row][col]! - expected).abs() <= tolerance) {
            isValid = true;
            break;
          }
        }
      }
    }
    // Validate middle number (row>0, col>0): cell[row,col] = rowHeader[row,0] ± colHeader[0,col]
    else {
      final expected = _computeExpectedValue(row, col);
      if (expected != null && (grid[row][col]! - expected).abs() <= tolerance) {
        isValid = true;
      }
    }

    isWrong[row][col] = !isValid;
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

    const tolerance = 0.01;

    // 2. Validate player grid using mathematical logic (not solutionGrid comparison)
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        // Skip the operation cell at [0,0]
        if (i == 0 && j == 0) continue;

        // Only evaluate cells that weren't fixed seeds
        if (!isFixed[i][j]) {
          totalPlayerCells++;

          // If cell is empty
          if (grid[i][j] == null) {
            isWrong[i][j] = true;
          } else {
            bool isValid = false;

            // Validate column header (i=0, j>0): colHead[j] = ANY middleNumber[n][j] + rowHead[n]
            if (i == 0 && j > 0) {
              for (int n = 1; n < gridSize; n++) {
                final middleNum = grid[n][j];
                final rowHead = grid[n][0];
                if (middleNum != null && rowHead != null) {
                  double expected;
                  if (operation == PuzzleOperation.addition) {
                    expected = middleNum + rowHead;
                  } else {
                    expected = (middleNum - rowHead).abs();
                  }
                  if ((grid[i][j]! - expected).abs() <= tolerance) {
                    isValid = true;
                    break;
                  }
                }
              }
            }
            // Validate row header (i>0, j=0): rowHead[i] = ANY middleNumber[i][n] + colHead[n]
            else if (i > 0 && j == 0) {
              for (int n = 1; n < gridSize; n++) {
                final middleNum = grid[i][n];
                final colHead = grid[0][n];
                if (middleNum != null && colHead != null) {
                  double expected;
                  if (operation == PuzzleOperation.addition) {
                    expected = middleNum + colHead;
                  } else {
                    expected = (middleNum - colHead).abs();
                  }
                  if ((grid[i][j]! - expected).abs() <= tolerance) {
                    isValid = true;
                    break;
                  }
                }
              }
            }
            // Validate middle number (i>0, j>0): cell[i,j] = rowHeader[i,0] ± colHeader[0,j]
            else {
              final expected = _computeExpectedValue(i, j);
              if (expected != null &&
                  (grid[i][j]! - expected).abs() <= tolerance) {
                isValid = true;
              }
            }

            if (isValid) {
              correctCount++;
            } else {
              isWrong[i][j] = true;
            }
          }
        }
      }
    }

    // 3. Update Metrics
    _totalPlayerCells = totalPlayerCells;
    _correctAnswers = correctCount;

    // Accuracy is (Correct Player Cells / Total Player Cells) * 100
    _accuracyPercentage =
        (totalPlayerCells > 0) ? (correctCount / totalPlayerCells) * 100 : 0.0;

    // 4. Calculate Final Score
    if (mode == GameMode.untimed) {
      score = _accuracyPercentage.round();
    } else {
      // Timed mode: 70% based on accuracy, 30% potential time bonus
      int baseScore = (_accuracyPercentage * 0.7).round();
      int timeBonus =
          (timeLeft.inSeconds > 240) ? 30 : (timeLeft.inSeconds > 120 ? 15 : 5);
      score = baseScore + timeBonus;
    }

    // 5. Final State Update
    bool isPerfect = correctCount == totalPlayerCells;
    if (isPerfect) {
      isPlaying = false;
      stopTimer();
      if (_gameStartTime != null) {
        _completionTimeSeconds =
            DateTime.now().difference(_gameStartTime!).inSeconds;
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
        endGame(); // FINAL & SAFE
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

// end game method instead of validate grid

  bool endGame() {
    int correctCount = 0;
    int totalPlayerCells = 0;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    // Helper to round to 1 decimal place
    double round(double v) => (v * 10).round() / 10.0;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;

        if (!isFixed[i][j]) {
          totalPlayerCells++;

          final playerValue = grid[i][j];
          final solutionValue = _solutionGrid[i][j];

          if (playerValue == null || solutionValue == null) {
            isWrong[i][j] = true;
            continue;
          }

          // Round both values and compare exactly
          if (round(playerValue) == round(solutionValue)) {
            correctCount++;
          } else {
            isWrong[i][j] = true;
          }
        }
      }
    }

    // Rest of the method remains the same...
    _totalPlayerCells = totalPlayerCells;
    _correctAnswers = correctCount;
    _accuracyPercentage =
        totalPlayerCells > 0 ? (correctCount / totalPlayerCells) * 100 : 0.0;

    if (mode == GameMode.untimed) {
      score = _accuracyPercentage.round();
    } else {
      final baseScore = (_accuracyPercentage * 0.7).round();
      final timeBonus = timeLeft.inSeconds > 240
          ? 30
          : timeLeft.inSeconds > 120
              ? 15
              : 5;
      score = baseScore + timeBonus;
    }

    isPlaying = false;
    stopTimer();

    if (_gameStartTime != null) {
      _completionTimeSeconds =
          DateTime.now().difference(_gameStartTime!).inSeconds;
    }

    notifyListeners();

    return correctCount == totalPlayerCells;
  }

  //helping method for parse
  /// Safely parses a string to double and rounds it to a fixed number of decimal places
  /// to prevent floating-point precision issues (e.g. 1.1 + 2.2 = 3.3000000000000003)
  double? safeParse(String? text, {int decimalPlaces = 1}) {
    if (text == null || text.trim().isEmpty) return null;

    final cleaned = text.trim();

    // Handle common incomplete inputs like "12." or ".5"
    String normalized = cleaned;
    if (normalized.endsWith('.')) {
      normalized += '0';
    }

    final parsed = double.tryParse(normalized);
    if (parsed == null) return null;

    // Round to desired decimal places
    final factor = pow(10, decimalPlaces);
    return (parsed * factor).round() / factor;
  }

  // Helper (add this in your class)
  // double _round(double value) {
  //   return (value * 10).round() / 10.0;
  // }
}

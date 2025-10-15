import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

enum GameMode { untimed, timed }
enum PuzzleOperation { addition, subtraction }

class GameController extends ChangeNotifier {
  int gridSize;
  GameMode _mode = GameMode.untimed;
  PuzzleOperation operation = PuzzleOperation.addition; // NEW
  late List<List<int?>> grid; // visible cells (null = empty)
  late List<List<int?>> _solutionGrid; // full solution
  late List<List<bool>> isFixed; // prefilled clues
  late List<List<bool>> isWrong; // tracks incorrect cells for highlighting
  int score = 0;
  Duration timeLeft = const Duration(minutes: 5);
  Timer? _timer;
  bool isPlaying = false;
  int seedNumbers = 0;

  GameController({this.gridSize = 4}) {
    _initGrid();
    if (mode == GameMode.timed) {
      startTimer();
    }
  }

  // NEW: Method to change operation and regenerate puzzle
  void setOperation(PuzzleOperation newOperation) {
    if (operation == newOperation) return;
    operation = newOperation;
    resetGame();
  }

  // ──────────────────────────────────────────────
  // INITIALIZATION - PORTED FROM JAALOO.COM
  // ──────────────────────────────────────────────
  void _initGrid() {
    final random = Random();
    // Initialize empty structures
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    isWrong = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // Reference cell (top-left) - always fixed
    grid[0][0] = -1;
    _solutionGrid[0][0] = -1;
    isFixed[0][0] = true;

    // Generate puzzle using jaaloo.com logic
    _createBoard(random);
    isPlaying = true;
    notifyListeners();
  }

  void _createBoard(Random random) {
    List<int> availableRows = [];
    List<int> availableCols = [];

    for (int i = 0; i < gridSize; i++) {
      availableRows.add(i);
      availableCols.add(i);
    }

    seedNumbers = 0;

    try {
      // PHASE 1: Place first 4 seed numbers
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
        } while (randomRow == 0 && randomCol == 0); // Avoid top-left corner

        // Place a random number that's not already in that row or column
        _solutionGrid[randomRow][randomCol] = _randomNumberNotInRowCol(randomRow, randomCol, random);
        grid[randomRow][randomCol] = _solutionGrid[randomRow][randomCol];
        isFixed[randomRow][randomCol] = true;

        seedNumbers++;
        availableRows.remove(randomRow);
        availableCols.remove(randomCol);
      }

      // PHASE 2: Solve the board to fill in deducible values
      if (operation == PuzzleOperation.addition) {
        _solvingBoard1();
      } else {
        _solvingBoard1Subtraction();
      }

      // PHASE 3: Add 2 more seed numbers (total 6)
      _addAdditionalSeeds(random);

      // PHASE 4: Final solve to complete the grid
      for (int n = 0; n < 20; n++) {
        if (operation == PuzzleOperation.addition) {
          _solvingBoard();
        } else {
          _solvingBoardSubtraction();
        }
      }

      // Check if board is fully solved
      if (!_checkBoardSolvable()) {
        // Board is solvable, prepare for gameplay
        _prepareGameBoard();
      } else {
        // Board has unsolvable cells, restart
        debugPrint("Board not solvable, regenerating...");
        _clearBoard();
        _createBoard(random);
      }
    } catch (e) {
      debugPrint("Error in board creation: $e");
      _clearBoard();
      _createBoard(random);
    }
  }

  int _randomNumberNotInRowCol(int row, int col, Random random) {
    int number;
    do {
      number = random.nextInt(9) + 1; // 1 to 9 (less than 10)
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

  // ──────────────────────────────────────────────
  // ADDITION MODE SOLVING (ORIGINAL)
  // ──────────────────────────────────────────────
  void _solvingBoard1() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) {
          continue;
        } else if (i == 0 && (j >= 1 && j < gridSize)) {
          // Top row (B values): B = sum of pairs in column
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = _solutionGrid[n][i]! + _solutionGrid[n][j]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          // Left column (A values): A = sum of pairs in row
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[j][n] != null && _solutionGrid[i][n] != null) {
                _solutionGrid[i][j] = _solutionGrid[j][n]! + _solutionGrid[i][n]!;
                break;
              }
            }
          }
        } else {
          // Intersection cells: C = A + B
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
        if (i == 0 && j == 0) {
          continue;
        } else if (i == 0 && (j >= 1 && j < gridSize)) {
          // Top row
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = _solutionGrid[n][i]! + _solutionGrid[n][j]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          // Left column
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[j][n] != null) {
                _solutionGrid[i][j] = _solutionGrid[j][n]! + _solutionGrid[i][n]!;
                break;
              }
            }
          }
        } else {
          // Intersection
          if (_solutionGrid[i][j] == null) {
            if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
              _solutionGrid[i][j] = _solutionGrid[i][0]! + _solutionGrid[0][j]!;
            }
          }
        }
      }
    }
  }

  // ──────────────────────────────────────────────
  // SUBTRACTION MODE SOLVING (NEW)
  // ──────────────────────────────────────────────
  void _solvingBoard1Subtraction() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) {
          continue;
        } else if (i == 0 && (j >= 1 && j < gridSize)) {
          // Top row (B values): B = |difference| of pairs in column
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = (_solutionGrid[n][i]! - _solutionGrid[n][j]!).abs();
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          // Left column (A values): A = |difference| of pairs in row
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[j][n] != null && _solutionGrid[i][n] != null) {
                _solutionGrid[i][j] = (_solutionGrid[j][n]! - _solutionGrid[i][n]!).abs();
                break;
              }
            }
          }
        } else {
          // Intersection cells: C = |A - B|
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
        if (i == 0 && j == 0) {
          continue;
        } else if (i == 0 && (j >= 1 && j < gridSize)) {
          // Top row
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                _solutionGrid[i][j] = (_solutionGrid[n][i]! - _solutionGrid[n][j]!).abs();
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          // Left column
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[j][n] != null) {
                _solutionGrid[i][j] = (_solutionGrid[j][n]! - _solutionGrid[i][n]!).abs();
                break;
              }
            }
          }
        } else {
          // Intersection
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
    List<int> availableRows = [];
    List<int> availableCols = [];

    for (int i = 0; i < gridSize; i++) {
      availableRows.add(i);
      availableCols.add(i);
    }

    try {
      while (seedNumbers < 6) {
        int randomRow = availableRows[random.nextInt(availableRows.length)];
        int randomCol = availableCols[random.nextInt(availableCols.length)];

        // Check if this position is valid for a seed
        if ((randomRow != 0 && randomCol != 0) &&
            _solutionGrid[randomRow][randomCol] == null &&
            _checkCondition(randomRow, randomCol)) {

          _solutionGrid[randomRow][randomCol] = random.nextInt(9) + 1; // 1-9 (less than 10)
          grid[randomRow][randomCol] = _solutionGrid[randomRow][randomCol];
          isFixed[randomRow][randomCol] = true;
          seedNumbers++;

          // Solve multiple times to propagate
          for (int n = 0; n < 20; n++) {
            if (operation == PuzzleOperation.addition) {
              _solvingBoard();
            } else {
              _solvingBoardSubtraction();
            }
          }

          availableRows.remove(randomRow);
          availableCols.remove(randomCol);
        }
      }
    } catch (e) {
      debugPrint("Error adding seeds: $e");
      // Reset to 4 seeds and try again
      for (int i = 0; i < gridSize; i++) {
        for (int j = 0; j < gridSize; j++) {
          if (!isFixed[i][j] || seedNumbers > 4) {
            if (isFixed[i][j] && seedNumbers > 4) {
              _solutionGrid[i][j] = null;
              grid[i][j] = null;
              isFixed[i][j] = false;
            }
          }
        }
      }
      seedNumbers = 4;
      _addAdditionalSeeds(random);
    }
  }

  bool _checkCondition(int i, int j) {
    if (i == 0) {
      // Top row position
      if (_solutionGrid[i][j] == null) {
        for (int n = 1; n < gridSize; n++) {
          if (_solutionGrid[n][i] == null || _solutionGrid[n][j] == null) {
            return true;
          } else {
            return false;
          }
        }
      }
    } else if (j == 0) {
      // Left column position
      if (_solutionGrid[i][j] == null) {
        for (int n = 1; n < gridSize; n++) {
          if (_solutionGrid[n][i] == null || _solutionGrid[n][j] == null) {
            return true;
          } else {
            return false;
          }
        }
      }
    } else {
      // Intersection position
      if (_solutionGrid[i][j] == null) {
        if (_solutionGrid[i][0] == null || _solutionGrid[0][j] == null) {
          return true;
        } else {
          return false;
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
    return zeroCount > 0; // Returns true if there are unsolved cells
  }

  void _prepareGameBoard() {
    // Clear the player's grid, keeping only the seed numbers
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
        if (grid[i][j] == _solutionGrid[i][j]) {
          correctCount++;
        }
      }
    }

    // Progress score: normalized to 100
    score = (correctCount / totalCells * 100).round();

    if (isComplete && correctCount == totalCells) {
      // Final score based on mode
      if (mode == GameMode.untimed) {
        score = 100;
      } else {
        int totalSeconds = 300;
        int remaining = timeLeft.inSeconds.clamp(0, totalSeconds);
        score = (remaining / totalSeconds * 100).round().clamp(0, 100);
      }
      isPlaying = false;
      if (mode == GameMode.timed) {
        stopTimer();
      }
    }
    notifyListeners();
    return isComplete && correctCount == totalCells;
  }

  void checkGrid() {
    // Reset all wrong flags
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    // Check each cell against solution
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

  void solvePuzzle() {
    if (!isPlaying) return;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        grid[i][j] = _solutionGrid[i][j];
        isFixed[i][j] = true;
      }
    }

    // Clear wrong flags
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    isPlaying = false;
    if (mode == GameMode.timed) {
      stopTimer();
    }
    score = 0; // No points for auto-solve
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
    if (mode == GameMode.timed) {
      startTimer();
    }
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
  // HELPER METHODS
  // ──────────────────────────────────────────────
  String getRuleSymbol(int row, int col) {
    if (row == 0 || col == 0) return '';
    return operation == PuzzleOperation.addition ? '+' : '-';
  }

  String getRuleDescription(int row, int col) {
    if (row == 0 || col == 0) return '';
    return operation == PuzzleOperation.addition ? 'A + B = C' : '|A - B| = C';
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
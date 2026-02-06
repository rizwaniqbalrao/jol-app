import 'dart:math';
import 'package:flutter/material.dart';

enum PuzzleOperation { addition, subtraction }

class GameController5x5 extends ChangeNotifier {
  final int gridSize = 5;
  PuzzleOperation operation = PuzzleOperation.addition;
  bool _useDecimals = false;
  bool _hardMode = false;

  late List<List<double?>> grid;
  late List<List<double?>> _solutionGrid;
  late List<List<bool>> isFixed;
  late List<List<bool>> isWrong;

  int seedNumbers = 0;
  bool isGenerating = true;

  bool get hardMode => _hardMode;
  bool get useDecimals => _useDecimals;
  List<List<double?>> get solutionGrid => _solutionGrid;

  GameController5x5({
    PuzzleOperation? operation,
    bool useDecimals = false,
    bool hardMode = false,
  }) {
    if (operation != null) this.operation = operation;
    _useDecimals = useDecimals;
    _hardMode = hardMode;

    // Initialize all late fields immediately with default values
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    isWrong = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // Then start the initialization
    //_initGrid();
  }

  int get _maxSeedValue => _hardMode ? 332 : gridSize * gridSize;
  double get _maxResultValue => _hardMode ? 999.0 : double.infinity;

  void setOperation(PuzzleOperation newOperation) {
    if (operation == newOperation) return;
    operation = newOperation;
    reset();
  }

  void setUseDecimals(bool useDecimals) {
    if (_useDecimals == useDecimals) return;
    _useDecimals = useDecimals;
    reset();
  }

  void setHardMode(bool value) {
    if (_hardMode == value) return;
    _hardMode = value;
    reset();
  }

  double? _safeResult(double value) {
    if (_hardMode && value > _maxResultValue) return null;
    return (value * 10).round() / 10.0;
  }

  Future<void> _initGrid() async {
    isGenerating = true;
    notifyListeners();

    // Small delay to allow UI to render loader
    await Future.delayed(const Duration(milliseconds: 50));

    final random = Random();

    // Reset the grids
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
    notifyListeners();
  }

  double _generateRandomNumber(Random random) {
    if (_useDecimals) {
      final max = _hardMode ? 332 : 9;
      return ((random.nextInt(max * 10 - 10) + 11) / 10.0);
    } else {
      final maxSeedValue = _hardMode ? 332 : _maxSeedValue;
      return (random.nextInt(maxSeedValue) + 1).toDouble();
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
    if (operation == PuzzleOperation.addition) {
      _solveAddition1();
    } else {
      _solveSubtraction1();
    }
  }

  void _solveAddition1() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                // Top Header = Inner - Left Header
                _solutionGrid[i][j] =
                    _solutionGrid[n][j]! - _solutionGrid[n][i]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                // Left Header = Inner - Top Header
                _solutionGrid[i][j] =
                    _solutionGrid[i][n]! - _solutionGrid[0][n]!;
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

  void _solveSubtraction1() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (_solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                // Top Header = Left Header + Inner OR Top Header = |Left Header - Inner|
                // But safest is Top = Left + Inner because Inner = |Left - Top|
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
                // Left Header = Top Header + Inner
                _solutionGrid[i][j] =
                    _solutionGrid[0][n]! + _solutionGrid[i][n]!;
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

  void _solvingBoard() {
    if (operation == PuzzleOperation.addition) {
      _solveAddition1();
    } else {
      _solveSubtraction1();
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

  void _createBoard(Random random, {int maxAttempts = 10}) {
    int attempts = 0;
    bool success = false;

    while (!success && attempts < maxAttempts) {
      attempts++;

      // Clear board at the START of each attempt (except first)
      if (attempts > 1) {
        _clearBoard();
      }

      List<int> availableRows = [];
      List<int> availableCols = [];

      for (int i = 0; i < gridSize; i++) {
        availableRows.add(i);
        availableCols.add(i);
      }

      seedNumbers = 0;

      try {
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
        _solvingBoard1();

        // Add up to 6 total seeds
        _addAdditionalSeeds(random);

        // Final solving ripple
        for (int n = 0; n < 20; n++) {
          _solvingBoard();
        }

        if (!_checkBoardSolvable()) {
          // Prepare game board - SUCCESS!
          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              if (!isFixed[i][j]) {
                grid[i][j] = null;
              }
            }
          }
          success = true;
        }
        // If board is not solvable, loop will continue and clear at start of next attempt
      } catch (e) {
        // Error occurred, loop will continue and clear at start of next attempt
      }
    }

    // If we couldn't generate a valid board after max attempts,
    // just use what we have (seeds from last attempt are still in grid)
    if (!success) {
      for (int i = 0; i < gridSize; i++) {
        for (int j = 0; j < gridSize; j++) {
          if (!isFixed[i][j]) {
            grid[i][j] = null;
          }
        }
      }
    }
  }

  void _addAdditionalSeeds(Random random) {
    List<int> availableRows = List.generate(gridSize, (i) => i);
    List<int> availableCols = List.generate(gridSize, (i) => i);

    int attempts = 0;
    int maxAttempts = 100; // Prevent infinite loop

    // Calculate target seeds: ceil(n * 1.5)
    int targetSeeds = (gridSize * 1.5).ceil();
    // Alternatively: (2 * gridSize) - 1;

    try {
      while (seedNumbers < targetSeeds && attempts < maxAttempts) {
        attempts++;

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
            _solvingBoard();
          }
        }
      }
    } catch (e) {
      // Just return current seed count
    }
  }

  void _clearBoard() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        grid[i][j] = null;
        _solutionGrid[i][j] = null;
        isFixed[i][j] = false;
      }
    }
    grid[0][0] = -1;
    _solutionGrid[0][0] = -1;
    isFixed[0][0] = true;
  }

  // Public methods for UI interaction
  double? getCell(int row, int col) => grid[row][col];
  bool getFixed(int row, int col) => isFixed[row][col];
  bool getWrong(int row, int col) => isWrong[row][col];

  void updateCell(int row, int col, double? value) {
    if (isFixed[row][col]) return;

    grid[row][col] = value;
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

  void validateAll() {
    const tolerance = 0.001;

    // Reset wrong status
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        isWrong[i][j] = false;
      }
    }

    // Validate using mathematical logic, not hardcoded values
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        // Skip the operation cell at [0,0]
        if (i == 0 && j == 0) continue;

        // Only evaluate cells that weren't fixed seeds
        if (!isFixed[i][j]) {
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

            if (!isValid) {
              isWrong[i][j] = true;
            }
          }
        }
      }
    }

    notifyListeners();
  }

  void reset() {
    _initGrid();
  }

  void finalizeCellInput(int row, int col, String rawText) {
    if (isFixed[row][col]) return;

    final parsed = _safeParse(rawText, decimalPlaces: 1);
    if (parsed != null) {
      grid[row][col] = parsed;
    }
    notifyListeners();
  }

  double? _safeParse(String? text, {int decimalPlaces = 1}) {
    if (text == null || text.trim().isEmpty) return null;

    String cleaned = text.trim();

    if (cleaned.endsWith('.')) {
      cleaned += '0';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;

    final factor = pow(10, decimalPlaces).toDouble();
    return (parsed * factor).round() / factor;
  }
}
import 'dart:math';
import '../controller/base_game_controller_nxn.dart';
import '../models/room_models.dart';

class PuzzleUtils {
  static double generateRandomNumber(
      Random random, bool useDecimals, bool hardMode, int gridSize) {
    if (useDecimals) {
      final max = hardMode ? 332 : 9;
      return ((random.nextInt(max * 10 - 10) + 11) / 10.0);
    } else {
      final maxSeedValue = hardMode ? 332 : (gridSize * gridSize);
      return (random.nextInt(maxSeedValue) + 1).toDouble();
    }
  }

  static double? _staticSafeResult(double value, bool hardMode) {
    final maxResultValue = hardMode ? 999.0 : double.infinity;
    if (hardMode && value > maxResultValue) return null;
    return value;
  }

  static double _randomNumberNotInRowCol(
      int row,
      int col,
      Random random,
      List<List<double?>> solutionGrid,
      int gridSize,
      bool useDecimals,
      bool hardMode) {
    double number;
    int attempts = 0;

    do {
      number = generateRandomNumber(random, useDecimals, hardMode, gridSize);
      attempts++;
      if (attempts > 100) break;
    } while (_isNumberUsedInRowOrColumnStatic(
            number, row, col, solutionGrid, gridSize) ||
        (hardMode && number >= 333));

    return number;
  }

  static bool _isNumberUsedInRowOrColumnStatic(double number, int row, int col,
      List<List<double?>> solutionGrid, int gridSize) {
    const tolerance = 0.001;
    for (int i = 0; i < gridSize; i++) {
        if (row < solutionGrid.length && i < solutionGrid[row].length) {
            final rowVal = solutionGrid[row][i];
            if (rowVal != null && (rowVal - number).abs() < tolerance) return true;
        }
        if (i < solutionGrid.length && col < solutionGrid[i].length) {
            final colVal = solutionGrid[i][col];
            if (colVal != null && (colVal - number).abs() < tolerance) return true;
        }
    }
    return false;
  }

  static void solvingBoard1Static(List<List<double?>> solutionGrid,
      int gridSize, PuzzleOperation operation, bool hardMode) {
    if (operation == PuzzleOperation.addition) {
      _solveAddition1(solutionGrid, gridSize, hardMode);
    } else {
      _solveSubtraction1(solutionGrid, gridSize);
    }
  }

  static void _solveAddition1(
      List<List<double?>> solutionGrid, int gridSize, bool hardMode) {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (solutionGrid[n][i] != null && solutionGrid[n][j] != null) {
                solutionGrid[i][j] = solutionGrid[n][j]! - solutionGrid[n][i]!;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (solutionGrid[i][n] != null && solutionGrid[0][n] != null) {
                solutionGrid[i][j] = solutionGrid[i][n]! - solutionGrid[0][n]!;
                break;
              }
            }
          }
        } else {
          if (solutionGrid[i][j] == null) {
            if (solutionGrid[i][0] != null && solutionGrid[0][j] != null) {
              final result = solutionGrid[i][0]! + solutionGrid[0][j]!;
              solutionGrid[i][j] = _staticSafeResult(result, hardMode);
            }
          }
        }
      }
    }
  }

  static void _solveSubtraction1(
      List<List<double?>> solutionGrid, int gridSize) {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (i == 0 && (j >= 1 && j < gridSize)) {
          if (solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (solutionGrid[n][i] != null && solutionGrid[n][j] != null) {
                solutionGrid[i][j] = (solutionGrid[n][i]! + solutionGrid[n][j]!);
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (solutionGrid[i][n] != null && solutionGrid[0][n] != null) {
                solutionGrid[i][j] = (solutionGrid[0][n]! + solutionGrid[i][n]!);
                break;
              }
            }
          }
        } else {
          if (solutionGrid[i][j] == null) {
            if (solutionGrid[i][0] != null && solutionGrid[0][j] != null) {
              solutionGrid[i][j] =
                  (solutionGrid[i][0]! - solutionGrid[0][j]!).abs();
            }
          }
        }
      }
    }
  }

  static void solvingBoardStatic(List<List<double?>> solutionGrid, int gridSize,
      PuzzleOperation operation, bool hardMode) {
    solvingBoard1Static(solutionGrid, gridSize, operation, hardMode);
  }

  static bool checkConditionStatic(
      int i, int j, List<List<double?>> solutionGrid, int gridSize) {
    if (i == 0) {
      if (solutionGrid[i][j] == null) {
        for (int n = 1; n < gridSize; n++) {
          if (solutionGrid[n][i] == null || solutionGrid[n][j] == null) {
            return true;
          }
        }
      }
    } else if (j == 0) {
      if (solutionGrid[i][j] == null) {
        for (int n = 1; n < gridSize; n++) {
          if (solutionGrid[n][i] == null || solutionGrid[n][j] == null) {
            return true;
          }
        }
      }
    } else {
      if (solutionGrid[i][j] == null) {
        if (solutionGrid[i][0] == null || solutionGrid[0][j] == null) {
          return true;
        }
      }
    }
    return false;
  }

  static bool checkBoardSolvableStatic(
      List<List<double?>> solutionGrid, int gridSize) {
    int zeroCount = 0;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (solutionGrid[i][j] == null) {
          zeroCount++;
        }
      }
    }
    return zeroCount == 0; // Solvable if no nulls
  }

  static Map<String, dynamic> generateBoardData({
    required int gridSize,
    required bool useDecimals,
    required bool hardMode,
    required PuzzleOperation operation,
  }) {
    List<List<double?>> grid =
        List.generate(gridSize, (_) => List.filled(gridSize, null));
    List<List<double?>> solutionGrid =
        List.generate(gridSize, (_) => List.filled(gridSize, null));
    List<List<bool>> isFixed =
        List.generate(gridSize, (_) => List.filled(gridSize, false));
    List<List<bool>> isWrong =
        List.generate(gridSize, (_) => List.filled(gridSize, false));

    final random = Random();

    grid[0][0] = -1;
    solutionGrid[0][0] = -1;
    isFixed[0][0] = true;

    _createBoardStatic(
        random: random,
        grid: grid,
        solutionGrid: solutionGrid,
        isFixed: isFixed,
        gridSize: gridSize,
        useDecimals: useDecimals,
        hardMode: hardMode,
        operation: operation);

    return {
      'grid': grid,
      'solutionGrid': solutionGrid,
      'isFixed': isFixed,
      'isWrong': isWrong,
    };
  }

  static void _createBoardStatic(
      {required Random random,
      required List<List<double?>> grid,
      required List<List<double?>> solutionGrid,
      required List<List<bool>> isFixed,
      required int gridSize,
      required bool useDecimals,
      required bool hardMode,
      required PuzzleOperation operation,
      int maxAttempts = 25}) {
    
    int attempts = 0;
    bool success = false;

    while (!success && attempts < maxAttempts) {
        attempts++;
        _clearBoardStatic(grid, solutionGrid, isFixed);
        
        try {
            List<int> availableRows = List.generate(gridSize, (i) => i);
            List<int> availableCols = List.generate(gridSize, (i) => i);

            int seedNumbers = 0;

            for (int i = 0; i < gridSize; i++) {
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

                solutionGrid[randomRow][randomCol] = _randomNumberNotInRowCol(randomRow,
                    randomCol, random, solutionGrid, gridSize, useDecimals, hardMode);
                grid[randomRow][randomCol] = solutionGrid[randomRow][randomCol];
                isFixed[randomRow][randomCol] = true;

                seedNumbers++;
                availableRows.remove(randomRow);
                availableCols.remove(randomCol);
            }

            // Initial solving pass
            solvingBoard1Static(solutionGrid, gridSize, operation, hardMode);

            // Add additional seeds
            _addAdditionalSeedsStatic(random, grid, solutionGrid,
                isFixed, gridSize, seedNumbers, operation, useDecimals, hardMode);

            // Final solving ripple
            for (int n = 0; n < gridSize * 5; n++) {
                solvingBoardStatic(solutionGrid, gridSize, operation, hardMode);
            }

            if (checkBoardSolvableStatic(solutionGrid, gridSize)) {
                // Success - hide non-fixed
                for (int i = 0; i < gridSize; i++) {
                    for (int j = 0; j < gridSize; j++) {
                        if (!isFixed[i][j]) {
                            grid[i][j] = null;
                        }
                    }
                }
                success = true;
            }
        } catch (e) {
            // retry
        }
    }
  }

  static void _clearBoardStatic(List<List<double?>> grid,
      List<List<double?>> solutionGrid, List<List<bool>> isFixed) {
    final gridSize = grid.length;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        grid[i][j] = null;
        solutionGrid[i][j] = null;
        isFixed[i][j] = false;
      }
    }
    grid[0][0] = -1;
    solutionGrid[0][0] = -1;
    isFixed[0][0] = true;
  }

  static int _addAdditionalSeedsStatic(
      Random random,
      List<List<double?>> grid,
      List<List<double?>> solutionGrid,
      List<List<bool>> isFixed,
      int gridSize,
      int seedNumbers,
      PuzzleOperation operation,
      bool useDecimals,
      bool hardMode) {
    
    int target = (gridSize * 2) - 2;
    int localAttempts = 0;

    while (seedNumbers < target && localAttempts < 100) {
        localAttempts++;
        int r = random.nextInt(gridSize);
        int c = random.nextInt(gridSize);

        if (r != 0 && c != 0 && solutionGrid[r][c] == null &&
            checkConditionStatic(r, c, solutionGrid, gridSize)) {
            solutionGrid[r][c] = generateRandomNumber(random, useDecimals, hardMode, gridSize);
            grid[r][c] = solutionGrid[r][c];
            isFixed[r][c] = true;
            seedNumbers++;
            for (int n = 0; n < 10; n++) {
                solvingBoardStatic(solutionGrid, gridSize, operation, hardMode);
            }
        }
    }
    return seedNumbers;
  }
}

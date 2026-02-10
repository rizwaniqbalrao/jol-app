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
    return (value * 10).round() / 10.0;
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
                solutionGrid[i][j] = ((solutionGrid[n][i]! + solutionGrid[n][j]!) * 10).round() / 10.0;
                break;
              }
            }
          }
        } else if ((i >= 1 && i < gridSize) && j == 0) {
          if (solutionGrid[i][j] == null) {
            for (int n = 1; n < gridSize; n++) {
              if (solutionGrid[i][n] != null && solutionGrid[0][n] != null) {
                solutionGrid[i][j] =
                    ((solutionGrid[0][n]! + solutionGrid[i][n]!) * 10).round() /
                        10.0;
                break;
              }
            }
          }
        } else {
          if (solutionGrid[i][j] == null) {
            if (solutionGrid[i][0] != null && solutionGrid[0][j] != null) {
              solutionGrid[i][j] =
                  (((solutionGrid[i][0]! - solutionGrid[0][j]!).abs()) * 10).round() / 10.0;
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
      int maxAttempts = 100}) {
    
    int attempts = 0;
    bool success = false;

    while (!success && attempts < maxAttempts) {
        attempts++;
        _clearBoardStatic(grid, solutionGrid, isFixed);
        
        try {
            // 1. GENERATE CONSISTENT SOLUTION
            // Fill Headers first to ensure consistency
            // Row Headers [1][0] to [size-1][0]
            for (int i = 1; i < gridSize; i++) {
                solutionGrid[i][0] = _randomNumberNotInRowCol(i, 0, random, solutionGrid, gridSize, useDecimals, hardMode);
            }
            // Col Headers [0][1] to [0][size-1]
            for (int j = 1; j < gridSize; j++) {
                solutionGrid[0][j] = _randomNumberNotInRowCol(0, j, random, solutionGrid, gridSize, useDecimals, hardMode);
            }

            // Compute Body Cells based on Headers
            for (int i = 1; i < gridSize; i++) {
                for (int j = 1; j < gridSize; j++) {
                    double? val;
                    if (operation == PuzzleOperation.addition) {
                         if (solutionGrid[i][0] != null && solutionGrid[0][j] != null) {
                             val = solutionGrid[i][0]! + solutionGrid[0][j]!;
                         }
                    } else { // Subtraction
                         if (solutionGrid[i][0] != null && solutionGrid[0][j] != null) {
                             val = (solutionGrid[i][0]! - solutionGrid[0][j]!).abs();
                         }
                    }
                    solutionGrid[i][j] = val != null ? _staticSafeResult(val, hardMode) : null;
                }
            }

            // 2. CHECK IF SOLUTION IS VALID (No nulls, values in range)
            bool solutionValid = true;
            for(int i=0; i<gridSize; i++) {
                for(int j=0; j<gridSize; j++) {
                    if (i==0 && j==0) continue;
                    if (solutionGrid[i][j] == null) {
                        solutionValid = false; 
                        break;
                    }
                }
            }
            if (!solutionValid) continue;

            // 3. PICK CLUES (isFixed)
            // Create a temporary grid for solvability check
            List<List<double?>> testGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
            testGrid[0][0] = -1;
            
            int cluesToPick = gridSize; // Start with gridSize number of clues
            List<Point<int>> allCoords = [];
            for(int i=0; i<gridSize; i++) {
                for(int j=0; j<gridSize; j++) {
                    if (i==0 && j==0) continue;
                    allCoords.add(Point(i, j));
                }
            }
            allCoords.shuffle(random);

            // Pick initial set of clues
            for(int k=0; k<cluesToPick && k<allCoords.length; k++) {
                Point<int> p = allCoords[k];
                testGrid[p.x][p.y] = solutionGrid[p.x][p.y];
                isFixed[p.x][p.y] = true;
                grid[p.x][p.y] = solutionGrid[p.x][p.y];
            }

            // 4. CHECK SOLVABILITY
            // Try to solve testGrid using deductive logic
            solvingBoardStatic(testGrid, gridSize, operation, hardMode);
            // Repeatedly solve...
             for (int n = 0; n < gridSize * 2; n++) {
                solvingBoardStatic(testGrid, gridSize, operation, hardMode);
            }

            if (checkBoardSolvableStatic(testGrid, gridSize)) {
                success = true;
            } else {
                // Not solvable with these clues? Add more clues until solvable or give up
                // Current approach: simple retry with new board. 
                // Alternatively: Add more seeds.
                _addAdditionalSeedsStatic(random, grid, solutionGrid, isFixed, gridSize, cluesToPick, operation, useDecimals, hardMode);
                 
                 // Re-check solvability on testGrid (which needs updates from new seeds)
                 // Re-sync testGrid with new isFixed
                 for(int i=0; i<gridSize; i++) {
                    for(int j=0; j<gridSize; j++) {
                        if (isFixed[i][j]) {
                             testGrid[i][j] = solutionGrid[i][j];
                        }
                    }
                 }
                 for (int n = 0; n < gridSize * 5; n++) {
                    solvingBoardStatic(testGrid, gridSize, operation, hardMode);
                 }
                 
                 if (checkBoardSolvableStatic(testGrid, gridSize)) {
                     success = true;
                 }
            }

            if (success) {
                 // Final cleanup: Hide non-fixed cells in player 'grid'
                 for (int i = 0; i < gridSize; i++) {
                    for (int j = 0; j < gridSize; j++) {
                        if (!isFixed[i][j]) {
                            grid[i][j] = null;
                        } else {
                            grid[i][j] = solutionGrid[i][j];
                        }
                    }
                }
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

        if (r != 0 && c != 0 && !isFixed[r][c]) {
           // If solutionGrid has value, reveal it. If not (shouldn't happen), generate one.
           if (solutionGrid[r][c] != null) {
              grid[r][c] = solutionGrid[r][c];
              isFixed[r][c] = true;
              seedNumbers++;
           } else {
               // Fallback if solutionGrid had nulls (unlikely in new logic)
              final rawVal =
                  generateRandomNumber(random, useDecimals, hardMode, gridSize);
              solutionGrid[r][c] = (rawVal * 10).round() / 10.0;
              grid[r][c] = solutionGrid[r][c];
              isFixed[r][c] = true;
              seedNumbers++;
           }
        }
    }
    return seedNumbers;
  }
}

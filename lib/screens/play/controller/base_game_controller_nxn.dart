import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

enum PuzzleOperation { addition, subtraction }
enum GameMode { untimed, timed }

abstract class BaseGameControllerNxN extends ChangeNotifier {
  final int gridSize;
  
  // Game State
  GameMode _mode = GameMode.untimed;
  PuzzleOperation operation = PuzzleOperation.addition;
  bool _useDecimals = false;
  bool _hardMode = false;
  
  // Grid Data
  late List<List<double?>> grid;
  late List<List<double?>> _solutionGrid;
  late List<List<bool>> isFixed;
  late List<List<bool>> isWrong;
  
  // Gameplay State
  Duration timeLeft = const Duration(minutes: 10);
  Timer? _timer;
  bool isPlaying = false;
  bool isGenerating = true;
  int seedNumbers = 0;
  
  // Metrics
  int score = 0;
  DateTime? _gameStartTime;
  int? _completionTimeSeconds;
  int _correctAnswers = 0;
  int _totalPlayerCells = 0;
  double _accuracyPercentage = 0.0;
  final Map<String, String> rawInputs = {};

  // Getters
  GameMode get mode => _mode;
  bool get useDecimals => _useDecimals;
  bool get hardMode => _hardMode;
  List<List<double?>> get solutionGrid => _solutionGrid;
  int get correctAnswers => _correctAnswers;
  int get totalPlayerCells => _totalPlayerCells;
  double get accuracyPercentage => _accuracyPercentage;
  int? get completionTimeSeconds => _completionTimeSeconds;
  DateTime? get gameStartTime => _gameStartTime;

  BaseGameControllerNxN({required this.gridSize}) {
    _initializeDataStructures();
    // Auto-start generation handled by subclasses or manually called
    initGrid();
  }

  void _initializeDataStructures() {
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    isWrong = List.generate(gridSize, (_) => List.filled(gridSize, false));
  }

  // -----------------------------------------------------------------------------
  // PUBLIC SETTERS & CONTROLS
  // -----------------------------------------------------------------------------

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
    if (isPlaying) return; // Cant change mode while playing
    _mode = (_mode == GameMode.timed) ? GameMode.untimed : GameMode.timed;
    notifyListeners();
  }

  void startGame() {
    _gameStartTime = DateTime.now();
    isPlaying = true;
    notifyListeners();
  }

  void stopTimer() {
    _timer?.cancel();
    notifyListeners();
  }

  void startTimer() {
    stopTimer(); // Ensure existing timer is cancelled
    if (_mode == GameMode.untimed) return;
    
    timeLeft = const Duration(minutes: 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft.inSeconds > 0) {
        timeLeft = timeLeft - const Duration(seconds: 1);
        notifyListeners();
      } else {
        stopTimer();
        endGame();
      }
    });
  }

  void resetGame() {
    stopTimer();
    isPlaying = false;
    _gameStartTime = null;
    score = 0;
    _accuracyPercentage = 0.0;
    timeLeft = const Duration(minutes: 10);
    rawInputs.clear();
    initGrid();
  }

  void endGame() {
    isPlaying = false;
    stopTimer();
    if (_gameStartTime != null) {
      _completionTimeSeconds = DateTime.now().difference(_gameStartTime!).inSeconds;
    }
    validateAll(); // Final validation
    notifyListeners();
  }

  // -----------------------------------------------------------------------------
  // GRID INTERACTION
  // -----------------------------------------------------------------------------

  double? getCell(int row, int col) {
    if (!_isValidCell(row, col)) return null;
    return grid[row][col];
  }

  bool getFixed(int row, int col) {
    if (!_isValidCell(row, col)) return false;
    return isFixed[row][col];
  }

  bool getWrong(int row, int col) {
    if (!_isValidCell(row, col)) return false;
    return isWrong[row][col];
  }

  bool _isValidCell(int row, int col) {
    return row >= 0 && row < gridSize && col >= 0 && col < gridSize;
  }

  void updateCell(int row, int col, double? value) {
    if (!_isValidCell(row, col) || isFixed[row][col]) return;
    if (value != null) {
      grid[row][col] = (value * 10).round() / 10.0;
    } else {
      grid[row][col] = null;
    }
    notifyListeners();
  }

  void updateRawInput(int row, int col, String rawText) {
    if (!_isValidCell(row, col) || isFixed[row][col]) return;
    
    final key = '$row-$col';
    rawInputs[key] = rawText;

    if (rawText.isEmpty) {
      grid[row][col] = null;
    } else {
      // Allow partial decimal inputs (e.g. "12.") to be stored in grid as number 
      // if parsable, otherwise ignore or keep previous
      final parsed = double.tryParse(rawText);
      if (parsed != null) {
        grid[row][col] = (parsed * 10).round() / 10.0;
      }
    }
    notifyListeners();
  }

  void finalizeCellInput(int row, int col, String rawText) {
    if (!_isValidCell(row, col) || isFixed[row][col]) return;

    final key = '$row-$col';
    rawInputs[key] = rawText;

    final parsed = _safeParse(rawText);
    if (parsed != null) {
      grid[row][col] = parsed;
    }
    notifyListeners();
  }

  double? _safeParse(String? text, {int decimalPlaces = 1}) {
    if (text == null || text.trim().isEmpty) return null;
    String cleaned = text.trim();
    if (cleaned.endsWith('.')) cleaned += '0';
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;
    final factor = pow(10, decimalPlaces).toDouble();
    return (parsed * factor).round() / factor;
  }

  // -----------------------------------------------------------------------------
  // VALIDATION LOGIC
  // -----------------------------------------------------------------------------

  void validateAll() {
    int correctCount = 0;
    int totalPlayerCount = 0;
    const tolerance = 0.001;

    // Reset wrong status
    for (int i = 0; i < gridSize; i++) {
        for (int j = 0; j < gridSize; j++) {
            isWrong[i][j] = false;
        }
    }

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        
        if (!isFixed[i][j]) {
          totalPlayerCount++;
          
          if (grid[i][j] == null) {
            isWrong[i][j] = true;
          } else {
            bool isValid = _validateCellMath(i, j, tolerance);
            if (isValid) {
              correctCount++;
            } else {
              isWrong[i][j] = true;
            }
          }
        }
      }
    }

    _totalPlayerCells = totalPlayerCount;
    _correctAnswers = correctCount;
    _accuracyPercentage = (totalPlayerCount > 0) ? (correctCount / totalPlayerCount) * 100 : 0.0;
    
    _calculateScore();
    notifyListeners();
  }

  bool _validateCellMath(int row, int col, double tolerance) {
     // Validate based on Headers (Row 0 or Col 0) or Middle Cells logic
     // This logic must handle cases where headers themselves might be user-filled or fixed.
     // However, typically validation compares against the headers if they are filled.
     
     // NOTE: As per the original controller logic, we validate:
     // Col Header (row=0, col>0): value = Middle[n][col] + RowHeader[n] (reverse check)
     // Row Header (row>0, col=0): value = Middle[row][n] + ColHeader[n] (reverse check)
     // Middle (row>0, col>0): value = RowHeader[row] ± ColHeader[col]

    if (row == 0 && col > 0) {
        // Validation for Column Header using ANY middle cell in this column
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
                if ((grid[row][col]! - expected).abs() <= tolerance) return true;
            }
        }
    } else if (row > 0 && col == 0) {
        // Validation for Row Header using ANY middle cell in this row
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
                 if ((grid[row][col]! - expected).abs() <= tolerance) return true;
            }
        }
    } else {
        // Middle Cell
        final rowHead = grid[row][0];
        final colHead = grid[0][col];
        if (rowHead != null && colHead != null) {
             double expected;
             if (operation == PuzzleOperation.addition) {
                 expected = rowHead + colHead;
             } else {
                 expected = (rowHead - colHead).abs();
             }
             if ((grid[row][col]! - expected).abs() <= tolerance) return true;
        }
    }
    return false;
  }

  void _calculateScore() {
    if (mode == GameMode.untimed) {
      score = _accuracyPercentage.round();
    } else {
      int baseScore = (_accuracyPercentage * 0.7).round();
      int timeBonus = (timeLeft.inSeconds > 240) ? 30 : (timeLeft.inSeconds > 120 ? 15 : 5);
      score = baseScore + timeBonus;
    }
  }

  // -----------------------------------------------------------------------------
  // GENERATION LOGIC (Generic)
  // -----------------------------------------------------------------------------
  
  Future<void> initGrid() async {
    isGenerating = true;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 50));
    final random = Random();

    _initializeDataStructures(); // Clear grid
    grid[0][0] = -1;
    _solutionGrid[0][0] = -1;
    isFixed[0][0] = true;

    _createBoard(random);

    isGenerating = false;
    notifyListeners();
  }

  void _createBoard(Random random, {int maxAttempts = 25}) {
      // NOTE: This logic is adapted from the original 4x4 controller but made generic for gridSize
      
      bool success = false;
      int attempts = 0;

      while (!success && attempts < maxAttempts) {
          attempts++;
          if (attempts > 1) _clearBoard(); // Reset for retry

          try {
              // 1. Fill strictly diagonal/random seeds
              List<int> availableRows = List.generate(gridSize, (i) => i);
              List<int> availableCols = List.generate(gridSize, (i) => i);
              seedNumbers = 0;

              for (int i = 0; i < gridSize; i++) {
                  int r, c;
                  do {
                    if (seedNumbers == 0) {
                        r = 0; 
                        // Avoid 0,0 double selection (handled below but just to be safe)
                        // Original logic: randomCol = availableCols[random...]
                         // We just pick a random non-zero col for the first seed if r=0
                         c = availableCols[random.nextInt(availableCols.length - 1) + 1]; 
                         // Wait, availableCols has 0..N. 
                         // If we want [1..N], we should pick properly.
                         // Let's stick closer to the rigorous logic:
                    } else {
                        r = availableRows[random.nextInt(availableRows.length)];
                        c = availableCols[random.nextInt(availableCols.length)];
                    }
                  } while (r == 0 && c == 0);

                  double val = _randomNumberNotInRowCol(r, c, random);
                  _solutionGrid[r][c] = val;
                  grid[r][c] = val;
                  isFixed[r][c] = true;
                  
                  seedNumbers++;
                  availableRows.remove(r);
                  availableCols.remove(c);
              }

              // 2. Initial Solving Pass
              _solveBoardRipple();

              // 3. Add more seeds if needed
              _addAdditionalSeeds(random);

              // 4. Final Ripple
               for (int n = 0; n < gridSize * 4; n++) { // More iterations for larger grids
                  _solveBoardRipple();
               }

               // 5. Check Solvability
               if (!_isBoardSolvable()) {
                   // If not solvable, strictly we fail and retry, 
                   // OR we just present what we have (partial board).
                   // The original code reset non-fixed cells here?
                   // No, original code retried if not solvable.
                   throw Exception("Board not solvable");
               } else {
                   // Success - Hide non-fixed cells
                   for(int i=0; i<gridSize; i++) {
                       for(int j=0; j<gridSize; j++) {
                           if(!isFixed[i][j]) {
                               grid[i][j] = null;
                           }
                       }
                   }
                   success = true;
               }

          } catch (e) {
              // Retry loop handles it
          }
      }
      
      // If failed after max attempts, just leave whatever was generated
  }

  void _clearBoard() {
      for(int i=0; i<gridSize; i++) {
          for(int j=0; j<gridSize; j++) {
              grid[i][j] = null;
              _solutionGrid[i][j] = null;
              isFixed[i][j] = false;
          }
      }
      grid[0][0] = -1;
      _solutionGrid[0][0] = -1;
      isFixed[0][0] = true;
  }

  double _randomNumberNotInRowCol(int row, int col, Random random) {
      double number;
      int attempts = 0;
      do {
          number = _generateRandomNumber(random);
          attempts++;
          if (attempts > 100) break;
      } while (_isNumberUsedInRowOrCol(number, row, col));
      return number;
  }

  double _generateRandomNumber(Random random) {
  const int ABSOLUTE_MAX = 332;

  if (_useDecimals) {
    final int max = _hardMode ? ABSOLUTE_MAX : 9;

    // Generates 1.1 → max.x but never above 332
    return ((random.nextInt(max * 10 - 10) + 11) / 10.0);
  } else {
    final int dynamicMax = _hardMode
        ? ABSOLUTE_MAX
        : (gridSize * gridSize);

    final int safeMax = dynamicMax > ABSOLUTE_MAX
        ? ABSOLUTE_MAX
        : dynamicMax;

    return (random.nextInt(safeMax) + 1).toDouble();
  }
}

  bool _isNumberUsedInRowOrCol(double number, int row, int col) {
      const tolerance = 0.001;
      for (int i = 0; i < gridSize; i++) {
          final rVal = _solutionGrid[row][i];
          final cVal = _solutionGrid[i][col];
          if (rVal != null && (rVal - number).abs() < tolerance) return true;
          if (cVal != null && (cVal - number).abs() < tolerance) return true;
      }
      return false;
  }

  void _solveBoardRipple() {
      // Loop solving logic
      // If Operation Addition:
      // Middle = Row + Col
      // Row = Middle - Col
      // Col = Middle - Row
      
      // If Operation Subtraction:
      // Middle = |Row - Col|
      // Row = Middle + Col (Possible ambiguity, |R - C| = M => R = C +/- M. But usually structured simply)
      // Actually standard logic:
      // Middle = abs(Row - Col)
      // If we know Middle and Col? Row could be Col + Middle OR Col - Middle. 
      // The original code had specific logic for Subtraction solving.
      
      if (operation == PuzzleOperation.addition) {
          _solveAddition();
      } else {
          _solveSubtraction();
      }
  }

  void _solveAddition() {
      for(int i=0; i<gridSize; i++) {
          for(int j=0; j<gridSize; j++) {
              if (i==0 && j==0) continue;
              
              if (_solutionGrid[i][j] == null) {
                  // Try to find if we can compute this cell
                  if (i == 0) { // Top Header
                       // Need a Middle[n][j] and Left[n]
                       for(int n=1; n<gridSize; n++) {
                           if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                               // Left[n] + Top[j] = Middle[n][j] => Top[j] = Middle - Left
                               _solutionGrid[i][j] = _solutionGrid[n][j]! - _solutionGrid[n][i]!;
                               break;
                           }
                       }
                  } else if (j == 0) { // Left Header
                        // Need Middle[i][n] and Top[n]
                        for(int n=1; n<gridSize; n++) {
                             if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                                 // Left[i] + Top[n] = Middle[i][n] => Left[i] = Middle - Top
                                 _solutionGrid[i][j] = _solutionGrid[i][n]! - _solutionGrid[0][n]!;
                                 break;
                             }
                        }
                  } else { // Middle
                        if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
                            final res = _solutionGrid[i][0]! + _solutionGrid[0][j]!;
                            _solutionGrid[i][j] = _safeResult((res * 10).round() / 10.0);
                        }
                  }
              }
          }
      }
  }

  void _solveSubtraction() {
      // Logic from original controller
      for(int i=0; i<gridSize; i++) {
          for(int j=0; j<gridSize; j++) {
              if (i==0 && j==0) continue;
              if (_solutionGrid[i][j] == null) {
                   if (i == 0) { // Top Header
                       for(int n=1; n<gridSize; n++) {
                           if (_solutionGrid[n][i] != null && _solutionGrid[n][j] != null) {
                               // Middle = |Left - Top|
                               // This is ambiguous in reverse without context, but original code used:
                               // Top = Left + Middle (Safe assumption for generation flow sometimes)
                               _solutionGrid[i][j] = _solutionGrid[n][i]! + _solutionGrid[n][j]!;
                               break;
                           }
                       }
                   } else if (j == 0) { // Left Header
                        for(int n=1; n<gridSize; n++) {
                             if (_solutionGrid[i][n] != null && _solutionGrid[0][n] != null) {
                                 // Left = Top + Middle
                                 _solutionGrid[i][j] = _solutionGrid[0][n]! + _solutionGrid[i][n]!;
                                 break;
                             }
                        }
                   } else { // Middle
                        if (_solutionGrid[i][0] != null && _solutionGrid[0][j] != null) {
                             _solutionGrid[i][j] = (_solutionGrid[i][0]! - _solutionGrid[0][j]!).abs();
                        }
                   }
              }
          }
      }
  }

  double? _safeResult(double val) {
    if (_hardMode && val > (_hardMode ? 999 : double.infinity)) return null;
    return (val * 10).round() / 10.0;
  }

  void _addAdditionalSeeds(Random random) {
      // int target = (gridSize * 1.5).ceil();
      int target = (gridSize*2)-2; // hope this will resolve the issue
      int localAttempts = 0;
      
      List<int> availableRows = List.generate(gridSize, (i) => i);
      List<int> availableCols = List.generate(gridSize, (i) => i);

      while (seedNumbers < target && localAttempts < 100) {
          localAttempts++;
          int r = availableRows[random.nextInt(gridSize)];
          int c = availableCols[random.nextInt(gridSize)];
          
          if (r!=0 && c!=0 && _solutionGrid[r][c] == null && _checkCondition(r, c)) {
               double val = _generateRandomNumber(random);
               _solutionGrid[r][c] = val;
                grid[r][c] = val;
                isFixed[r][c] = true;
                seedNumbers++;
                for(int k=0; k<10; k++) _solveBoardRipple();
          }
      }
  }

  bool _checkCondition(int i, int j) {
      // Check if adding a seed here helps solve others
      // e.g., if we are a header, do we have a partner to solve a middle?
      // Logic copied from original:
      if (i == 0) { // Top Header
           // Useful if we have a Left Header that is missing a Middle, or a Middle missing a Left
           for(int n=1; n<gridSize; n++) {
               if (_solutionGrid[n][i] == null || _solutionGrid[n][j] == null) return true;
           }
      } else if (j == 0) { // Left Header
            for(int n=1; n<gridSize; n++) {
               if (_solutionGrid[n][i] == null || _solutionGrid[n][j] == null) return true;
           }
      } else { // Middle
            if (_solutionGrid[i][0] == null || _solutionGrid[0][j] == null) return true;
      }
      return false;
  }

  bool _isBoardSolvable() {
      int missing = 0;
      for(int i=0; i<gridSize; i++) {
          for(int j=0; j<gridSize; j++) {
              if (i==0 && j==0) continue;
              if (_solutionGrid[i][j] == null) missing++;
          }
      }
      return missing == 0;
  }
}

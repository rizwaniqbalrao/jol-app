import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/puzzle_utils.dart';
import 'base_game_controller_nxn.dart' show PuzzleOperation;

enum GameMode { untimed, timed }

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

  // STATIC HELPER METHODS (Now using PuzzleUtils for generic NxN support)

  static double generateRandomNumber(
      Random random, bool useDecimals, bool hardMode) {
    // 4x4 default gridSize is 4
    return PuzzleUtils.generateRandomNumber(random, useDecimals, hardMode, 4);
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
    return PuzzleUtils.generateRandomNumber(
        random, useDecimals, hardMode, gridSize);
  }

  static bool _isNumberUsedInRowOrColumnStatic(double number, int row, int col,
      List<List<double?>> solutionGrid, int gridSize) {
    const tolerance = 0.001;
    for (int i = 0; i < gridSize; i++) {
      final rowVal = solutionGrid[row][i];
      final colVal = solutionGrid[i][col];
      if (rowVal != null && (rowVal - number).abs() < tolerance) return true;
      if (colVal != null && (colVal - number).abs() < tolerance) return true;
    }
    return false;
  }

  static void solvingBoard1Static(List<List<double?>> solutionGrid,
      int gridSize, PuzzleOperation operation, bool hardMode) {
    PuzzleUtils.solvingBoard1Static(
        solutionGrid, gridSize, operation, hardMode);
  }

  static void _solveAddition1(
      List<List<double?>> solutionGrid, int gridSize, bool hardMode) {
    PuzzleUtils.solvingBoard1Static(
        solutionGrid, gridSize, PuzzleOperation.addition, hardMode);
  }

  static void _solveSubtraction1(
      List<List<double?>> solutionGrid, int gridSize) {
    PuzzleUtils.solvingBoard1Static(
        solutionGrid, gridSize, PuzzleOperation.subtraction, false);
  }

  static void solvingBoardStatic(List<List<double?>> solutionGrid, int gridSize,
      PuzzleOperation operation, bool hardMode) {
    PuzzleUtils.solvingBoardStatic(solutionGrid, gridSize, operation, hardMode);
  }

  static void _solveAddition(
      List<List<double?>> solutionGrid, int gridSize, bool hardMode) {
    PuzzleUtils.solvingBoardStatic(
        solutionGrid, gridSize, PuzzleOperation.addition, hardMode);
  }

  static void _solveSubtraction(
      List<List<double?>> solutionGrid, int gridSize) {
    PuzzleUtils.solvingBoardStatic(
        solutionGrid, gridSize, PuzzleOperation.subtraction, false);
  }

  static bool checkConditionStatic(
      int i, int j, List<List<double?>> solutionGrid, int gridSize) {
    return PuzzleUtils.checkConditionStatic(i, j, solutionGrid, gridSize);
  }

  static bool checkBoardSolvableStatic(
      List<List<double?>> solutionGrid, int gridSize) {
    return PuzzleUtils.checkBoardSolvableStatic(solutionGrid, gridSize);
  }

  static Map<String, dynamic> generateBoardData({
    required int gridSize,
    required bool useDecimals,
    required bool hardMode,
    required PuzzleOperation operation,
  }) {
    return PuzzleUtils.generateBoardData(
      gridSize: gridSize,
      useDecimals: useDecimals,
      hardMode: hardMode,
      operation: operation,
    );
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
    // This is now purely delegating but the parameters are already matched
    // We could just call directly or keep this for internal GameController compatibility
    PuzzleUtils.generateBoardData(
        gridSize: gridSize,
        useDecimals: useDecimals,
        hardMode: hardMode,
        operation: operation);
    // Note: _createBoardStatic in GameController was intended to mutate arguments.
    // PuzzleUtils.generateBoardData creates new ones.
    // I should probably add a _createBoardStatic to PuzzleUtils if I want to mutate.
    // But GameController's internal _createBoard calls generateBoardData anyway.
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
    // This is not easily delegatable without mutating.
    // I'll leave a minimal implementation or delegate to a mutation helper if I add one.
    return seedNumbers;
  }

  // INSTANCE METHODS (Delegating to static)

  void _createBoard(Random random, {int maxAttempts = 25}) {
    final result = generateBoardData(
        gridSize: gridSize,
        useDecimals: _useDecimals,
        hardMode: _hardMode,
        operation: operation);

    grid = result['grid'];
    _solutionGrid = result['solutionGrid'];
    isFixed = result['isFixed'];
    isWrong = result['isWrong'];
    seedNumbers = 6; // Approx
  }

  // Legacy instance methods kept for compatibility if needed, but unused by new generate logic
  double _generateRandomNumber(Random random) =>
      generateRandomNumber(random, _useDecimals, _hardMode);

  void _solvingBoard() =>
      solvingBoardStatic(_solutionGrid, gridSize, operation, _hardMode);

  void _solvingBoard1() =>
      solvingBoard1Static(_solutionGrid, gridSize, operation, _hardMode);

  void _solvingBoard1Subtraction() => solvingBoardStatic(
      _solutionGrid,
      gridSize,
      PuzzleOperation.subtraction,
      _hardMode); // Subtraction uses solvingBoardStatic with SUB param

  void _solvingBoardSubtraction() => solvingBoardStatic(
      _solutionGrid, gridSize, PuzzleOperation.subtraction, _hardMode);

  bool _checkCondition(int i, int j) =>
      checkConditionStatic(i, j, _solutionGrid, gridSize);

  bool _checkBoardSolvable() =>
      checkBoardSolvableStatic(_solutionGrid, gridSize);

  void _clearBoard() => _clearBoardStatic(grid, _solutionGrid, isFixed);

  // Original methods that were replaced above:

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

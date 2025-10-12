import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

class GameController extends ChangeNotifier {
  int gridSize;
  late List<List<int?>> grid; // visible cells (null = empty)
  late List<List<int?>> _solutionGrid; // full solution
  late List<List<bool>> isFixed; // prefilled clues
  late List<List<int>> _relationshipRules; // 0=A+B=C, 1=B+C=A, 2=A+C=B
  int score = 0;
  Duration timeLeft = const Duration(minutes: 5);
  Timer? _timer;
  bool isPlaying = false;

  GameController({this.gridSize = 4}) {
    _initGrid();
    startTimer();
  }

  // ──────────────────────────────────────────────
  // INITIALIZATION
  // ──────────────────────────────────────────────
  void _initGrid() {
    final random = Random();
    // Initialize empty structures
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    _solutionGrid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    isFixed = List.generate(gridSize, (_) => List.filled(gridSize, false));
    _relationshipRules = List.generate(gridSize, (_) => List.filled(gridSize, 0));

    // Reference cell (top-left) - always fixed
    grid[0][0] = -1;
    _solutionGrid[0][0] = -1;
    isFixed[0][0] = true;
    _relationshipRules[0][0] = -1;

    // Generate a solvable puzzle
    _generateSolvablePuzzle(random);
    isPlaying = true;
    notifyListeners();
  }

  void _generateSolvablePuzzle(Random random) {
    const int maxAttempts = 100;
    bool success = false;
    for (int attempt = 0; attempt < maxAttempts && !success; attempt++) {
      // Step 1: Generate random headers (keep them small for better gameplay)
      for (int i = 1; i < gridSize; i++) {
        _solutionGrid[i][0] = random.nextInt(25) + 1; // A values: 1-25
      }
      for (int j = 1; j < gridSize; j++) {
        _solutionGrid[0][j] = random.nextInt(25) + 1; // B values: 1-25
      }

      // Step 2: Assign random valid rules to each intersection
      for (int i = 1; i < gridSize; i++) {
        for (int j = 1; j < gridSize; j++) {
          int a = _solutionGrid[i][0]!;
          int b = _solutionGrid[0][j]!;
          // Determine which rules are valid (result must be positive)
          List<int> validRules = [0]; // A + B = C always valid
          if (a > b) validRules.add(1); // B + C = A → C = A - B (valid if A > B)
          if (b > a) validRules.add(2); // A + C = B → C = B - A (valid if B > A)

          // Randomly choose a valid rule (prefer non-addition for variety)
          int rule;
          if (validRules.length > 1 && random.nextDouble() > 0.4) {
            rule = validRules[1 + random.nextInt(validRules.length - 1)];
          } else {
            rule = 0;
          }
          _relationshipRules[i][j] = rule;

          // Calculate the result based on the rule
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

      // Step 3: Select 6 OPERAND clues that are ALL < 10 and verify solvability
      if (_selectOperandClues(random)) {
        success = true;
      }
    }
    if (!success) {
      // Fallback: use a guaranteed-solvable pattern
      _useFallbackClues(random);
    }
  }

  bool _selectOperandClues(Random random) {
    // Clear any previous clues
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (!(i == 0 && j == 0)) {
          grid[i][j] = null;
          isFixed[i][j] = false;
        }
      }
    }

    // CRITICAL: Select 6 cells that are OPERANDS (not results) AND VALUES < 10
    final operandCandidates = <List<int>>[];

    // Add headers as operand candidates ONLY if their value < 10
    for (int i = 1; i < gridSize; i++) {
      if (_solutionGrid[i][0]! < 10) {
        operandCandidates.add([i, 0]); // Row headers (A values)
      }
    }
    for (int j = 1; j < gridSize; j++) {
      if (_solutionGrid[0][j]! < 10) {
        operandCandidates.add([0, j]); // Column headers (B values)
      }
    }

    // Add intersection cells where C is an OPERAND (rule 1 or 2) AND value < 10
    for (int i = 1; i < gridSize; i++) {
      for (int j = 1; j < gridSize; j++) {
        final rule = _relationshipRules[i][j];
        if ((rule == 1 || rule == 2) && _solutionGrid[i][j]! < 10) {
          // Rule 1: B + C = A (C is operand)
          // Rule 2: A + C = B (C is operand)
          operandCandidates.add([i, j]);
        }
      }
    }

    if (operandCandidates.length < 6) {
      return false; // Not enough operands with values < 10, retry
    }

    // NEW: First, select two disjoint obvious partial triplets (4 operands total)
    final partialTriplets = _selectTwoDisjointPartialTriplets(operandCandidates, random);
    if (partialTriplets.length != 2) {
      return false; // Couldn't find suitable hints, retry
    }

    // Extract the 4 operand positions from the two triplets
    final hintOperands = <List<int>>[];
    for (final triplet in partialTriplets) {
      hintOperands.addAll(triplet.sublist(0, 2)); // The two known operands per triplet
    }

    // Now select 2 more random operands from remaining candidates (avoiding conflicts)
    final remainingCandidates = operandCandidates
        .where((pos) => !hintOperands.any((h) => h[0] == pos[0] && h[1] == pos[1]))
        .toList();
    if (remainingCandidates.length < 2) {
      return false;
    }
    remainingCandidates.shuffle(random);
    final additionalClues = remainingCandidates.take(2).toList();

    // Combine all 6
    final selectedClues = [...hintOperands, ...additionalClues];

    // Apply these clues temporarily
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

    // Check if puzzle is solvable with these clues
    if (_isPuzzleSolvable()) {
      return true;
    }
    return false;
  }

  List<List<List<int>>> _selectTwoDisjointPartialTriplets(
      List<List<int>> operandCandidates, Random random) {
    final triplets = <List<List<int>>>[]; // Each: [known1, known2, unknown]

    // Find all possible partial triplets where exactly two operands are candidates (<10)
    final possiblePartials = <List<List<int>>>[];
    for (int i = 1; i < gridSize; i++) {
      for (int j = 1; j < gridSize; j++) {
        final rule = _relationshipRules[i][j];
        final aPos = [i, 0];
        final bPos = [0, j];
        final cPos = [i, j];

        // Check if A is operand candidate
        final aIsCandidate = operandCandidates.any((p) => p[0] == i && p[1] == 0);
        // Check if B is operand candidate
        final bIsCandidate = operandCandidates.any((p) => p[0] == 0 && p[1] == j);
        // Check if C is operand (for this rule) and candidate
        final cIsOperand = (rule == 1 || rule == 2);
        final cIsCandidate = cIsOperand &&
            operandCandidates.any((p) => p[0] == i && p[1] == j);

        // Possible pairs for obvious deduction (unique based on rule)
        if (rule == 0) {
          // Prefer A + B → C (unknown C)
          if (aIsCandidate && bIsCandidate) {
            possiblePartials.add([aPos, bPos, cPos]);
          }
        } else if (rule == 1) {
          // B + C → A (unknown A), or A + B → C but since rule=1, C operand
          if (bIsCandidate && cIsCandidate) {
            possiblePartials.add([bPos, cPos, aPos]);
          } else if (aIsCandidate && bIsCandidate) {
            // Fallback, but check if deduces correctly
            final a = _solutionGrid[i][0]!;
            final b = _solutionGrid[0][j]!;
            final expectedC = a - b;
            if (expectedC > 0) {
              possiblePartials.add([aPos, bPos, cPos]);
            }
          }
        } else if (rule == 2) {
          // A + C → B (unknown B), or A + B → C
          if (aIsCandidate && cIsCandidate) {
            possiblePartials.add([aPos, cPos, bPos]);
          } else if (aIsCandidate && bIsCandidate) {
            final a = _solutionGrid[i][0]!;
            final b = _solutionGrid[0][j]!;
            final expectedC = b - a;
            if (expectedC > 0) {
              possiblePartials.add([aPos, bPos, cPos]);
            }
          }
        }
      }
    }

    if (possiblePartials.length < 2) {
      return [];
    }

    // Shuffle and try to pick two disjoint (no shared positions)
    possiblePartials.shuffle(random);
    for (int idx1 = 0; idx1 < possiblePartials.length - 1; idx1++) {
      final t1 = possiblePartials[idx1];
      bool disjoint = true;
      for (int idx2 = idx1 + 1; idx2 < possiblePartials.length; idx2++) {
        final t2 = possiblePartials[idx2];
        // Check no shared known positions
        final shared = t1.sublist(0, 2).any((p1) => t2.sublist(0, 2).any((p2) => p1[0] == p2[0] && p1[1] == p2[1]));
        if (!shared) {
          return [t1, t2];
        }
      }
    }
    return []; // No disjoint pair found
  }

  void _useFallbackClues(Random random) {
    // Fallback: reveal headers strategically that are < 10
    final clues = <List<int>>[];

    // Add row headers that are < 10
    for (int i = 1; i < gridSize; i++) {
      if (_solutionGrid[i][0]! < 10) {
        clues.add([i, 0]);
      }
    }

    // Add column headers that are < 10
    for (int j = 1; j < gridSize; j++) {
      if (_solutionGrid[0][j]! < 10 && clues.length < 6) {
        clues.add([0, j]);
      }
    }

    // If we still need more clues, add operand intersections that are < 10
    for (int i = 1; i < gridSize && clues.length < 6; i++) {
      for (int j = 1; j < gridSize && clues.length < 6; j++) {
        final rule = _relationshipRules[i][j];
        if ((rule == 1 || rule == 2) && _solutionGrid[i][j]! < 10) {
          clues.add([i, j]);
        }
      }
    }

    // If STILL not enough, relax the <10 constraint but keep operand requirement
    if (clues.length < 6) {
      for (int i = 1; i < gridSize && clues.length < 6; i++) {
        if (!clues.any((pos) => pos[0] == i && pos[1] == 0)) {
          clues.add([i, 0]);
        }
      }
      for (int j = 1; j < gridSize && clues.length < 6; j++) {
        if (!clues.any((pos) => pos[0] == 0 && pos[1] == j)) {
          clues.add([0, j]);
        }
      }
    }

    // Apply clues
    for (final pos in clues) {
      grid[pos[0]][pos[1]] = _solutionGrid[pos[0]][pos[1]];
      isFixed[pos[0]][pos[1]] = true;
    }
  }

  bool _isPuzzleSolvable() {
    // Simulate solving the puzzle step-by-step
    final tempGrid = List.generate(
      gridSize,
          (i) => List<int?>.from(grid[i]),
    );
    bool madeProgress = true;
    int iterations = 0;
    const maxIterations = 100;
    while (madeProgress && iterations < maxIterations) {
      madeProgress = false;
      iterations++;

      // Try to deduce unknown cells from known values
      for (int i = 1; i < gridSize; i++) {
        for (int j = 1; j < gridSize; j++) {
          if (tempGrid[i][j] != null) continue;
          final a = tempGrid[i][0];
          final b = tempGrid[0][j];
          final rule = _relationshipRules[i][j];

          // Case 1: Know A and B, can deduce C
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

      // Try to deduce row headers (A values)
      for (int i = 1; i < gridSize; i++) {
        if (tempGrid[i][0] != null) continue;
        for (int j = 1; j < gridSize; j++) {
          final b = tempGrid[0][j];
          final c = tempGrid[i][j];
          final rule = _relationshipRules[i][j];
          if (b != null && c != null) {
            int? a;
            switch (rule) {
              case 0:
                a = c - b; // A + B = C → A = C - B
                break;
              case 1:
                a = b + c; // B + C = A
                break;
              case 2:
                a = b - c; // A + C = B → A = B - C
                break;
            }
            if (a != null && a > 0) {
              tempGrid[i][0] = a;
              madeProgress = true;
              break;
            }
          }
        }
      }

      // Try to deduce column headers (B values)
      for (int j = 1; j < gridSize; j++) {
        if (tempGrid[0][j] != null) continue;
        for (int i = 1; i < gridSize; i++) {
          final a = tempGrid[i][0];
          final c = tempGrid[i][j];
          final rule = _relationshipRules[i][j];
          if (a != null && c != null) {
            int? b;
            switch (rule) {
              case 0:
                b = c - a; // A + B = C → B = C - A
                break;
              case 1:
                b = a - c; // B + C = A → B = A - C
                break;
              case 2:
                b = a + c; // A + C = B
                break;
            }
            if (b != null && b > 0) {
              tempGrid[0][j] = b;
              madeProgress = true;
              break;
            }
          }
        }
      }
    }

    // Check if we solved everything
    for (int i = 1; i < gridSize; i++) {
      for (int j = 1; j < gridSize; j++) {
        if (tempGrid[i][j] == null) return false;
      }
    }
    for (int i = 1; i < gridSize; i++) {
      if (tempGrid[i][0] == null) return false;
    }
    for (int j = 1; j < gridSize; j++) {
      if (tempGrid[0][j] == null) return false;
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
    int correct = 0;
    bool isComplete = true;
    int totalCells = gridSize * gridSize - 1;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (grid[i][j] == null) {
          isComplete = false;
          continue;
        }
        // Check if the value matches the solution
        if (grid[i][j] == _solutionGrid[i][j]) {
          correct++;
        }
      }
    }
    score = correct;
    if (isComplete && correct == totalCells) {
      stopTimer();
      isPlaying = false;
      score += timeLeft.inSeconds ~/ 10;
    }
    notifyListeners();
    return isComplete && correct == totalCells;
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
    isPlaying = false;
    stopTimer();
    validateGrid();
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // TIMER
  // ──────────────────────────────────────────────
  void startTimer() {
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
    startTimer();
  }

  void changeGridSize(int newSize) {
    gridSize = newSize;
    resetGame();
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // HELPER METHODS FOR DEBUGGING/UI
  // ──────────────────────────────────────────────
  String getRuleSymbol(int row, int col) {
    if (row == 0 || col == 0) return '';
    final rule = _relationshipRules[row][col];
    switch (rule) {
      case 0:
        return '+'; // A + B = C
      case 1:
        return '−'; // B + C = A
      case 2:
        return '−'; // A + C = B
      default:
        return '+';
    }
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
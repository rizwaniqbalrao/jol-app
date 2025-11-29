import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jol_app/screens/play/submit_game_screen.dart';
import 'package:jol_app/screens/play/widgets/game_helper.dart';
import 'package:provider/provider.dart';
import 'controller/game_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);
  static const Color hintColor = Color(0xFFFF9800);

  final Map<String, TextEditingController> _inputControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _showMinus = false;
  String? _selectedCell;
  bool _isGameStarted = false;
  final GameSaveHelper _gameSaveHelper = GameSaveHelper();
  bool _isSaving = false;

  @override
  void dispose() {
    _inputControllers.values.forEach((controller) => controller.dispose());
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  String _getKey(int row, int col) => '$row-$col';

  // NEW: Handle back button press
  Future<bool> _onWillPop(GameController controller) async {
    if (!_isGameStarted) {
      return true; // Allow back navigation if game hasn't started
    }

    // Show abandon game dialog
    final shouldLeave = await _showAbandonGameDialog(context, controller);
    return shouldLeave ?? false;
  }

  // NEW: Show abandon game dialog
  Future<bool?> _showAbandonGameDialog(BuildContext context, GameController controller) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.exit_to_app,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "LEAVE GAME?",
                style: TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                "Are you sure you want to leave?\n\nYour current progress will be saved as abandoned.\n\nCurrent Score: ${controller.score}",
                style: const TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Colors.black26, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "STAY",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Close dialog first
                        Navigator.pop(dialogContext, true);

                        // Save game with abandoned status
                        await _saveGameToBackend(context, controller, 'abandoned');

                        // Pop the game screen
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "LEAVE",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MODIFIED: Added gameStatus parameter with default value
  Future<void> _saveGameToBackend(
      BuildContext context,
      GameController controller,
      [String gameStatus = 'completed']
      ) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await _gameSaveHelper.saveSoloGame(
        controller: controller,
        gameStatus: gameStatus,
      );

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Game saved successfully!'),
              backgroundColor: gameStatus == 'abandoned' ? Colors.orange : textGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to save game'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving game: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _onKeyboardTap(String value, GameController controller) {
    if (_selectedCell == null || !_isGameStarted) return;

    final parts = _selectedCell!.split('-');
    final row = int.parse(parts[0]);
    final col = int.parse(parts[1]);

    if (value == 'clear') {
      final currentText = _inputControllers[_selectedCell]?.text ?? '';
      if (currentText.isNotEmpty) {
        final newText = currentText.substring(0, currentText.length - 1);
        _inputControllers[_selectedCell]?.text = newText;

        if (newText.isEmpty) {
          controller.updateCell(row, col, null);
        } else {
          final newVal = int.tryParse(newText);
          if (newVal != null && newVal >= 0) {
            controller.updateCell(row, col, newVal);
          }
        }
      }
    } else {
      final currentText = _inputControllers[_selectedCell]?.text ?? '';
      final newText = currentText + value;

      if (newText.length <= 3) {
        _inputControllers[_selectedCell]?.text = newText;
        final newVal = int.tryParse(newText);
        if (newVal != null && newVal >= 0) {
          controller.updateCell(row, col, newVal);
          _checkIfAllCellsFilled(controller);
        }
      }
    }
  }

  void _checkIfAllCellsFilled(GameController controller) {
    bool allFilled = true;

    for (int i = 0; i < controller.gridSize; i++) {
      for (int j = 0; j < controller.gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (controller.grid[i][j] == null) {
          allFilled = false;
          break;
        }
      }
      if (!allFilled) break;
    }

    if (allFilled && _isGameStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isGameStarted) {
          _showStopGameDialog(context, controller);
        }
      });
    }
  }

  void _showHintDialog(BuildContext context, GameController controller) {
    if (_selectedCell == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a cell first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final parts = _selectedCell!.split('-');
    final row = int.parse(parts[0]);
    final col = int.parse(parts[1]);

    if (controller.isFixed[row][col] || (row == 0 && col == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot use hint on this cell'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (controller.isHinted[row][col]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hint already used on this cell'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: hintColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hintColor,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: hintColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "USE HINT?",
                style: TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hintColor,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                "Reveal the correct answer for this cell?\n\nHints remaining: ${controller.hintsRemaining}\nPenalty: ${controller.hintPenalty} points",
                style: const TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Colors.black26, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "CANCEL",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        bool success = controller.useHint(row, col);
                        if (success) {
                          _inputControllers[_selectedCell]?.text =
                              controller.grid[row][col]?.toString() ?? '';

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hint used! ${controller.hintsRemaining} remaining'),
                              backgroundColor: hintColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not use hint on this cell'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hintColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "USE HINT",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Modified _showStopGameDialog method
  void _showStopGameDialog(BuildContext context, GameController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.orange,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "STOP GAME?",
                style: TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              const Text(
                "Do you want to stop and submit your score?",
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Colors.black26, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "CONTINUE",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Close the dialog first
                        Navigator.pop(dialogContext);

                        // Stop the game
                        setState(() => _isGameStarted = false);
                        controller.validateGrid();

                        // Save game to backend
                        await _saveGameToBackend(context, controller, 'completed');

                        // Show result dialog without submit button
                        if (mounted) {
                          _showResultDialog(context, controller, showSubmitButton: false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "STOP",
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Modified _showResultDialog method - added showSubmitButton parameter
  void _showResultDialog(BuildContext context, GameController controller, {bool showSubmitButton = true}) {
    final accuracyPercentage = controller.accuracyPercentage;
    final totalCells = (controller.gridSize * controller.gridSize) - 1 - controller.seedNumbers;
    int correctCount = 0;

    for (int i = 0; i < controller.gridSize; i++) {
      for (int j = 0; j < controller.gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (!controller.isFixed[i][j] &&
            controller.grid[i][j] != null &&
            controller.grid[i][j] == controller.solutionGrid[i][j]) {
          correctCount++;
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: textGreen.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: textGreen,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: textGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "GAME STATUS",
                style: TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textBlue,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: textPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textPink, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      "YOUR ACCURACY",
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPink,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${accuracyPercentage.toStringAsFixed(2)} %",
                      style: const TextStyle(
                        fontFamily: 'Digitalt',
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: textPink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    "Correct",
                    "$correctCount",
                    textGreen,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _buildStatItem(
                    "Total",
                    "$totalCells",
                    textBlue,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _buildStatItem(
                    "Hints",
                    "${controller.hintsUsed}",
                    hintColor,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Conditional button layout based on showSubmitButton
              if (showSubmitButton)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          controller.resetGame();
                          _inputControllers.clear();
                          _focusNodes.clear();
                          setState(() => _selectedCell = null);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: textBlue, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "CLOSE",
                          style: TextStyle(
                            fontFamily: 'Digitalt',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textBlue,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);

                          await _saveGameToBackend(context, controller, 'completed');

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubmitGameScreen(),
                            ),
                          ).then((_) {
                            controller.resetGame();
                            _inputControllers.clear();
                            _focusNodes.clear();
                            setState(() => _selectedCell = null);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: textGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(
                            fontFamily: 'Digitalt',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
              // Only show CLOSE button when submit button is hidden
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      controller.resetGame();
                      _inputControllers.clear();
                      _focusNodes.clear();
                      setState(() => _selectedCell = null);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "CLOSE",
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Digitalt',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return ChangeNotifierProvider(
      create: (_) => GameController(gridSize: 4),
      child: Consumer<GameController>(
        builder: (context, controller, _) {
          int gridSize = controller.gridSize;
          final bool isTimed = controller.mode == GameMode.timed;

          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              if ((i != 0 || j != 0) && !controller.isFixed[i][j]) {
                String key = _getKey(i, j);
                _inputControllers.putIfAbsent(key, () => TextEditingController());
                _focusNodes.putIfAbsent(key, () {
                  final node = FocusNode();
                  node.addListener(() {
                    if (node.hasFocus) {
                      setState(() => _selectedCell = key);
                    }
                  });
                  return node;
                });
              }
            }
          }

          // MODIFIED: Wrap Scaffold with WillPopScope
          return WillPopScope(
            onWillPop: () => _onWillPop(controller),
            child: Scaffold(
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFC0CB),
                      Color(0xFFADD8E6),
                      Color(0xFFE6E6FA),
                    ],
                  ),
                ),
                child: // Replace the build method's body (inside SafeArea) with this responsive version:

                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenHeight = constraints.maxHeight;
                      final screenWidth = constraints.maxWidth;

                      // Responsive font and icon sizes
                      final headerSize = screenHeight * 0.04;
                      final iconSize = screenHeight * 0.035;
                      final scoreFontSize = screenHeight * 0.016;
                      final buttonFontSize = screenHeight * 0.015;
                      final buttonPadding = screenHeight * 0.01;

                      return Column(
                        children: [
                          // Header Bar - Fixed size
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.008,
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () async {
                                    final shouldPop = await _onWillPop(controller);
                                    if (shouldPop && mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Container(
                                    width: iconSize,
                                    height: iconSize,
                                    decoration: const BoxDecoration(
                                      color: textPink,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.arrow_back_ios_new,
                                        color: Colors.white, size: iconSize * 0.6),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  "Jol Puzzle",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: headerSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Builder(
                                  builder: (innerContext) {
                                    return InkWell(
                                      onTap: _isGameStarted ? null : () {
                                        showSettingsDialog(innerContext);
                                      },
                                      child: Container(
                                        width: iconSize,
                                        height: iconSize,
                                        decoration: BoxDecoration(
                                          color: _isGameStarted
                                              ? Colors.grey
                                              : textGreen,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.settings,
                                            color: Colors.white, size: iconSize * 0.6),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.008),

                          // Timer/Mode Bar - Fixed size
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.04,
                                      vertical: screenHeight * 0.01,
                                    ),
                                    decoration: BoxDecoration(
                                      color: textPink,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        isTimed
                                            ? Text(
                                          "Time: ${controller.timeLeft.inMinutes.toString().padLeft(2, '0')}:${(controller.timeLeft.inSeconds % 60).toString().padLeft(2, '0')}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: scoreFontSize,
                                          ),
                                        )
                                            : Text(
                                          "Mode: Untimed",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: scoreFontSize,
                                          ),
                                        ),
                                        if (!_isGameStarted)
                                          Text(
                                            "Score: ${controller.score}",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: scoreFontSize,
                                            ),
                                          ),
                                        Text(
                                          "Hints: ${controller.hintsRemaining}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: scoreFontSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                InkWell(
                                  onTap: _isGameStarted ? null : () {
                                    controller.toggleMode();
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(screenHeight * 0.012),
                                    decoration: BoxDecoration(
                                      color: _isGameStarted
                                          ? Colors.grey
                                          : textGreen,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isTimed ? Icons.timer : Icons.timer_off,
                                      color: Colors.white,
                                      size: iconSize * 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.01),

                          // Action Buttons Row - Fixed size
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: (_isGameStarted && controller.hintsRemaining > 0)
                                        ? () => _showHintDialog(context, controller)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hintColor,
                                      disabledBackgroundColor: Colors.grey,
                                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline,
                                          size: buttonFontSize * 1.2,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Hint",
                                          style: TextStyle(
                                            fontFamily: "Rubik",
                                            fontSize: buttonFontSize,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_isGameStarted) {
                                        _showStopGameDialog(context, controller);
                                      } else {
                                        setState(() => _isGameStarted = true);
                                        controller.startGame();
                                        if (controller.mode == GameMode.timed) {
                                          controller.startTimer();
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isGameStarted
                                          ? Colors.orange
                                          : textGreen,
                                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      _isGameStarted ? "Stop" : "Start",
                                      style: TextStyle(
                                        fontFamily: "Rubik",
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.015),

                          // FLEXIBLE GRID - Takes available space
                          Flexible(
                            flex: 5, // Takes proportional space
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                              child: Container(
                                padding: EdgeInsets.all(screenHeight * 0.015),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: LayoutBuilder(
                                  builder: (context, gridConstraints) {
                                    final availableSize = gridConstraints.maxWidth < gridConstraints.maxHeight
                                        ? gridConstraints.maxWidth
                                        : gridConstraints.maxHeight;

                                    final spacing = availableSize * 0.02;
                                    final cellSize = (availableSize - (spacing * (gridSize - 1)) - (screenHeight * 0.03)) / gridSize;
                                    final unifiedFontSize = cellSize * 0.35; // Font size relative to cell size

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: gridSize * gridSize,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridSize,
                                        mainAxisSpacing: spacing,
                                        crossAxisSpacing: spacing,
                                        childAspectRatio: 1,
                                      ),
                                      itemBuilder: (context, index) {
                                        int row = index ~/ gridSize;
                                        int col = index % gridSize;
                                        bool isFixedCell = controller.isFixed[row][col];
                                        bool isHintedCell = controller.isHinted[row][col];
                                        final value = controller.grid[row][col];

                                        Color cellColor = Colors.white;

                                        if (row == 0 && col == 0) {
                                          cellColor = const Color(0xFFFFD54F);
                                        } else if (isFixedCell) {
                                          cellColor = const Color(0xFFFFD54F);
                                        } else if (isHintedCell) {
                                          cellColor = hintColor.withOpacity(0.3);
                                        }

                                        if (controller.isWrong[row][col] == true) {
                                          cellColor = Colors.red.shade300;
                                        }

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: cellColor,
                                            borderRadius: BorderRadius.circular(6),
                                            border: isHintedCell
                                                ? Border.all(color: hintColor, width: 2)
                                                : null,
                                          ),
                                          child: Center(
                                            child: (row == 0 && col == 0)
                                                ? GestureDetector(
                                              onTap: _isGameStarted ? null : () {
                                                setState(() {
                                                  _showMinus = !_showMinus;
                                                });
                                                controller.setOperation(
                                                    _showMinus
                                                        ? PuzzleOperation.subtraction
                                                        : PuzzleOperation.addition
                                                );
                                                _inputControllers.clear();
                                                _focusNodes.clear();
                                                setState(() => _selectedCell = null);
                                              },
                                              child: Text(
                                                _showMinus ? "-" : "+",
                                                style: TextStyle(
                                                  fontSize: unifiedFontSize * 1.3,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            )
                                                : isFixedCell
                                                ? Text(
                                              value?.toString() ?? "",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: unifiedFontSize,
                                                color: Colors.black,
                                              ),
                                            )
                                                : TextField(
                                              controller: _inputControllers[_getKey(row, col)],
                                              focusNode: _focusNodes[_getKey(row, col)],
                                              textAlign: TextAlign.center,
                                              readOnly: true,
                                              enabled: _isGameStarted,
                                              showCursor: _isGameStarted,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                hintText: "",
                                                counterText: "",
                                                isCollapsed: true,
                                              ),
                                              style: TextStyle(
                                                fontSize: unifiedFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: isHintedCell ? hintColor : Colors.black,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.015),

                          // FLEXIBLE KEYBOARD - Takes available space
                          Flexible(
                            flex: 4, // Takes proportional space
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                              child: Container(
                                padding: EdgeInsets.all(screenHeight * 0.015),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: LayoutBuilder(
                                  builder: (context, keyboardConstraints) {
                                    final keyHeight = keyboardConstraints.maxHeight * 0.20;
                                    final fontSize = keyHeight * 0.4;
                                    final iconSize = keyHeight * 0.35;

                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              _buildKeyButton('1', controller, keyHeight, fontSize),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildKeyButton('2', controller, keyHeight, fontSize),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildKeyButton('3', controller, keyHeight, fontSize),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: keyboardConstraints.maxHeight * 0.02),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              _buildKeyButton('4', controller, keyHeight, fontSize),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildKeyButton('5', controller, keyHeight, fontSize),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildKeyButton('6', controller, keyHeight, fontSize),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: keyboardConstraints.maxHeight * 0.02),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              _buildKeyButton('7', controller, keyHeight, fontSize),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildKeyButton('8', controller, keyHeight, fontSize),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildKeyButton('9', controller, keyHeight, fontSize),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: keyboardConstraints.maxHeight * 0.02),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(child: Container()),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildKeyButton('0', controller, keyHeight, fontSize),
                                              SizedBox(width: screenWidth * 0.02),
                                              _buildClearButton(controller, keyHeight, iconSize),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.015),

                          // Bottom Actions - Fixed size
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.05,
                              vertical: screenHeight * 0.008,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isGameStarted ? null : () {
                                      controller.resetGame();
                                      _inputControllers.clear();
                                      _focusNodes.clear();
                                      setState(() => _selectedCell = null);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      disabledBackgroundColor: Colors.grey,
                                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      "Reset",
                                      style: TextStyle(
                                        fontFamily: "Rubik",
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: _isGameStarted ? null : () {
                                      controller.validateGrid();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SubmitGameScreen(),
                                        ),
                                      ).then((_) {
                                        controller.resetGame();
                                        _inputControllers.clear();
                                        _focusNodes.clear();
                                        setState(() => _selectedCell = null);
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: textBlue,
                                      disabledBackgroundColor: Colors.grey,
                                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      "Check & Submit Score",
                                      style: TextStyle(
                                        fontFamily: "Rubik",
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyButton(String number, GameController controller, double height, double fontSize) {
    return Expanded(
      child: Material(
        color: _isGameStarted ? Colors.white : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: _isGameStarted ? () => _onKeyboardTap(number, controller) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(vertical: height * 0.15),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: _isGameStarted ? Colors.black : Colors.black45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton(GameController controller, double height, double iconSize) {
    return Expanded(
      child: Material(
        color: _isGameStarted ? Colors.grey.shade400 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: _isGameStarted ? () => _onKeyboardTap('clear', controller) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(vertical: height * 0.15),
            alignment: Alignment.center,
            child: Icon(
              Icons.backspace_outlined,
              size: iconSize,
              color: _isGameStarted ? Colors.black87 : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  void showSettingsDialog(BuildContext context) {
    final controller = Provider.of<GameController>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(controller: controller),
    );
  }
}

// SettingsDialog remains the same
class SettingsDialog extends StatefulWidget {
  final GameController controller;

  const SettingsDialog({super.key, required this.controller});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  double volume = 0.5;
  double music = 0.5;
  bool hapticEnabled = true;

  static const Color textPink = Color(0xFFC42AF8);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textBlue = Color(0xFF0734A5);
  static const Color settingsOrange = Color(0xFFF47A62);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isTimed = controller.mode == GameMode.timed;
    final gridSize = controller.gridSize;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: settingsOrange,
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.volume_up, color: textPink),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 16,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: volume,
                          onChanged: (value) =>
                              setState(() => volume = value),
                          activeColor: textPink,
                          inactiveColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_note_outlined, color: textGreen),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 16,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: music,
                          onChanged: (value) =>
                              setState(() => music = value),
                          activeColor: textGreen,
                          inactiveColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text(
                      'HAPTIC FEEDBACK',
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: textBlue,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          hapticEnabled ? 'ON' : 'OFF',
                          style: const TextStyle(
                            fontFamily: 'Digitalt',
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: textBlue,
                          ),
                        ),
                        Switch(
                          value: hapticEnabled,
                          onChanged: (value) =>
                              setState(() => hapticEnabled = value),
                          activeColor: Colors.white,
                          activeTrackColor: textBlue,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text(
                      'TIMED MODE',
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: textBlue,
                      ),
                    ),
                    Switch(
                      value: isTimed,
                      onChanged: (value) {
                        setState(() {
                          controller.toggleMode();
                        });
                      },
                      activeColor: Colors.white,
                      activeTrackColor: textGreen,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text(
                      'GRID SIZE',
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: textBlue,
                      ),
                    ),
                    DropdownButton<int>(
                      value: gridSize,
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        color: textBlue,
                        fontFamily: 'Digitalt',
                        fontSize: 16,
                      ),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 x 3')),
                        DropdownMenuItem(value: 4, child: Text('4 x 4')),
                        DropdownMenuItem(value: 5, child: Text('5 x 5')),
                      ],
                      onChanged: (value) {
                        // Commented out as per original code
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: -40,
            child: Image.asset(
              'lib/assets/images/settings_emoji.png',
              height: 80,
            ),
          ),
        ],
      ),
    );
  }
}

void showSettingsDialog(BuildContext context) {
  final controller = Provider.of<GameController>(context, listen: false);

  showDialog(
    context: context,
    builder: (context) => SettingsDialog(controller: controller),
  );
}
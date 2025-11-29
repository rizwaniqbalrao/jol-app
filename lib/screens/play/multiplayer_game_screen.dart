// MultiplayerGameScreen.dart - COMPLETE WITH ALL AUTO-SAVE SCENARIOS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jol_app/screens/play/widgets/multiplayer_gamehelper.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'controller/multiplayer_game_controller.dart';
import 'models/room_models.dart';
import 'multiplayer_results_screen.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String roomCode;
  final String playerId;

  const MultiplayerGameScreen({
    super.key,
    required this.roomCode,
    required this.playerId,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);

  final MultiplayerGameSaveHelper _gameSaveHelper = MultiplayerGameSaveHelper();
  bool _isSaving = false;
  bool _hasAutoSaved = false;

  final Map<String, TextEditingController> _inputControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _showLeaderboard = false;
  String? _selectedCell;

  @override
  void dispose() {
    _inputControllers.values.forEach((controller) => controller.dispose());
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  String _getKey(int row, int col) => '$row-$col';

  bool _isGridFilled(MultiplayerGameController controller, Room room) {
    final gridSize = room.settings.gridSize;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (i == 0 && j == 0) continue;
        if (!room.puzzle!.isFixed[i][j] && controller.grid[i][j] == null) {
          return false;
        }
      }
    }
    return true;
  }

  // CRITICAL: Handle back button press for abandoned saves
  Future<bool> _onWillPop(MultiplayerGameController controller) async {
    // If game hasn't started yet, allow free navigation
    if (!controller.isPlaying) {
      return true;
    }

    // Show leave confirmation dialog
    _showLeaveConfirmation(controller);
    return false; // Prevent automatic pop
  }

  Future<void> _saveGameToBackend(
      BuildContext context,
      MultiplayerGameController controller,
      Room room,
      String gameStatus,
      ) async {
    if (_isSaving || _hasAutoSaved) return;

    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await _gameSaveHelper.saveMultiplayerGame(
        controller: controller,
        room: room,
        gameStatus: gameStatus,
      );

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        setState(() => _hasAutoSaved = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Game saved successfully!'),
              backgroundColor: textGreen,
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

  void _onKeyboardTap(String value, MultiplayerGameController controller) {
    if (_selectedCell == null) return;

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
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return ChangeNotifierProvider(
      create: (_) => MultiplayerGameController(
        roomCode: widget.roomCode,
        playerId: widget.playerId,
      ),
      child: Consumer<MultiplayerGameController>(
        builder: (context, controller, _) {
          // CRITICAL FIX 1: Navigate to results when game ends + auto-save
          if (controller.room?.gameState.status == 'ended' && !controller.isPlaying) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Auto-save before navigating if player had submitted
              if (!_hasAutoSaved && controller.isSubmitted && controller.room != null) {
                // Determine status: completed if submitted, timed_out if time ran out
                String status = 'completed';
                if (controller.room!.settings.mode == 'timed' &&
                    controller.timeLeft.inSeconds <= 0) {
                  status = 'timed_out';
                }

                await _saveGameToBackend(
                  context,
                  controller,
                  controller.room!,
                  status,
                );
              }

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MultiplayerResultsScreen(
                      roomCode: widget.roomCode,
                      playerId: widget.playerId,
                    ),
                  ),
                );
              }
            });
          }

          if (controller.room == null || controller.grid.isEmpty) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final room = controller.room!;
          final gridSize = room.settings.gridSize;
          final isTimed = room.settings.mode == 'timed';

          // Initialize controllers and focus nodes
          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              if ((i != 0 || j != 0) && !room.puzzle!.isFixed[i][j]) {
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

          // CRITICAL FIX 2: Wrap Scaffold with WillPopScope for back button handling
          return WillPopScope(
            onWillPop: () => _onWillPop(controller),
            child: Scaffold(
              body: Stack(
                children: [
                  Container(
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
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final screenHeight = constraints.maxHeight;
                          final screenWidth = constraints.maxWidth;

                          final headerSize = screenHeight * 0.04;
                          final iconSize = screenHeight * 0.035;
                          final scoreFontSize = screenHeight * 0.016;
                          final buttonFontSize = screenHeight * 0.015;
                          final buttonPadding = screenHeight * 0.01;

                          final gridPadding = screenWidth * 0.1;
                          final gridAreaHeight = screenHeight * 0.35;
                          final spacing = screenHeight * 0.01;

                          final keyboardHeight = screenHeight * 0.30;
                          final keyHeight = keyboardHeight * 0.20;
                          final keyFontSize = screenHeight * 0.022;

                          return SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: screenHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  children: [
                                    /// 1. Header Bar
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.03,
                                        vertical: screenHeight * 0.008,
                                      ),
                                      child: Row(
                                        children: [
                                          InkWell(
                                            onTap: () => _showLeaveConfirmation(controller),
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
                                          const Text(
                                            "Private Room",
                                            style: TextStyle(
                                              fontFamily: "Rubik",
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () => setState(() => _showLeaderboard = !_showLeaderboard),
                                            child: Container(
                                              width: iconSize,
                                              height: iconSize,
                                              decoration: const BoxDecoration(
                                                color: textGreen,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.leaderboard,
                                                  color: Colors.white, size: iconSize * 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: screenHeight * 0.008),

                                    /// 2. Score & Timer
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
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: screenHeight * 0.01),

                                    /// 3. Submit Game Button
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: (controller.isPlaying && !controller.isSubmitted && _isGridFilled(controller, room))
                                              ? () async {
                                            await controller.submitGame();

                                            if (mounted && !_hasAutoSaved) {
                                              await _saveGameToBackend(context, controller, room, 'completed');
                                            }

                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Game submitted and saved!'),
                                                  backgroundColor: textGreen,
                                                ),
                                              );
                                            }
                                          }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: textGreen,
                                            disabledBackgroundColor: Colors.grey,
                                            padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            controller.isSubmitted ? "Submitted ✓" : "Submit Game",
                                            style: TextStyle(
                                              fontFamily: "Rubik",
                                              fontSize: buttonFontSize,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: screenHeight * 0.01),

                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                                      child: Text(
                                        "Double tap a cell to use a hint (if available)",
                                        style: TextStyle(
                                          fontFamily: "Rubik",
                                          fontSize: scoreFontSize,
                                          color: Colors.grey.shade700,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    SizedBox(height: screenHeight * 0.015),

                                    /// 4. Grid
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: gridPadding),
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
                                        child: SizedBox(
                                          height: gridAreaHeight,
                                          child: LayoutBuilder(
                                            builder: (context, gridConstraints) {
                                              final gridWidth = gridConstraints.maxWidth;
                                              final cellSize = (gridWidth - (spacing * (gridSize - 1))) / gridSize;
                                              final unifiedFontSize = screenHeight * 0.024;

                                              return GridView.builder(
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
                                                  bool isFixedCell = room.puzzle!.isFixed[row][col];
                                                  final value = controller.grid[row][col];

                                                  Color cellColor = Colors.white;

                                                  if (row == 0 && col == 0) {
                                                    cellColor = const Color(0xFFFFD54F);
                                                  } else if (isFixedCell) {
                                                    cellColor = const Color(0xFFFFD54F);
                                                  }

                                                  return GestureDetector(
                                                    onDoubleTap: () {
                                                      if (!isFixedCell && controller.hintsRemaining > 0) {
                                                        _showHintDialog(controller, row, col);
                                                      }
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: cellColor,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Center(
                                                        child: (row == 0 && col == 0)
                                                            ? Text(
                                                          room.settings.operation == 'addition' ? "+" : "-",
                                                          style: TextStyle(
                                                            fontSize: unifiedFontSize * 1.3,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.black,
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
                                                          showCursor: true,
                                                          decoration: const InputDecoration(
                                                            border: InputBorder.none,
                                                            hintText: "",
                                                            counterText: "",
                                                            isCollapsed: true,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: unifiedFontSize,
                                                            fontWeight: FontWeight.bold,
                                                          ),
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

                                    /// 5. Keyboard
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: gridPadding),
                                      child: Container(
                                        height: keyboardHeight,
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
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Row(
                                              children: [
                                                _buildKeyButton('1', controller, keyHeight, keyFontSize),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildKeyButton('2', controller, keyHeight, keyFontSize),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildKeyButton('3', controller, keyHeight, keyFontSize),
                                              ],
                                            ),
                                            SizedBox(height: screenHeight * 0.01),
                                            Row(
                                              children: [
                                                _buildKeyButton('4', controller, keyHeight, keyFontSize),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildKeyButton('5', controller, keyHeight, keyFontSize),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildKeyButton('6', controller, keyHeight, keyFontSize),
                                              ],
                                            ),
                                            SizedBox(height: screenHeight * 0.01),
                                            Row(
                                              children: [
                                                _buildKeyButton('7', controller, keyHeight, keyFontSize),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildKeyButton('8', controller, keyHeight, keyFontSize),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildKeyButton('9', controller, keyHeight, keyFontSize),
                                              ],
                                            ),
                                            SizedBox(height: screenHeight * 0.01),
                                            Row(
                                              children: [
                                                Expanded(child: Container()),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildKeyButton('0', controller, keyHeight, keyFontSize),
                                                SizedBox(width: screenWidth * 0.02),
                                                _buildClearButton(controller, keyHeight, screenHeight * 0.022),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: screenHeight * 0.015),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  /// Leaderboard Overlay
                  if (_showLeaderboard)
                    _buildLeaderboardOverlay(controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyButton(String number, MultiplayerGameController controller, double height, double fontSize) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: () => _onKeyboardTap(number, controller),
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
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton(MultiplayerGameController controller, double height, double iconSize) {
    return Expanded(
      child: Material(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: () => _onKeyboardTap('clear', controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(vertical: height * 0.15),
            alignment: Alignment.center,
            child: Icon(
              Icons.backspace_outlined,
              size: iconSize,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardOverlay(MultiplayerGameController controller) {
    final leaderboard = controller.getLeaderboard();

    return GestureDetector(
      onTap: () => setState(() => _showLeaderboard = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Live Leaderboard",
                  style: TextStyle(
                    fontFamily: "Rubik",
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textPink,
                  ),
                ),
                const SizedBox(height: 20),
                ...leaderboard.asMap().entries.map((entry) {
                  final index = entry.key;
                  final player = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.amber.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "#${index + 1}",
                          style: TextStyle(
                            fontFamily: "Rubik",
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: index == 0 ? Colors.amber.shade900 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            player.name,
                            style: const TextStyle(
                              fontFamily: "Rubik",
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          "${player.score}",
                          style: const TextStyle(
                            fontFamily: "Rubik",
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHintDialog(MultiplayerGameController controller, int row, int col) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Hint?'),
        content: Text('Use a hint for this cell? (${controller.hintsRemaining} remaining)\n\nThis will deduct 5 points.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await controller.useHint(row, col);
              if (success) {
                _inputControllers[_getKey(row, col)]?.text =
                    controller.grid[row][col]?.toString() ?? '';
              }
            },
            child: const Text('Use Hint'),
          ),
        ],
      ),
    );
  }

  void _showLeaveConfirmation(MultiplayerGameController controller) {
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
                "Are you sure you want to leave?\n\nYour progress will be saved as abandoned.\n\nCurrent Score: ${controller.localScore}",
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
                        Navigator.pop(dialogContext);

                        // Save game with abandoned status
                        if (controller.isPlaying && controller.room != null && !_hasAutoSaved) {
                          await _saveGameToBackend(
                            context,
                            controller,
                            controller.room!,
                            'abandoned',
                          );
                        }

                        // Leave room
                        await controller.leaveRoom();

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
}
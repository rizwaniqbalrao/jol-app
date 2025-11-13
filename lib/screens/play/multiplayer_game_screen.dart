// MultiplayerGameScreen.dart - UPDATED WITH GRID & KEYPAD DESIGN

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _onKeyboardTap(String value, MultiplayerGameController controller) {
    if (_selectedCell == null) return;

    final parts = _selectedCell!.split('-');
    final row = int.parse(parts[0]);
    final col = int.parse(parts[1]);

    if (value == 'clear') {
      final currentText = _inputControllers[_selectedCell]?.text ?? '';
      if (currentText.isNotEmpty) {
        // Remove last character
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
          // Navigate to results when game ends
          if (controller.room?.gameState.status == 'ended' && !controller.isPlaying) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MultiplayerResultsScreen(
                    roomCode: widget.roomCode,
                    playerId: widget.playerId,
                  ),
                ),
              );
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

          return Scaffold(
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
                        // Calculate responsive sizing based on available height
                        final screenHeight = constraints.maxHeight;
                        final screenWidth = constraints.maxWidth;

                        // Responsive font and size calculations
                        final headerSize = screenHeight * 0.04;
                        final iconSize = screenHeight * 0.035;
                        final scoreFontSize = screenHeight * 0.016;
                        final buttonFontSize = screenHeight * 0.015;
                        final buttonPadding = screenHeight * 0.01;

                        // Grid calculations
                        final gridPadding = screenWidth * 0.1;
                        final gridAreaHeight = screenHeight * 0.35;
                        final spacing = screenHeight * 0.01;

                        // Keyboard calculations
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
                                                  "Score: ${controller.localScore}",
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
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Submitted! Score based on correct cells.')),
                                          );
                                        }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: textGreen,
                                          padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          controller.isSubmitted ? "Submitted" : "Submit Game",
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

                                  // Note about double tap for hints
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

                                  /// 4. Grid with Container Background
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

                                                // Top-left corner is now yellow too
                                                if (row == 0 && col == 0) {
                                                  cellColor = const Color(0xFFFFD54F);
                                                } else if (isFixedCell) {
                                                  cellColor = const Color(0xFFFFD54F); // Yellow for fixed cells
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

                                  /// 5. Custom Numeric Keyboard
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
      builder: (context) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text('Are you sure you want to leave? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await controller.leaveRoom();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
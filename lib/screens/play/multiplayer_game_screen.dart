// MultiplayerGameScreen.dart - UPDATED WITH SCROLLVIEW AND OVERFLOW FIXES
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    for (var controller in _inputControllers.values) {
      controller.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
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
    // If game_screen hasn't started yet, allow free navigation
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
              content: Text(result['message'] ?? 'Failed to save game_screen'),
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
            content: Text('Error saving game_screen: $e'),
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
    final selected = _selectedCell;
    if (selected == null) return;
    final parts = selected.split('-');
    final row = int.parse(parts[0]);
    final col = int.parse(parts[1]);
    // guard for fixed cells and controller presence
    if (controller.room?.puzzle?.isFixed[row][col] == true) return;
    final tc = _inputControllers[selected];
    if (tc == null) return;
    if (!(_focusNodes[selected]?.hasFocus ?? false)) return;
    if (value == 'clear') {
      final currentText = tc.text;
      if (currentText.isNotEmpty) {
        final newText = currentText.substring(0, currentText.length - 1);
        tc.text = newText;
        if (newText.isEmpty) {
          controller.updateCell(row, col, null);
        } else {
          final newVal = double.tryParse(newText);
          if (newVal != null && newVal >= 0) {
            controller.updateCell(row, col, newVal);
          }
        }
      }
    } else {
      final currentText = tc.text;
      // Prevent multiple decimals
      if (value == '.' && currentText.contains('.')) return;

      final newText = currentText + value;
      // Allow up to 6 characters (supports up to 5 digits plus optional decimal)
      if (newText.length <= 6) {
        tc.text = newText;
        final newVal = double.tryParse(newText);
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
          // CRITICAL FIX 1: Navigate to results when game_screen ends + auto-save
          if (controller.room?.gameState.status == 'ended' &&
              !controller.isPlaying) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Auto-save before navigating if player had submitted
              if (!_hasAutoSaved &&
                  controller.isSubmitted &&
                  controller.room != null) {
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
                _inputControllers.putIfAbsent(
                    key, () => TextEditingController());
                _focusNodes.putIfAbsent(key, () {
                  final node = FocusNode();
                  node.addListener(() {
                    if (node.hasFocus) {
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedCell != key)
                          setState(() => _selectedCell = key);
                      });
                    } else {
                      if (mounted && _selectedCell == key)
                        setState(() => _selectedCell = null);
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
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height -
                                MediaQuery.of(context).padding.top -
                                MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              /// 1. Header Bar
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.of(context).size.width * 0.03,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          _showLeaveConfirmation(controller),
                                      child: Container(
                                        width: 35,
                                        height: 35,
                                        decoration: const BoxDecoration(
                                          color: textPink,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.arrow_back_ios_new,
                                            color: Colors.white, size: 20),
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
                                      onTap: () => setState(() =>
                                          _showLeaderboard = !_showLeaderboard),
                                      child: Container(
                                        width: 35,
                                        height: 35,
                                        decoration: const BoxDecoration(
                                          color: textGreen,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.leaderboard,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              /// 2. Score & Timer
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: textPink,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            isTimed
                                                ? Text(
                                                    "Time: ${controller.timeLeft.inMinutes.toString().padLeft(2, '0')}:${(controller.timeLeft.inSeconds % 60).toString().padLeft(2, '0')}",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  )
                                                : const Text(
                                                    "Mode: Untimed",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                            Text(
                                              "Hints: ${controller.hintsRemaining}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              /// 3. Submit Game Button
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: (controller.isPlaying &&
                                            !controller.isSubmitted &&
                                            _isGridFilled(controller, room))
                                        ? () async {
                                            await controller.submitGame();
                                            if (mounted && !_hasAutoSaved) {
                                              await _saveGameToBackend(
                                                  context,
                                                  controller,
                                                  room,
                                                  'completed');
                                            }
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Game submitted and saved!'),
                                                  backgroundColor: textGreen,
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: textGreen,
                                      disabledBackgroundColor: Colors.grey,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      controller.isSubmitted
                                          ? "Submitted ✓"
                                          : "Submit Game",
                                      style: const TextStyle(
                                        fontFamily: "Rubik",
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  "Double tap a cell to use a hint (if available)",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),

                              /// 4. Grid - Fixed height to prevent overflow
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
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
                                    height: MediaQuery.of(context).size.height *
                                        0.38,
                                    child: LayoutBuilder(
                                      builder: (context, gridConstraints) {
                                        final gridWidth =
                                            gridConstraints.maxWidth;
                                        final spacing = 8;
                                        final cellSize = (gridWidth -
                                                (spacing * (gridSize - 1))) /
                                            gridSize;
                                        final unifiedFontSize = cellSize * 0.35;
                                        return GridView.builder(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: gridSize * gridSize,
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: gridSize,
                                            mainAxisSpacing: spacing.toDouble(),
                                            crossAxisSpacing:
                                                spacing.toDouble(),
                                            childAspectRatio: 1,
                                          ),
                                          itemBuilder: (context, index) {
                                            int row = index ~/ gridSize;
                                            int col = index % gridSize;
                                            bool isFixedCell =
                                                room.puzzle!.isFixed[row][col];
                                            final value =
                                                controller.grid[row][col];
                                            Color cellColor = Colors.white;
                                            if (row == 0 && col == 0) {
                                              cellColor =
                                                  const Color(0xFFFFD54F);
                                            } else if (isFixedCell) {
                                              cellColor =
                                                  const Color(0xFFFFD54F);
                                            }
                                            return GestureDetector(
                                              onDoubleTap: () {
                                                if (!isFixedCell &&
                                                    controller.hintsRemaining >
                                                        0) {
                                                  _showHintDialog(
                                                      controller, row, col);
                                                }
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: cellColor,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: (row == 0 && col == 0)
                                                      ? Text(
                                                          room.settings
                                                                      .operation ==
                                                                  'addition'
                                                              ? "+"
                                                              : "-",
                                                          style: TextStyle(
                                                            fontSize:
                                                                unifiedFontSize *
                                                                    1.3,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        )
                                                      : isFixedCell
                                                          ? Text(
                                                              value?.toString() ??
                                                                  "",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize:
                                                                    unifiedFontSize,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                            )
                                                          : TextField(
                                                              controller:
                                                                  _inputControllers[
                                                                      _getKey(
                                                                          row,
                                                                          col)],
                                                              focusNode:
                                                                  _focusNodes[
                                                                      _getKey(
                                                                          row,
                                                                          col)],
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              readOnly: true,
                                                              showCursor: true,
                                                              decoration:
                                                                  const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                hintText: "",
                                                                counterText: "",
                                                                isCollapsed:
                                                                    true,
                                                              ),
                                                              style: TextStyle(
                                                                fontSize:
                                                                    unifiedFontSize,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                              const SizedBox(height: 16),

                              /// 5. Keyboard - Fixed height
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Container(
                                  height: 200, // Fixed height for keyboard
                                  padding: const EdgeInsets.all(16),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            _buildKeyButton(
                                                '1', controller, 16),
                                            const SizedBox(width: 8),
                                            _buildKeyButton(
                                                '2', controller, 16),
                                            const SizedBox(width: 8),
                                            _buildKeyButton(
                                                '3', controller, 16),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            _buildKeyButton(
                                                '4', controller, 16),
                                            const SizedBox(width: 8),
                                            _buildKeyButton(
                                                '5', controller, 16),
                                            const SizedBox(width: 8),
                                            _buildKeyButton(
                                                '6', controller, 16),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            _buildKeyButton(
                                                '7', controller, 16),
                                            const SizedBox(width: 8),
                                            _buildKeyButton(
                                                '8', controller, 16),
                                            const SizedBox(width: 8),
                                            _buildKeyButton(
                                                '9', controller, 16),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            _buildKeyButton(
                                                '.', controller, 18),
                                            const SizedBox(width: 8),
                                            _buildKeyButton(
                                                '0', controller, 16),
                                            const SizedBox(width: 8),
                                            _buildClearButton(controller),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  /// Leaderboard Overlay
                  if (_showLeaderboard) _buildLeaderboardOverlay(controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyButton(
      String number, MultiplayerGameController controller, double fontSize) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: () => _onKeyboardTap(number, controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
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

  Widget _buildClearButton(MultiplayerGameController controller) {
    return Expanded(
      child: Material(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: () => _onKeyboardTap('clear', controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: const Icon(
              Icons.backspace_outlined,
              size: 20,
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
                      color: index == 0
                          ? Colors.amber.shade100
                          : Colors.grey.shade100,
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
                            color: index == 0
                                ? Colors.amber.shade900
                                : Colors.black87,
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
                }),
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
        content: Text(
            'Use a hint for this cell? (${controller.hintsRemaining} remaining)\n\nThis will deduct 5 points.'),
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
                        side:
                            const BorderSide(color: Colors.black26, width: 1.5),
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
                        if (controller.isPlaying &&
                            controller.room != null &&
                            !_hasAutoSaved) {
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

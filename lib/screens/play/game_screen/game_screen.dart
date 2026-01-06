import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../dashboard/models/game_models.dart';
import '../controller/game_controller.dart';
import '../submit_game_screen.dart';
import '../widgets/game_helper.dart';
import 'widgets/game_grid_widget.dart';
import 'widgets/game_keyboard_widget.dart';
import 'widgets/game_dailogs.dart';
import 'widgets/result_dailog_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const Color textPink = Color(0xFFF82A87);
  static const Color textGreen = Color(0xFF43AC45);

  final Map<String, TextEditingController> _inputControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _showMinus = false;
  String? _selectedCell;
  bool _isGameStarted = false;

  // Guard variables to prevent infinite loops
  bool _isInitialized = false;
  int? _lastInitializedGridSize;

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (var c in _inputControllers.values) {
      c.dispose();
    }
    for (var n in _focusNodes.values) {
      n.dispose();
    }
    _inputControllers.clear();
    _focusNodes.clear();
  }

  String _getKey(int row, int col) => '$row-$col';

  // This handles the setup of UI controllers for player-input cells
  void _initializeGridState(GameController controller) {
    if (_isInitialized && _lastInitializedGridSize == controller.gridSize) return;

    _disposeControllers();

    for (int i = 0; i < controller.gridSize; i++) {
      for (int j = 0; j < controller.gridSize; j++) {
        if ((i != 0 || j != 0) && !controller.isFixed[i][j]) {
          String key = _getKey(i, j);

          final textController = TextEditingController();
          if (controller.grid[i][j] != null) {
            textController.text = controller.grid[i][j].toString();
          }

          _inputControllers[key] = textController;

          final node = FocusNode();
          node.addListener(() {
            if (node.hasFocus) {
              Future.microtask(() {
                if (mounted && _selectedCell != key) {
                  setState(() => _selectedCell = key);
                }
              });
            }
          });
          _focusNodes[key] = node;
        }
      }
    }
    _lastInitializedGridSize = controller.gridSize;
    _isInitialized = true;
  }

  Future<bool> _onWillPop(GameController controller) async {
    if (!_isGameStarted) return true;
    final shouldLeave = await GameDialogs.showAbandonGameDialog(context, controller);
    return shouldLeave ?? false;
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
        controller.updateCell(row, col, newText.isEmpty ? null : int.tryParse(newText));
      }
    } else {
      final currentText = _inputControllers[_selectedCell]?.text ?? '';
      final newText = currentText + value;

      if (newText.length <= 3) {
        _inputControllers[_selectedCell]?.text = newText;
        final newVal = int.tryParse(newText);
        if (newVal != null) {
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
    }

    if (allFilled && _isGameStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStopGameDialog(context, controller);
      });
    }
  }

  void _showStopGameDialog(BuildContext context, GameController controller) {
    GameDialogs.showStopGameDialog(context, controller, () async {
      setState(() => _isGameStarted = false);
      controller.validateGrid();
      await _saveGameToBackend(context, controller, 'completed');
    });
  }

  Future<void> _saveGameToBackend(BuildContext context, GameController controller, String status) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await GameSaveHelper().saveSoloGame(controller: controller, gameStatus: status);
      if (mounted) Navigator.pop(context);

      if (result['success']) {
        _showResultDialog(context, controller, savedGame: result['game'], pointsEarned: result['pointsEarned']);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showResultDialog(BuildContext context, GameController controller, {Game? savedGame, int? pointsEarned}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResultDialogWidget(
        controller: controller,
        savedGame: savedGame,
        pointsEarned: pointsEarned,
        onClose: () {
          // 1. Close the Dialog
          Navigator.pop(ctx);

          // 2. Reset the game state so the user can play again or leave
          _handleReset(controller);

          // Optional: If you want to take them back to a specific screen automatically
          // Navigator.of(context).pop();
        },
      ),
    );
  }

  void _handleReset(GameController controller) {
    _isInitialized = false;
    controller.resetGame();
    setState(() => _selectedCell = null);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameController(gridSize: 4),
      child: Consumer<GameController>(
        builder: (context, controller, _) {
          // Initialize logic remains here
          if (!controller.isGenerating) {
            _initializeGridState(controller);
          }

          return WillPopScope(
            onWillPop: () => _onWillPop(controller),
            child: Scaffold(
              // The Scaffold remains constant, preventing the black screen/flicker
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFC0CB), Color(0xFFADD8E6), Color(0xFFE6E6FA)],
                  ),
                ),
                child: SafeArea(
                  child: Stack( // Use Stack to layer content and loader
                    children: [
                      // Layer 1: The Main Game UI
                      Opacity(
                        // Optional: Slightly dim the UI while generating
                        opacity: controller.isGenerating ? 0.3 : 1.0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final h = constraints.maxHeight;
                            final w = constraints.maxWidth;

                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildHeader(w, h, controller),
                                  _buildStatsBar(w, h, controller),
                                  _buildControls(w, h, controller),
                                  SizedBox(height: h * 0.02),
                                  GameGridWidget(
                                    controller: controller,
                                    inputControllers: _inputControllers,
                                    focusNodes: _focusNodes,
                                    showMinus: _showMinus,
                                    isGameStarted: _isGameStarted,
                                    onOperationToggle: (val) {
                                      setState(() {
                                        _showMinus = val;
                                        _isInitialized = false;
                                      });
                                      controller.setOperation(val ? PuzzleOperation.subtraction : PuzzleOperation.addition);
                                      setState(() => _selectedCell = null);
                                    },
                                    screenHeight: h,
                                    screenWidth: w,
                                  ),
                                  SizedBox(height: h * 0.02),
                                  GameKeyboardWidget(
                                    controller: controller,
                                    isGameStarted: _isGameStarted,
                                    onKeyTap: (val) => _onKeyboardTap(val, controller),
                                    screenHeight: h,
                                    screenWidth: w,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Layer 2: The Loader (Only shows when generating)
                      if (controller.isGenerating)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFC42AF8), // textPink
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(double w, double h, GameController controller) {
    return Padding(
      padding: EdgeInsets.all(w * 0.03),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (await _onWillPop(controller) && mounted) Navigator.pop(context);
            },
            icon: const CircleAvatar(backgroundColor: textPink, child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
          ),
          const Spacer(),
          Text("Jol Puzzle", style: TextStyle(fontSize: h * 0.035, fontWeight: FontWeight.bold)),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildStatsBar(double w, double h, GameController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.05),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: textPink, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Centered now that Hint is gone
                children: [
                  Text(controller.mode == GameMode.timed
                      ? "Time: ${controller.timeLeft.inMinutes}:${(controller.timeLeft.inSeconds % 60).toString().padLeft(2, '0')}"
                      : "Mode: Untimed",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isGameStarted ? null : () => controller.toggleMode(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _isGameStarted ? Colors.grey : textGreen, borderRadius: BorderRadius.circular(10)),
              child: Icon(controller.mode == GameMode.timed ? Icons.timer : Icons.timer_off, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildControls(double w, double h, GameController controller) {
    return Padding(
      padding: EdgeInsets.fromLTRB(w * 0.05, 10, w * 0.05, 0),
      child: Row(
        children: [
          _actionBtn("Reset", Icons.refresh, Colors.orange, _isGameStarted ? null : () => _handleReset(controller)),
          const SizedBox(width: 8),
          // Hint button removed from here
          _actionBtn(_isGameStarted ? "Stop" : "Start", Icons.play_arrow, _isGameStarted ? Colors.orange : textGreen, () {
            if (_isGameStarted) {
              _showStopGameDialog(context, controller);
            } else {
              setState(() => _isGameStarted = true);
              // THIS LINE IS CRITICAL:
              controller.startGame();
              if (controller.mode == GameMode.timed) controller.startTimer();
            }
          }),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback? onPressed) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
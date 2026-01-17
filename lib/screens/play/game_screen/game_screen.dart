import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../dashboard/models/game_models.dart';
import '../controller/game_controller.dart';
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

  // New flag: true when game is finished but user hasn't pressed 'Reset' yet
  bool _needsReset = false;

  // Guard variables to prevent infinite loops
  bool _isInitialized = false;
  int? _lastInitializedGridSize;
  // Ensure end-game dialog flow runs only once per game end
  bool _endDialogShown = false;

  bool _isProcessingEnd =
      false; // New flag to prevent multiple end-game processes

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

  //parsing helper method
  /// Safely parses input string to double with rounding to prevent floating-point issues
  double? safeParse(String? text, {int decimalPlaces = 1}) {
    if (text == null || text.trim().isEmpty) return null;

    String cleaned = text.trim();

    // Handle incomplete decimal like "12." → treat as "12.0"
    if (cleaned.endsWith('.')) {
      cleaned += '0';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;

    // Round to desired precision (1 decimal is usually enough for your game)
    final factor = pow(10, decimalPlaces).toDouble();
    return (parsed * factor).round() / factor;
  }

  String _getKey(int row, int col) => '$row-$col';

  String _formatNumber(double? value) {
    if (value == null) return "";
    // If it's a whole number, show without decimal
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    // Otherwise show with decimal
    return value.toStringAsFixed(1);
  }

  void _initializeGridState(GameController controller) {
    // Don't reinitialize while game is running
    if (_isGameStarted) return;

    if (_isInitialized && _lastInitializedGridSize == controller.gridSize)
      return;

    _disposeControllers();

    for (int i = 0; i < controller.gridSize; i++) {
      for (int j = 0; j < controller.gridSize; j++) {
        if ((i != 0 || j != 0) && !controller.isFixed[i][j]) {
          String key = _getKey(i, j);

          final textController = TextEditingController();
          if (controller.grid[i][j] != null) {
            textController.text = _formatNumber(controller.grid[i][j]);
          }

          _inputControllers[key] = textController;

          final node = FocusNode();
          node.addListener(() {
            if (node.hasFocus) {
              debugPrint(
                  'FocusNode gained focus for $key; _selectedCell=$_selectedCell');
              // Schedule the selection update to the next frame to avoid timing races
              if (mounted) {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedCell != key)
                    setState(() => _selectedCell = key);
                });
              }
            } else {
              // Finalize input on focus loss
              try {
                controller.finalizeCellInput(
                    i, j, _inputControllers[key]?.text ?? '');
              } catch (_) {}
              // Clear selection if this node lost focus and it was selected
              if (mounted && _selectedCell == key)
                setState(() => _selectedCell = null);
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
    final shouldLeave =
        await GameDialogs.showAbandonGameDialog(context, controller);
    return shouldLeave ?? false;
  }

  void _onKeyboardTap(String value, GameController controller) {
    // Block input if game not active or already finished/reviewing
    if (!_isGameStarted || _needsReset) return;

    final selected = _selectedCell;
    if (selected == null) return;

    final parts = selected.split('-');
    final row = int.parse(parts[0]);
    final col = int.parse(parts[1]);

    // Fixed cells are not editable
    if (controller.isFixed[row][col]) return;

    final textController = _inputControllers[selected];
    final focusNode = _focusNodes[selected];

    // Safety: skip if no controller or not focused
    if (textController == null || !(focusNode?.hasFocus ?? false)) return;

    // Clear wrong mark (we don't do live validation)
    controller.isWrong[row][col] = false;

    // ─────────────── CLEAR (Backspace) ───────────────
    if (value == 'clear') {
      if (textController.text.isEmpty) return;

      final newText =
          textController.text.substring(0, textController.text.length - 1);
      textController.text = newText;

      // Update model with safely parsed value (null if empty)
      final parsed = safeParse(newText);
      controller.grid[row][col] =
          parsed; // direct grid update (or use updateRawInput if you keep it)
      controller.notifyListeners();

      _checkIfAllCellsFilled(controller);
      return;
    }

    // ─────────────── NUMBER / DECIMAL INPUT ───────────────
    String currentText = textController.text;
    String newText = currentText + value;

    // Prevent multiple dots
    if (value == '.') {
      if (!controller.useDecimals ||
          currentText.contains('.') ||
          currentText.isEmpty) {
        return;
      }
    }

    // Length & format guard
    if (newText.length > 8) return; // generous limit
    if (newText.replaceAll('.', '').length > 6) return; // e.g. 9999.99

    // Apply new text to UI immediately
    textController.text = newText;

    // Safely parse and round the value
    final parsedValue = safeParse(newText);

    if (parsedValue != null) {
      // Update model
      controller.grid[row][col] = parsedValue;
      // If you still want to keep raw input:
      // controller.updateRawInput(row, col, newText);

      controller.notifyListeners();
    }

    // Check if puzzle is complete (after valid input)
    _checkIfAllCellsFilled(controller);
  }

  // bool _checkIfAllCellsFilled(GameController controller) {
  //   for (int i = 0; i < controller.gridSize; i++) {
  //     for (int j = 0; j < controller.gridSize; j++) {
  //       if (i == 0 && j == 0) continue;
  //       if (controller.grid[i][j] == null) return false;
  //     }
  //   }
  //   return true;
  // }

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
      _isProcessingEnd = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStopGameDialog(context, controller);
      });
    }
  }

  void _onCellChanged(int row, int col, GameController controller) {
    final key = _getKey(row, col);
    final text = _inputControllers[key]?.text ?? '';
    controller.updateRawInput(row, col, text);

    // If validation finished the game, show the stop dialog.
    // Do not rely on validateGrid() return value — check controller.isPlaying.
    // if (!controller.isPlaying) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     _showStopGameDialog(context, controller);
    //   });
    //}
  }

  void _showStopGameDialog(BuildContext context, GameController controller) {
    GameDialogs.showStopGameDialog(context, controller, () async {
      // STOP THE TIMER IMMEDIATELY
      controller.stopTimer();

      controller.endGame();

      setState(() {
        _isGameStarted = false;
        _needsReset = true;
      });

      await _saveGameToBackend(context, controller, 'completed');
    });
  }

  Future<void> _saveGameToBackend(
      BuildContext context, GameController controller, String status) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await GameSaveHelper()
          .saveSoloGame(controller: controller, gameStatus: status);
      if (mounted) Navigator.pop(context);

      if (result['success']) {
        _showResultDialog(context, controller,
            savedGame: result['game'], pointsEarned: result['pointsEarned']);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    } finally {
      _isProcessingEnd = false; // Reset the processing flag
    }
  }

  void _showResultDialog(BuildContext context, GameController controller,
      {Game? savedGame, int? pointsEarned}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResultDialogWidget(
        controller: controller,
        savedGame: savedGame,
        pointsEarned: pointsEarned,
        onClose: () {
          Navigator.pop(ctx);
          _handleReset(controller); // This cleans the board for a new game
        },
      ),
    );
  }

  void _handleReset(GameController controller) {
    _isInitialized = false;
    _endDialogShown = false;
    controller.resetGame();
    setState(() {
      _selectedCell = null;
      _needsReset = false; // Reset the review flag
      _isGameStarted = false;
    });
  }

  void autoEndGameFlow(GameController controller) {
    // 1. Force state updates
    setState(() {
      _isGameStarted = false;
      _needsReset = true;
    });

    // 2. Stop controller and calculate final scores
    controller.stopTimer();
    controller.endGame();

    // 3. Save and Show Dialog
    _saveGameToBackend(context, controller, 'completed');
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameController(gridSize: 4),
      child: Consumer<GameController>(
        builder: (context, controller, _) {
          if (!controller.isGenerating) {
            _initializeGridState(controller);
          }

          // If controller stopped while UI still thinks game is running,
          // run the end-game save/results flow once (no confirmation).
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            debugPrint('''
              AUTO-END CHECK TRIGGERED:
             _isGameStarted     : $_isGameStarted
               controller.isPlaying: ${controller.isPlaying}
               _needsReset        : $_needsReset
               _endDialogShown    : $_endDialogShown
               _isProcessingEnd   : $_isProcessingEnd
              ''');
            // Game ended (by timer or manual stop) but UI still thinks it's running
            if (_isGameStarted && !controller.isPlaying && !_needsReset) {
              // Prevent multiple triggers
              if (_endDialogShown || _isProcessingEnd) return;

              _endDialogShown = true;
              _isProcessingEnd = true;

              // Immediately update UI state
              setState(() {
                _isGameStarted = false;
                _needsReset = true;
              });
              debugPrint(
                  "!!! PREMATURE RESET DETECTED HERE !!! Caller: ${StackTrace.current}");

              if (mounted && !_isProcessingEnd) {
                _isProcessingEnd = true;
                debugPrint("→ Calling _showStopGameDialog");
                _showStopGameDialog(context, controller);
              }

              // Run the full end flow
              _showStopGameDialog(context, controller);
            }
          });

          return WillPopScope(
            onWillPop: () => _onWillPop(controller),
            child: Scaffold(
              body: Container(
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFC0CB),
                      Color(0xFFADD8E6),
                      Color(0xFFE6E6FA)
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      Opacity(
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
                                    screenHeight: h,
                                    screenWidth: w,
                                    inputControllers: _inputControllers,
                                    focusNodes: _focusNodes,
                                    showMinus: _showMinus,
                                    isGameStarted: _isGameStarted,
                                    onOperationToggle: (val) {
                                      setState(() {
                                        _showMinus = val;
                                        _isInitialized = false;
                                      });
                                      controller.setOperation(val
                                          ? PuzzleOperation.subtraction
                                          : PuzzleOperation.addition);
                                      setState(() => _selectedCell = null);
                                    },
                                    onCellTap: (row, col) {
                                      final key = _getKey(row, col);

                                      // 1. Ensure controller exists
                                      if (!_inputControllers.containsKey(key)) {
                                        final tc = TextEditingController();
                                        _inputControllers[key] = tc;
                                      } // Fixed: added closing brace for if

                                      // 2. Ensure focus node exists and attach listener
                                      if (!_focusNodes.containsKey(key)) {
                                        final node = FocusNode();
                                        node.addListener(() {
                                          if (node.hasFocus) {
                                            debugPrint(
                                                'FocusNode gained focus for $key; _selectedCell=$_selectedCell');
                                            if (mounted) {
                                              SchedulerBinding.instance
                                                  .addPostFrameCallback((_) {
                                                if (mounted &&
                                                    _selectedCell != key) {
                                                  setState(() =>
                                                      _selectedCell = key);
                                                }
                                              });
                                            }
                                          } else {
                                            // Finalize input on focus loss
                                            try {
                                              controller.finalizeCellInput(
                                                  row,
                                                  col,
                                                  _inputControllers[key]
                                                          ?.text ??
                                                      '');
                                            } catch (_) {}
                                            if (mounted &&
                                                _selectedCell == key) {
                                              setState(
                                                  () => _selectedCell = null);
                                            }
                                          }
                                        });
                                        _focusNodes[key] = node;
                                      } // Fixed: added closing brace for if

                                      // 3. Select and request focus
                                      setState(() => _selectedCell = key);
                                      Future.microtask(() =>
                                          _focusNodes[key]?.requestFocus());
                                    }, // Fixed: added closing brace and comma for onCellTap
                                  ),
                                  SizedBox(height: h * 0.02),
                                  GameKeyboardWidget(
                                    controller: controller,
                                    isGameStarted: _isGameStarted,
                                    onKeyTap: (val) =>
                                        _onKeyboardTap(val, controller),
                                    onDecimalToggle: (useDecimals) =>
                                        controller.setUseDecimals(useDecimals),
                                    screenHeight: h,
                                    screenWidth: w,
                                  ),
                                  SizedBox(height: h * 0.02),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (controller.isGenerating)
                        const Center(
                          child: CircularProgressIndicator(
                            color: textPink,
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
              if (await _onWillPop(controller) && mounted)
                Navigator.pop(context);
            },
            icon: const CircleAvatar(
                backgroundColor: textPink,
                child: Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18)),
          ),
          const Spacer(),
          const Text("Jol Puzzle",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildControls(double w, double h, GameController controller) {
    return Padding(
      padding: EdgeInsets.fromLTRB(w * 0.05, 10, w * 0.05, 0),
      child: Row(
        children: [
          _actionBtn("Reset", Icons.refresh, Colors.orange,
              _isGameStarted ? null : () => _handleReset(controller)),
          const SizedBox(width: 8),
          _actionBtn(
              _isGameStarted ? "Stop" : "Start",
              Icons.play_arrow,
              _isGameStarted ? Colors.orange : textGreen,
              (_needsReset && !_isGameStarted)
                  ? null
                  : () {
                      // Disable Start button if needs reset
                      if (_isGameStarted) {
                        _showStopGameDialog(context, controller);
                      } else {
                        setState(() {
                          _isGameStarted = true;
                          _needsReset = false;
                          _endDialogShown = false;
                        });
                        controller.startGame();
                        if (controller.mode == GameMode.timed)
                          controller.startTimer();
                      }
                    }),
        ],
      ),
    );
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback? onPressed) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: Colors.grey.shade400,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(
                  color: textPink, borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  controller.mode == GameMode.timed
                      ? "Time: ${controller.timeLeft.inMinutes}:${(controller.timeLeft.inSeconds % 60).toString().padLeft(2, '0')}"
                      : "Mode: Untimed",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: (_isGameStarted || _needsReset)
                ? null
                : () => controller.toggleMode(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color:
                      (_isGameStarted || _needsReset) ? Colors.grey : textGreen,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  controller.mode == GameMode.timed
                      ? Icons.timer
                      : Icons.timer_off,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          toggleButton(controller), // Hard mode toggle
        ],
      ),
    );
  }

  //toggle button for hard mode
  Widget toggleButton(GameController controller) {
    final bool enabled = !_isGameStarted && !_needsReset;

    return GestureDetector(
      onTap: enabled
          ? () {
              controller.setHardMode(!controller.hardMode);
              controller.resetGame();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: controller.hardMode ? textPink : Colors.grey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Hard',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

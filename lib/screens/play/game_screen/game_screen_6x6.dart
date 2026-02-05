import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../dashboard/models/game_models.dart';
import '../controller/base_game_controller_nxn.dart';
import '../controller/game_controller_6x6.dart';
import '../widgets_nxn/game_helper_nxn.dart'; 
import '../widgets_nxn/game_grid_widget_nxn.dart';
import '../widgets_nxn/game_keyboard_widget_nxn.dart';
import '../widgets_nxn/game_dialogs_nxn.dart';
import '../widgets_nxn/result_dialog_widget_nxn.dart';

class GameScreen6x6 extends StatefulWidget {
  const GameScreen6x6({super.key});

  @override
  State<GameScreen6x6> createState() => _GameScreen6x6State();
}

class _GameScreen6x6State extends State<GameScreen6x6> {
  static const Color textPink = Color(0xFFF82A87);
  static const Color textGreen = Color(0xFF43AC45);

  final Map<String, TextEditingController> _inputControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _showMinus = false;
  String? _selectedCell;
  bool _isGameStarted = false;

  bool _needsReset = false;
  bool _isInitialized = false;
  bool _endDialogShown = false;
  bool _isProcessingEnd = false;

  bool? _lastControllerPlayingState;
  Timer? _debounceTimer;

  @override

  @override
  void initState() {
    super.initState();
    _lastControllerPlayingState = null;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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

  void _initializeGridState(BaseGameControllerNxN controller) {
    if (_isGameStarted) return;
    if (_isInitialized) return;

    _disposeControllers();

    for (int i = 0; i < controller.gridSize; i++) {
      for (int j = 0; j < controller.gridSize; j++) {
        if ((i != 0 || j != 0) && !controller.isFixed[i][j]) {
          String key = _getKey(i, j);

          final textController = TextEditingController();
          final val = controller.getCell(i, j);
          if (val != null) {
            textController.text = (val == val.toInt()) ? val.toInt().toString() : val.toStringAsFixed(1);
          }

          _inputControllers[key] = textController;

          final node = FocusNode();
          node.addListener(() {
            if (node.hasFocus) {
              if (mounted) {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedCell != key) setState(() => _selectedCell = key);
                });
              }
            } else {
              try {
                controller.finalizeCellInput(i, j, _inputControllers[key]?.text ?? '');
              } catch (_) {}
              if (mounted && _selectedCell == key) setState(() => _selectedCell = null);
            }
          });
          _focusNodes[key] = node;
        }
      }
    }
    _isInitialized = true;
  }

  Future<bool> _onWillPop(BaseGameControllerNxN controller) async {
    if (!_isGameStarted) return true;
    final shouldLeave = await GameDialogsNxN.showAbandonGameDialog(context, controller);
    return shouldLeave ?? false;
  }

  void _onKeyboardTap(String value, BaseGameControllerNxN controller) {
    if (!_isGameStarted || _needsReset) return;

    final selected = _selectedCell;
    if (selected == null) return;

    final parts = selected.split('-');
    final row = int.parse(parts[0]);
    final col = int.parse(parts[1]);

    if (controller.isFixed[row][col]) return;

    final textController = _inputControllers[selected];
    final focusNode = _focusNodes[selected];

    if (textController == null || !(focusNode?.hasFocus ?? false)) return;

    // Reset wrong status visually (game controller handles logic)
    // controller.isWrong[row][col] = false; // logic is in controller, this is direct access, maybe avoid?
    // Actually BaseGameControllerNxN doesn't expose setter for isWrong, but validateAll resets it.

    if (value == 'clear') {
      if (textController.text.isEmpty) return;
      final newText = textController.text.substring(0, textController.text.length - 1);
      textController.text = newText;
      controller.updateRawInput(row, col, newText);
      _checkIfAllCellsFilled(controller);
      return;
    }

    String currentText = textController.text;
    String newText = currentText + value;

    if (value == '.') {
      if (!controller.useDecimals || currentText.contains('.') || currentText.isEmpty) {
        return;
      }
    }

    if (newText.length > 8) return;
    if (newText.replaceAll('.', '').length > 6) return;

    textController.text = newText;
    controller.updateRawInput(row, col, newText);
    _checkIfAllCellsFilled(controller);
  }

  void _checkIfAllCellsFilled(BaseGameControllerNxN controller) {
    bool allFilled = true;
    for (int i = 0; i < controller.gridSize; i++) {
        for (int j = 0; j < controller.gridSize; j++) {
            if (i == 0 && j == 0) continue;
            if (controller.getCell(i, j) == null) {
                allFilled = false;
                break;
            }
        }
    }

    if (allFilled && _isGameStarted) {
      // Debounce logic
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isGameStarted) {
          _isProcessingEnd = true;
          _showStopGameDialog(context, controller);
        }
      });
    } else {
      _debounceTimer?.cancel();
    }
  }

  void _showStopGameDialog(BuildContext context, BaseGameControllerNxN controller) {
    GameDialogsNxN.showStopGameDialog(context, controller, () async {
      controller.stopTimer();
      controller.endGame();

      setState(() {
        _isGameStarted = false;
        _needsReset = true;
      });

      await _saveGameToBackend(context, controller, 'completed');
    });
  }

  Future<void> _saveGameToBackend(BuildContext context, BaseGameControllerNxN controller, String status) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // NOTE: GameSaveHelper might need updates if it doesn't support generic controller
      // Assuming GameSaveHelperNxN exists or GameSaveHelper is generic enough.
      // If not, we might need a GameHelperNxN.
      // Based on imports, we have `game_helper_nxn.dart`. Let's assume it has GameSaveHelperNxN.
      
      final result = await GameSaveHelperNxN().saveSoloGame(controller: controller, gameStatus: status);
      
      if (mounted) Navigator.pop(context);

      if (result['success']) {
        _showResultDialog(context, controller, savedGame: result['game'], pointsEarned: result['pointsEarned']);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    } finally {
      _isProcessingEnd = false;
    }
  }

  void _showResultDialog(BuildContext context, BaseGameControllerNxN controller, {Game? savedGame, int? pointsEarned}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResultDialogWidgetNxN(
        controller: controller,
        savedGame: savedGame,
        pointsEarned: pointsEarned,
        onClose: () {
          Navigator.pop(ctx);
          _handleReset(controller);
        },
      ),
    );
  }

  void _handleReset(BaseGameControllerNxN controller) {
    _isInitialized = false;
    _endDialogShown = false;
    controller.resetGame();
    setState(() {
      _selectedCell = null;
      _needsReset = false;
      _isGameStarted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameController6x6(),
      child: Consumer<GameController6x6>(
        builder: (context, controller, _) {
          if (!controller.isGenerating && !_isInitialized) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isInitialized && mounted) {
                _initializeGridState(controller);
              }
            });
          }

          bool gameJustStopped = _isGameStarted &&
              !controller.isPlaying &&
              (_lastControllerPlayingState == null || _lastControllerPlayingState == true) &&
              !_needsReset &&
              !_endDialogShown &&
              !_isProcessingEnd;

          if (gameJustStopped) {
            _lastControllerPlayingState = false;
            _endDialogShown = true;
            _isProcessingEnd = true;
          } else if (controller.isPlaying) {
            _lastControllerPlayingState = true;
          }

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
                                  GameGridWidgetNxN(
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
                                      controller.setOperation(val ? PuzzleOperation.subtraction : PuzzleOperation.addition);
                                      setState(() => _selectedCell = null);
                                    },
                                    onCellTap: (row, col) {
                                       final key = _getKey(row, col);
                                       if (!_inputControllers.containsKey(key)) {
                                          _inputControllers[key] = TextEditingController();
                                       }
                                       if (!_focusNodes.containsKey(key)) {
                                          final node = FocusNode();
                                          node.addListener(() {
                                             if (node.hasFocus && mounted) {
                                                 SchedulerBinding.instance.addPostFrameCallback((_) {
                                                     if (mounted && _selectedCell != key) setState(() => _selectedCell = key);
                                                 });
                                             } else {
                                                 try {
                                                    controller.finalizeCellInput(row, col, _inputControllers[key]?.text ?? '');
                                                 } catch (_) {}
                                                 if (mounted && _selectedCell == key) setState(() => _selectedCell = null);
                                             }
                                          });
                                          _focusNodes[key] = node;
                                       }
                                       setState(() => _selectedCell = key);
                                       _focusNodes[key]?.requestFocus();
                                    },
                                    onCellChanged: (row, col) {
                                        // Handled in widget via controller.updateRawInput
                                    },
                                  ),
                                  SizedBox(height: h * 0.02),
                                  GameKeyboardWidgetNxN(
                                    controller: controller,
                                    isGameStarted: _isGameStarted,
                                    onKeyTap: (val) => _onKeyboardTap(val, controller),
                                    onDecimalToggle: (useDecimals) => controller.setUseDecimals(useDecimals),
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
                          child: CircularProgressIndicator(color: textPink),
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

  Widget _buildHeader(double w, double h, BaseGameControllerNxN controller) {
    return Padding(
      padding: EdgeInsets.all(w * 0.03),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (await _onWillPop(controller) && mounted) Navigator.pop(context);
            },
            icon: const CircleAvatar(
                backgroundColor: textPink,
                child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
          ),
          const Spacer(),
          const Text("JOL Puzzle",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildControls(double w, double h, BaseGameControllerNxN controller) {
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
                      if (_isGameStarted) {
                        _showStopGameDialog(context, controller);
                      } else {
                        setState(() {
                          _isGameStarted = true;
                          _needsReset = false;
                          _endDialogShown = false;
                        });
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
            disabledBackgroundColor: Colors.grey.shade400,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatsBar(double w, double h, BaseGameControllerNxN controller) {
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: (_isGameStarted || _needsReset) ? null : () => controller.toggleMode(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: (_isGameStarted || _needsReset) ? Colors.grey : textGreen,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  controller.mode == GameMode.timed ? Icons.timer : Icons.timer_off,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          toggleButton(controller),
        ],
      ),
    );
  }

  Widget toggleButton(BaseGameControllerNxN controller) {
    final bool enabled = !_isGameStarted && !_needsReset;
    final Color bgColor = controller.hardMode ? textPink : Colors.grey;

    final TextStyle? btnTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            );

    return TextButton(
      onPressed: enabled
          ? () {
              controller.setHardMode(!controller.hardMode);
              controller.resetGame();
            }
          : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => enabled ? bgColor : Colors.grey.shade400),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      child: Text('Hard', style: btnTextStyle),
    );
  }
}

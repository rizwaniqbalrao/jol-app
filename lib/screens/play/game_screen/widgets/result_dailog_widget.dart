import 'package:flutter/material.dart';
import '../../../dashboard/models/game_models.dart';
import '../../controller/game_controller.dart';

class ResultDialogWidget extends StatelessWidget {
  final GameController controller;
  final Game? savedGame;
  final int? pointsEarned;
  final VoidCallback onClose;

  static const Color primaryBlue = Color(0xFF0734A5);
  static const Color successGreen = Color(0xFF43AC45);
  static const Color accentPink = Color(0xFFF82A87);
  static const Color neutralBg = Color(0xFFF8F9FE);

  const ResultDialogWidget({
    Key? key,
    required this.controller,
    this.savedGame,
    this.pointsEarned,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accuracy = savedGame?.accuracyPercentage ?? controller.accuracyPercentage;
    final totalCells = (controller.gridSize * controller.gridSize) - 1 - controller.seedNumbers;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none, // Allows the trophy to "pop out" of the stack
        alignment: Alignment.topCenter,
        children: [
          // Main Dialog Container
          Container(
            margin: const EdgeInsets.only(top: 42), // Creates space for half the icon height
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 60), // Spacing to clear the floating icon
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      const Text(
                        "CHALLENGE COMPLETE",
                         style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 22,
                          color: primaryBlue,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Scoring breakdown wrapped in Builder
                      Builder(
                        builder: (context) {
                          // Calculate scoring breakdown
                          final int correctAnswers = controller.correctAnswers;
                          final int baseScore = correctAnswers * 5;
                          final int timeRemaining = controller.timeLeft.inSeconds;
                          final int timeBonus = controller.mode == GameMode.timed 
                              ? timeRemaining * 2 
                              : 0;
                          final double multiplier = controller.getMultiplier();
                          final int totalScore = savedGame?.finalScore ?? controller.score;

                          return Column(
                            children: [
                              // Main Score Display
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [primaryBlue, Color(0xFF0A4DBF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      "FINAL SCORE",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "$totalScore",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontFamily: 'Digitalt',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      height: 1,
                                      color: Colors.white24,
                                    ),
                                    const SizedBox(height: 16),
                                    // Score breakdown
                                    _buildScoreBreakdownRow(
                                      "Base Score",
                                      "$correctAnswers × 10",
                                      "$baseScore",
                                    ),
                                    if (controller.mode == GameMode.timed) ...[
                                      const SizedBox(height: 8),
                                      _buildScoreBreakdownRow(
                                        "Time Bonus",
                                        "${timeRemaining}s / 15",
                                        "+$timeBonus",
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    _buildScoreBreakdownRow(
                                      "Multiplier",
                                      _getMultiplierDescription(multiplier),
                                      "×${multiplier.toStringAsFixed(1)}",
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Additional Stats Container
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: neutralBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildSubStat("Accuracy", "${accuracy.toStringAsFixed(0)}%", accentPink),
                                    _buildVerticalDivider(),
                                    _buildSubStat("Correct", "${controller.correctAnswers}/${controller.totalPlayerCells}", successGreen),
                                    if (savedGame?.completionTime != null) ...[
                                      _buildVerticalDivider(),
                                      _buildSubStat("Time", _formatTime(savedGame!.completionTime!), Colors.orange),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Sugar-coated Persistence Message
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.history_toggle_off_rounded, color: primaryBlue.withOpacity(0.6), size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Your achievement has been archived in your dashboard history for future review.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF556080),
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Primary Dismiss Button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: onClose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            "PLAY ANOTHER GAME",
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontSize: 16,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ADD THIS: Close Icon at Top Right
          Positioned(
            top: 52, // Adjusted to clear the floating trophy space
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28),
              onPressed: () => Navigator.pop(context), // Just close, no reset
            ),
          ),


          // Floating Trophy Icon (Layered on top)
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [successGreen, Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdownRow(String label, String calculation, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                calculation,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Digitalt',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMultiplierDescription(double multiplier) {
    final gridSize = controller.gridSize;
    final useDecimals = controller.useDecimals;
    final hardMode = controller.hardMode;
    
    String difficulty = "";
    if (useDecimals && hardMode) {
      difficulty = "Decimal Hard";
    } else if (useDecimals) {
      difficulty = "Decimal Easy";
    } else if (hardMode) {
      difficulty = "Integer Hard";
    } else {
      difficulty = "Integer Easy";
    }
    
    return "${gridSize}×$gridSize $difficulty";
  }

  Widget _buildMainStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8
            )),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
                color: color,
                fontSize: 30,
                fontFamily: 'Digitalt'
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSubStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontFamily: 'Digitalt')),
      ],
    );
  }

  Widget _buildVerticalDivider() => Container(height: 24, width: 1.5, color: Colors.grey.withOpacity(0.15));

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

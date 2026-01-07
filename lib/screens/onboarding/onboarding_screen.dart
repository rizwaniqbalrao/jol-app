import 'package:flutter/material.dart';
import 'package:jol_app/screens/auth/login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  // Colors from splash screen
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFC42AF8);

  // Font size for logo
  static const double logoFontSize = 90;

  TextSpan _coloredLetter(String letter, int index) {
    final colors = [textBlue, textGreen, textPink];
    return TextSpan(
      text: letter,
      style: const TextStyle(
        fontFamily: 'Digitalt',
        fontWeight: FontWeight.w500,
        height: 0.82, // 🔑 forces even tighter vertical spacing
      ).copyWith(
        color: colors[index % 3],
        fontSize: logoFontSize,
        letterSpacing: logoFontSize * 0.04,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding =
        MediaQuery.of(context).padding.top + 40; // dynamic + extra space

    final combinedText = <TextSpan>[
      _coloredLetter('J', 0),
      _coloredLetter('O', 1),
      _coloredLetter('L', 2),
      const TextSpan(text: '\n'),
      _coloredLetter('P', 3),
      _coloredLetter('U', 4),
      _coloredLetter('Z', 5),
      _coloredLetter('Z', 6),
      _coloredLetter('L', 7),
      _coloredLetter('E', 8),
      _coloredLetter('S', 9),
    ];

    return Scaffold(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top left-aligned logo text with better top spacing
            Padding(
              padding: EdgeInsets.only(top: topPadding, left: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(children: combinedText),
                  textAlign: TextAlign.start,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                ),
              ),
            ),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const HelpDialog(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textBlue,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.question_mark,
                        color: Colors.white, size: 26),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: textPink,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 70, vertical: 15),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => showSettingsDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textGreen,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.settings,
                        color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  double volume = 0.5;
  double music = 0.5;
  bool hapticEnabled = true;

  // Colors from your palette
  static const Color textPink = Color(0xFFC42AF8);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textBlue = Color(0xFF0734A5);
  static const Color settingsOrange = Color(0xFFF47A62);

  @override
  Widget build(BuildContext context) {
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
                // Title
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: settingsOrange,
                  ),
                ),
                const SizedBox(height: 20),

                // Volume Slider
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // center horizontally
                  children: [
                    const Icon(Icons.volume_up, color: textPink),
                    const SizedBox(width: 12), // spacing between icon & slider
                    SizedBox(
                      width: 200,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 16,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 12,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: volume,
                          onChanged: (value) => setState(() => volume = value),
                          activeColor: textPink,
                          inactiveColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

// Music Slider
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // center horizontally
                  children: [
                    const Icon(Icons.music_note_outlined, color: textGreen),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 16,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 12,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: music,
                          onChanged: (value) => setState(() => music = value),
                          activeColor: textGreen,
                          inactiveColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Haptic Feedback toggle with ON/OFF text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'HAPTIC FEEDBACK',
                      style: const TextStyle(
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

                // Close button
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

          // Top image
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
  showDialog(
    context: context,
    builder: (context) => const SettingsDialog(),
  );
}


class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key});

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  // Brand Colors
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFC42AF8);
  static const Color labelPink = Color(0xFFE961B9);

  int currentPage = 0;

  void nextPage() {
    if (currentPage < 4) {
      setState(() => currentPage++);
    }
  }

  void previousPage() {
    if (currentPage > 0) {
      setState(() => currentPage--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top small handle
            Container(
              width: 80,
              height: 6,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
            ),

            // Title
            Text(
              _pageTitle(currentPage),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),

            // Page content
            _pageContent(currentPage),

            const SizedBox(height: 30),

            // Buttons row
            _buildNavigationButtons(),

            const SizedBox(height: 18),

            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: index == currentPage ? textPink : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    if (currentPage == 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: nextPage,
          style: _btnStyle(textPink),
          child: const Text('Next', style: _btnTextStyle),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: previousPage,
            style: _btnStyle(textBlue),
            child: const Text('Previous', style: _btnTextStyle),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton(
            onPressed: () => currentPage == 4 ? Navigator.pop(context) : nextPage(),
            style: _btnStyle(textPink),
            child: Text(currentPage == 4 ? 'Done' : 'Next', style: _btnTextStyle),
          ),
        ),
      ],
    );
  }

  Widget _pageContent(int page) {
    switch (page) {
      case 0: // A, B and C
        return Column(
          children: [
            _gridContainer([
              [_cell('+', textPink), _cell('B', textGreen), _cell('', textBlue)],
              [_cell('A', textGreen), _cell('', Colors.white, border: true), _cell('', Colors.white, border: true)],
              [_cell('', textGreen), _cell('C', Colors.white, border: true), _cell('', Colors.white, border: true)],
            ]),
            const SizedBox(height: 20),
            const Text(
              "In the grid, locate point C by drawing a vertical line down from number B and a horizontal line to the right from number A. The intersection of these lines creates point C, forming an inverted 'L' shape connecting A, B, and C.",
              textAlign: TextAlign.center,
              style: _bodyStyle,
            ),
          ],
        );

      case 1: // A+B = C
        return Column(
          children: [
            _gridContainer([
              [_cell('+', textPink), _cell('', textGreen), _cell('4', textBlue)],
              [_cell('6', textGreen), _cell('', Colors.white, border: true), _cell('10', Colors.white, border: true)],
              [_cell('', textGreen), _cell('', Colors.white, border: true), _cell('', Colors.white, border: true)],
            ]),
            const SizedBox(height: 20),
            const Text(
              "If you have A = 6 and B = 4,\nsimply add A and B to find the value of C.\nIn this case,\n\nC = 6 + 4, which equals 10",
              textAlign: TextAlign.center,
              style: _bodyStyle,
            ),
          ],
        );

      case 2: // B = AC
        return Column(
          children: [
            _gridContainer([
              [_cell('+', textPink), _cell('?', textGreen), _cell('', textBlue)],
              [_cell('6', textGreen), _cell('', Colors.white, border: true), _cell('', Colors.white, border: true)],
              [_cell('5', textGreen), _cell('7', Colors.white, border: true), _cell('', Colors.white, border: true)],
            ]),
            const SizedBox(height: 20),
            const Text(
              "If You have A = 5 and C = 7,\nsimply add A and C to find the value of B.\nIn the case,\n\nB = 5 + 7, which equals 12.",
              textAlign: TextAlign.center,
              style: _bodyStyle,
            ),
          ],
        );

      case 3: // Jol Puzzle
        return Column(
          children: [
            _jolGridWithLabels(),
            const SizedBox(height: 20),
            _instructionBadge("1", "“To find A2, add B2 and C: A2 = B2 + C. For example, If B2 = 3 and C = 4, then A2 = 3+4 = 7.”", textPink),
            _instructionBadge("2", "“With A2 and C, find B1 by adding them: B1 = A2 + C. For example, if A2 = 7 and C = 8, then B1 = 7 + 8 = 15.”", textPink),
            _instructionBadge("3", "“This pattern continues as you progress inn the game.”", const Color(0xFF4DA8FF)),
          ],
        );

      case 4: // Point System
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade50),
              ),
              child: Column(
                children: const [
                  _ScoreRow("Remaining Time:", "120 Sec", isValueRed: true),
                  SizedBox(height: 8),
                  _ScoreRow("Points:", "150", isValueRed: true),
                  SizedBox(height: 8),
                  _ScoreRow("Total Score:", "150", isValueRed: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: _btnStyle(textBlue),
                child: const Text("Check & submit score", style: _btnTextStyle),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "After completing the board, click 'Check & Submit Score' to review. Correct answers yield 100 points each, with an extra point awarded for every remaining second.",
              textAlign: TextAlign.center,
              style: _bodyStyle,
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  String _pageTitle(int page) {
    if (page == 1) return "A+B = C";
    if (page == 2) return "B = AC";
    return ["A, B and C", "", "", "Jol Puzzle", "Point System"][page];
  }

  // ---- Shared Grid Components ----
  Widget _gridContainer(List<List<Widget>> rows) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 2),
      ),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: row.map((cell) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(width: 60, height: 60, child: cell),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  static Widget _cell(String text, Color color, {bool border = false}) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: border ? Border.all(color: Colors.grey.shade300) : null,
        boxShadow: [
          if (color != Colors.white)
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 24, color: Colors.black),
      ),
    );
  }

  // ---- Page 3 Specialized Grid ----
  Widget _jolGridWithLabels() {
    const double size = 60;
    const double gap = 8;
    const labelStyle = TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, fontSize: 18, color: labelPink);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(width: size + 20),
            SizedBox(width: size, child: Center(child: Text("B1", style: labelStyle))),
            SizedBox(width: gap),
            SizedBox(width: size, child: Center(child: Text("B2", style: labelStyle))),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: const [
                SizedBox(height: size + gap),
                SizedBox(height: size, child: Center(child: Text("A1", style: labelStyle))),
                SizedBox(height: gap),
                SizedBox(height: size, child: Center(child: Text("A2", style: labelStyle))),
              ],
            ),
            const SizedBox(width: 8),
            _gridContainer([
              [_cell('+', textPink), _jolCell('15', '7+8='), _cell('3', textGreen)],
              [_jolCell('17', '15+2='), _cell('2', textGreen), _cell('', Colors.white, border: true)],
              [_jolCell('7', '3+4='), _cell('8', textBlue), _cell('4', textPink)],
            ]),
          ],
        ),
      ],
    );
  }

  static Widget _jolCell(String text, String formula) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          Positioned(top: 4, left: 0, right: 0, child: Text(formula, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
          Center(child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Widget _instructionBadge(String num, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // Styles
  static const TextStyle _bodyStyle = TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, height: 1.3, color: Colors.black);
  static const TextStyle _btnTextStyle = TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white);

  ButtonStyle _btnStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label, value;
  final bool isValueRed;
  const _ScoreRow(this.label, this.value, {this.isValueRed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 17, color: Colors.black)),
        Text(value, style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 17, color: isValueRed ? const Color(0xFFFF7088) : Colors.black)),
      ],
    );
  }
}



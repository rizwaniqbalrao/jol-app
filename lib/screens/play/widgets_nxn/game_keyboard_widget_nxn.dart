import 'package:flutter/material.dart';
import '../controller/base_game_controller_nxn.dart';

class GameKeyboardWidgetNxN extends StatelessWidget {
  final BaseGameControllerNxN controller;
  final bool isGameStarted;
  final Function(String) onKeyTap;
  final Function(bool) onDecimalToggle;
  final double screenHeight;
  final double screenWidth;

  const GameKeyboardWidgetNxN({
    super.key,
    required this.controller,
    required this.isGameStarted,
    required this.onKeyTap,
    required this.onDecimalToggle,
    required this.screenHeight,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: screenHeight * 0.30,
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
                        _buildKeyButton('1', keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('2', keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('3', keyHeight, fontSize),
                      ],
                    ),
                  ),
                  SizedBox(height: keyboardConstraints.maxHeight * 0.02),
                  Expanded(
                    child: Row(
                      children: [
                        _buildKeyButton('4', keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('5', keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('6', keyHeight, fontSize),
                      ],
                    ),
                  ),
                  SizedBox(height: keyboardConstraints.maxHeight * 0.02),
                  Expanded(
                    child: Row(
                      children: [
                        _buildKeyButton('7', keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('8', keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('9', keyHeight, fontSize),
                      ],
                    ),
                  ),
                  SizedBox(height: keyboardConstraints.maxHeight * 0.02),
                  Expanded(
                    child: Row(
                      children: [
                        _buildDecimalToggleButton(keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('0', keyHeight, fontSize),
                        SizedBox(width: screenWidth * 0.02),
                        _buildKeyButton('.', keyHeight, fontSize),
                      ],
                    ),
                  ),
                  SizedBox(height: keyboardConstraints.maxHeight * 0.02),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: Container()),
                        SizedBox(width: screenWidth * 0.02),
                        _buildClearButton(keyHeight, iconSize),
                        SizedBox(width: screenWidth * 0.02),
                        Expanded(child: Container()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(String number, double height, double fontSize) {
    return Expanded(
      child: Material(
        color: isGameStarted ? Colors.white : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: isGameStarted ? () => onKeyTap(number) : null,
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
                color: isGameStarted ? Colors.black : Colors.black45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton(double height, double iconSize) {
    return Expanded(
      child: Material(
        color: isGameStarted ? Colors.grey.shade400 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: isGameStarted ? () => onKeyTap('clear') : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(vertical: height * 0.15),
            alignment: Alignment.center,
            child: Icon(
              Icons.backspace_outlined,
              size: iconSize,
              color: isGameStarted ? Colors.black87 : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecimalToggleButton(double height, double fontSize) {
    return Expanded(
      child: Material(
        color: controller.useDecimals
            ? Colors.blue.shade400
            : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: !isGameStarted
              ? () => onDecimalToggle(!controller.useDecimals)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(vertical: height * 0.15),
            alignment: Alignment.center,
            child: Text(
              controller.useDecimals ? 'Decimals' : 'Integars',
              style: TextStyle(
                fontSize: fontSize * 0.7,
                fontWeight: FontWeight.bold,
                color: !isGameStarted
                    ? (controller.useDecimals ? Colors.white : Colors.black87)
                    : Colors.black45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../controller/base_game_controller_nxn.dart';

class GameGridWidgetNxN extends StatelessWidget {
  final BaseGameControllerNxN controller;
  final Map<String, TextEditingController> inputControllers;
  final Map<String, FocusNode> focusNodes;
  final bool showMinus;
  final bool isGameStarted;
  final Function(bool) onOperationToggle;
  final double screenHeight;
  final double screenWidth;
  final Function(int, int)? onCellTap;
  final Function(int, int)? onCellChanged;

  const GameGridWidgetNxN({
    super.key,
    required this.controller,
    required this.inputControllers,
    required this.focusNodes,
    required this.showMinus,
    required this.isGameStarted,
    required this.onOperationToggle,
    required this.screenHeight,
    required this.screenWidth,
    this.onCellTap,
    this.onCellChanged,
  });

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

  @override
  Widget build(BuildContext context) {
    final gridSize = controller.gridSize;

    return Padding(
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
            final availableSize =
                gridConstraints.maxWidth < gridConstraints.maxHeight
                    ? gridConstraints.maxWidth
                    : gridConstraints.maxHeight;

            final spacing = availableSize * 0.02;
            final cellSize = (availableSize -
                    (spacing * (gridSize - 1)) -
                    (screenHeight * 0.03)) /
                gridSize;
            final unifiedFontSize = cellSize * 0.35;

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
                // Safe access using methods or direct check if fields are public in base
                bool isFixedCell = controller.isFixed[row][col];
                final value = controller.getCell(row, col);

                Color cellColor = Colors.white;

                if (row == 0 && col == 0) {
                  cellColor = const Color(0xFFFFD54F);
                } else if (isFixedCell) {
                  cellColor = const Color(0xFFFFD54F);
                }

                if (controller.isWrong[row][col] == true) {
                  cellColor = Colors.red.shade300;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: (row == 0 && col == 0)
                        ? GestureDetector(
                            onTap: isGameStarted
                                ? null
                                : () {
                                    onOperationToggle(!showMinus);
                                  },
                            child: Text(
                              showMinus ? "-" : "+",
                              style: TextStyle(
                                fontSize: unifiedFontSize * 1.3,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : isFixedCell
                            ? Text(
                                _formatNumber(value),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: unifiedFontSize,
                                  color: Colors.black,
                                ),
                              )
                            : TextField(
                                key: ValueKey('cell-$row-$col'),
                                controller: inputControllers[_getKey(row, col)],
                                focusNode: focusNodes[_getKey(row, col)],
                                textAlign: TextAlign.center,
                                enabled: isGameStarted,
                                showCursor: isGameStarted,
                                keyboardType: TextInputType.none,
                                maxLength: 5,
                                onTap: () {
                                  debugPrint('cell tapped: $row-$col');
                                  onCellTap?.call(row, col);
                                  focusNodes[_getKey(row, col)]?.requestFocus();
                                },
                                onChanged: (value) {
                                  // Use updateRawInput to handle partial decimals
                                  controller.updateRawInput(row, col, value);
                                  onCellChanged?.call(row, col);
                                },
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "",
                                  counterText: "",
                                  isCollapsed: true,
                                ),
                                style: TextStyle(
                                  fontSize: unifiedFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../controller/game_controller.dart';

class GameGridWidget extends StatelessWidget {
  final GameController controller;
  final Map<String, TextEditingController> inputControllers;
  final Map<String, FocusNode> focusNodes;
  final bool showMinus;
  final bool isGameStarted;
  final Function(bool) onOperationToggle;
  final double screenHeight;
  final double screenWidth;

  const GameGridWidget({
    Key? key,
    required this.controller,
    required this.inputControllers,
    required this.focusNodes,
    required this.showMinus,
    required this.isGameStarted,
    required this.onOperationToggle,
    required this.screenHeight,
    required this.screenWidth,
  }) : super(key: key);

  String _getKey(int row, int col) => '$row-$col';

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
                bool isFixedCell = controller.isFixed[row][col];
                final value = controller.grid[row][col];

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
                      value?.toString() ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: unifiedFontSize,
                        color: Colors.black,
                      ),
                    )
                        : TextField(
                      controller: inputControllers[_getKey(row, col)],
                      focusNode: focusNodes[_getKey(row, col)],
                      textAlign: TextAlign.center,
                      readOnly: true,
                      enabled: isGameStarted,
                      showCursor: isGameStarted,
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
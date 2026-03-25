
import 'package:flutter_test/flutter_test.dart';
import 'package:jol_app/screens/play/controller/game_controller.dart';
import 'package:jol_app/screens/play/controller/base_game_controller_nxn.dart' show PuzzleOperation;

void main() {
  group('GameController Logic Tests', () {
    test('Should generate a solvable 4x4 grid', () async {
      final controller = GameController(gridSize: 4);
      // Wait for async init
      await Future.delayed(const Duration(milliseconds: 200));
      
      expect(controller.solutionGrid.isNotEmpty, true);
      
      // Check if all cells (except 0,0) are filled in solution
      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          if (i == 0 && j == 0) continue;
          expect(controller.solutionGrid[i][j], isNotNull, reason: 'Cell [$i,$j] is null');
        }
      }
    });

    test('Should validate addition logic correctly', () async {
      final controller = GameController(gridSize: 4);
      controller.setOperation(PuzzleOperation.addition);
      await Future.delayed(const Duration(milliseconds: 200));

      // Manually set some values to test mathematical validation
      // Row 1 Head: 5, Col 1 Head: 10 => Middle [1,1]: 15
      controller.grid[1][0] = 5.0;
      controller.grid[0][1] = 10.0;
      controller.grid[1][1] = 15.0;
      
      // Make sure they aren't fixed to avoid skipping
      controller.isFixed[1][0] = false;
      controller.isFixed[0][1] = false;
      controller.isFixed[1][1] = false;

      // Note: validateGrid also updates isWrong
      controller.validateGrid();
      
      expect(controller.isWrong[1][1], false, reason: '5+10=15 should be correct');
      
      controller.grid[1][1] = 16.0;
      controller.validateGrid();
      expect(controller.isWrong[1][1], true, reason: '5+10=16 should be wrong');
    });

    test('Should handle "Reversed L" header validation', () async {
      final controller = GameController(gridSize: 4);
      controller.setOperation(PuzzleOperation.addition);
      await Future.delayed(const Duration(milliseconds: 200));

      // ColHeader = MiddleValue + RowHeader
      // Middle [1,1]: 20, RowHeader [1,0]: 5 => ColHeader [0,1]: 25
      controller.grid[1][1] = 20.0;
      controller.grid[1][0] = 5.0;
      controller.grid[0][1] = 25.0; // 20 + 5
      
      controller.isFixed[1][1] = false;
      controller.isFixed[1][0] = false;
      controller.isFixed[0][1] = false;

      controller.validateGrid();
      expect(controller.isWrong[0][1], false, reason: 'ColHeader 25 = Middle 20 + RowHead 5 should be correct');
    });
  });
}

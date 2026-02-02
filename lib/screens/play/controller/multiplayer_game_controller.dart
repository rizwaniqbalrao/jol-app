import 'package:flutter/material.dart';
import '../models/room_models.dart';
import 'base_multiplayer_controller_nxn.dart';
import 'base_game_controller_nxn.dart' show PuzzleOperation;
import '../utils/puzzle_utils.dart';

class MultiplayerGameController extends BaseMultiplayerControllerNxN {
  MultiplayerGameController({
    required super.roomCode,
    required super.playerId,
  });
}

// multiplayer_puzzle_generator.dart
// Use this to generate puzzles for multiplayer games
class MultiplayerPuzzleGenerator {
  /// Generates a puzzle using the shared logic from PuzzleUtils
  static PuzzleData generatePuzzle({
    required int gridSize,
    required PuzzleOperation operation,
    bool useDecimals = false,
    bool hardMode = false,
  }) {
    debugPrint("Generating Multiplayer puzzle using PuzzleUtils shared logic");

    final result = PuzzleUtils.generateBoardData(
        gridSize: gridSize,
        useDecimals: useDecimals,
        hardMode: hardMode,
        operation: operation);

    final List<List<double?>> fullGrid = result['grid'];
    final List<List<double?>> solutionGrid = result['solutionGrid'];
    final List<List<bool>> isFixed = result['isFixed'];

    return PuzzleData(
      grid: fullGrid,
      solution: solutionGrid,
      isFixed: isFixed,
    );
  }
}

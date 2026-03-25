import 'base_game_controller_nxn.dart';

class GameController5x5 extends BaseGameControllerNxN {
  
  GameController5x5({
    PuzzleOperation? initialOperation, 
    bool initialUseDecimals = false,
    bool initialHardMode = false,
  }) : super(gridSize: 5) {
    if (initialOperation != null) operation = initialOperation;
    setUseDecimals(initialUseDecimals);
    setHardMode(initialHardMode);
  }
}

import 'base_game_controller_nxn.dart';

class GameController6x6 extends BaseGameControllerNxN {
  
  GameController6x6({
    PuzzleOperation? initialOperation, 
    bool initialUseDecimals = false,
    bool initialHardMode = false,
  }) : super(gridSize: 6) {
    if (initialOperation != null) operation = initialOperation;
    setUseDecimals(initialUseDecimals);
    setHardMode(initialHardMode);
  }
}

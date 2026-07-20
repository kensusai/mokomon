import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../logic/minigames.dart' show minigameContinueCost;
import '../widgets/game_overlays.dart';

/// 正誤判定つきミニゲーム(パズル/ちがうのどっち/じゅんばん/かぞえて)共通:
/// ミス上限でのゲームオーバー→コインで続行、の配線をまとめる(docs/game-design.md §5)。
mixin MistakeGameOverMixin<T extends StatefulWidget> on State<T> {
  var gameOver = false;

  GameController get controller;

  /// ゲーム側のミス数をリセットする(例: `_game.continueAfterFail()`)。
  void resetMistakes();

  void failGame() => setState(() => gameOver = true);

  void continueGame() {
    if (controller.payToContinue(minigameContinueCost)) {
      resetMistakes();
      setState(() => gameOver = false);
    }
  }

  Widget buildGameOverOverlay(BuildContext context) => GameOverOverlay(
        cost: minigameContinueCost,
        canAfford: controller.state.coins >= minigameContinueCost,
        onContinue: continueGame,
        onGiveUp: () => Navigator.of(context).pop(),
      );
}

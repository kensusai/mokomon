import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart' show minigameContinueCost;
import '../widgets/game_overlays.dart';
import 'timer_bag.dart';

/// 正誤判定つきミニゲーム(パズル/ちがうのどっち/じゅんばん/かぞえて)共通:
/// ミス上限でのゲームオーバー→コインで続行、の配線をまとめる(docs/game-design.md §5)。
mixin MistakeGameOverMixin<T extends StatefulWidget>
    on State<T>, TimerBagMixin<T> {
  var gameOver = false;

  /// 最終ラウンド正解後、[handleGuess] の finishDelay が明けるまで true。
  /// この間の追いタップを画面側の入力ガードで無視するために見る
  /// (無視しないと全問正解直後に不正解音が鳴る。docs/review-findings.md #23)。
  var finishing = false;

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

  /// 「正解ならすぐ確定・不正解ならミス判定」という即時採点ゲーム
  /// (ちがうのどっち/かぞえて)共通の後処理(docs/review-findings.md #9)。
  /// [finished] がクリア(ラウンド完走)による場合のみ、少し待って
  /// [onFinished] を呼ぶ(ゲームオーバーによる finished はここでは扱わない)。
  void handleGuess({
    required bool correct,
    required bool failed,
    required bool finished,
    required int reward,
    required VoidCallback onFinished,
    Duration finishDelay = const Duration(milliseconds: 400),
  }) {
    if (correct) {
      controller.sfx.play(Sfx.happy);
      if (finished) {
        finishing = true;
        later(finishDelay, () {
          controller.finishMinigame(reward);
          onFinished();
        });
      }
      setState(() {});
    } else {
      controller.sfx.play(Sfx.wrong);
      if (failed) failGame();
    }
  }
}

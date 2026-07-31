import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart' show RoundGuessGame, minigameContinueCost;
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

  /// 「正解ならすぐ確定・不正解ならミス判定」という即時採点ゲーム共通の
  /// 後処理(docs/review-findings.md #9)。
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

/// 正誤ラウンド系画面(かぞえて/どっちがおおい/けいさん/いろタッチ/
/// もじさがし/ペアもじ/ちがうのどっち)の共通配線(docs/review-findings.md #66):
/// 入力ガード→採点→終了フラグ→標準オーバーレイまでを1枚にまとめる。
/// 画面側は [game] を返し、選択肢のタップで [choose] を呼ぶだけでよい。
/// 独自演出を持つ画面(おなじのどれ?のロック+シェイク)は [choose] を
/// 使わず、[ended] と [buildRoundGuessOverlays] だけ共有する。
mixin RoundGuessScreenMixin<T extends StatefulWidget>
    on MistakeGameOverMixin<T> {
  /// クリアで終了した(終了オーバーレイ表示中)。
  var ended = false;

  /// 画面が進行しているゲーム。
  RoundGuessGame get game;

  @override
  void resetMistakes() => game.continueAfterFail();

  /// 選択肢 [index] をタッチ。ガードを通ってから採点する
  /// (ガード前に guess を評価すると、勝利待ち中の追いタップで
  /// 不正解音が鳴る #23 が再発する)。
  void choose(int index) {
    if (ended || finishing || gameOver) return;
    handleGuess(
      correct: game.guess(index),
      failed: game.failed,
      finished: game.finished,
      reward: game.reward,
      onFinished: () => setState(() => ended = true),
    );
  }

  /// 終了([ended])とゲームオーバーの標準オーバーレイ。
  List<Widget> buildRoundGuessOverlays(
    BuildContext context, {
    required String emoji,
    required String result,
  }) => [
    if (ended)
      GameEndOverlay(
        emoji: emoji,
        result: result,
        onDone: () => Navigator.of(context).pop(),
      ),
    if (gameOver) buildGameOverOverlay(context),
  ];
}

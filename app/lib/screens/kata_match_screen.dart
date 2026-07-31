import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// ペアもじ(docs/game-design.md §5)。ひらがな↔カタカナの対応を4択で。
class KataMatchScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final KataMatchGame? game;

  const KataMatchScreen({super.key, required this.controller, this.game});

  @override
  State<KataMatchScreen> createState() => _KataMatchScreenState();
}

class _KataMatchScreenState extends State<KataMatchScreen>
    with TimerBagMixin<KataMatchScreen>, MistakeGameOverMixin<KataMatchScreen> {
  late final _game = widget.game ?? KataMatchGame();
  var _ended = false;

  @override
  GameController get controller => widget.controller;

  @override
  void resetMistakes() => _game.continueAfterFail();

  void _choose(int index) {
    if (_ended || finishing || gameOver) return;
    handleGuess(
      correct: _game.guess(index),
      failed: _game.failed,
      finished: _game.finished,
      reward: _game.reward,
      onFinished: () => setState(() => _ended = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '🔠 ペアもじ',
      topColor: const Color(0xFFFFEFF5),
      bottomColor: const Color(0xFFE8F6EF),
      overlays: [
        if (_ended)
          GameEndOverlay(
            emoji: '🔠',
            result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
            onDone: () => Navigator.of(context).pop(),
          ),
        if (gameOver) buildGameOverOverlay(context),
      ],
      children: [
        const SizedBox(height: 6),
        Text(
          _game.showKata ? 'この カタカナ、ひらがなで どれ?' : 'この ひらがな、カタカナで どれ?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              _game.prompt,
              key: const ValueKey('kata-prompt'),
              style: const TextStyle(
                fontSize: 88,
                fontWeight: FontWeight.w800,
                color: inkColor,
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              for (var i = 0; i < _game.choices.length; i++) _choiceButton(i),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RoundProgressDots(total: kataRounds, current: _game.round),
      ],
    );
  }

  Widget _choiceButton(int i) => Material(
    key: ValueKey('kata-$i'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    elevation: 3,
    shadowColor: const Color(0x1F3A3F52),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _choose(i),
      child: Center(
        child: Text(
          _game.choices[i],
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
      ),
    ),
  );
}

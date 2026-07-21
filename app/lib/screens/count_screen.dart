import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// かぞえてタッチ(docs/game-design.md §5)。対象をかぞえて3択で答える。
class CountScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final CountGame? game;

  const CountScreen({super.key, required this.controller, this.game});

  @override
  State<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<CountScreen>
    with TimerBagMixin<CountScreen>, MistakeGameOverMixin<CountScreen> {
  late final _game = widget.game ?? CountGame();
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
      title: '🧮 かぞえてタッチ',
      topColor: const Color(0xFFE6F7FF),
      bottomColor: const Color(0xFFFFF3E0),
      overlays: [
        if (_ended)
          GameEndOverlay(
            emoji: '🧮',
            result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
            onDone: () => Navigator.of(context).pop(),
          ),
        if (gameOver) buildGameOverOverlay(context),
      ],
      children: [
        const SizedBox(height: 6),
        Text(
          '「${_game.target}」は なんこ?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in _game.items)
                    Text(e, style: const TextStyle(fontSize: 34)),
                ],
              ),
            ),
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < _game.choices.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _choiceButton(i)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _dots(),
      ],
    );
  }

  Widget _choiceButton(int i) => Material(
    key: ValueKey('count-choice-$i'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    elevation: 3,
    shadowColor: const Color(0x1F3A3F52),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _choose(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            '${_game.choices[i]}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: inkColor,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _dots() => RoundProgressDots(
    total: countRounds,
    current: _game.round,
    size: 10,
    trackColor: const Color(0xFFD9DEEA),
  );
}

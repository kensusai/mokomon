import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// どっちがおおい?(docs/game-design.md §5)。多いほうのむれをタッチ。
class CompareScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final CompareGame? game;

  const CompareScreen({super.key, required this.controller, this.game});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen>
    with TimerBagMixin<CompareScreen>, MistakeGameOverMixin<CompareScreen> {
  late final _game = widget.game ?? CompareGame();
  var _ended = false;

  @override
  GameController get controller => widget.controller;

  @override
  void resetMistakes() => _game.continueAfterFail();

  void _choose(int side) {
    if (_ended || finishing || gameOver) return;
    handleGuess(
      correct: _game.guess(side),
      failed: _game.failed,
      finished: _game.finished,
      reward: _game.reward,
      onFinished: () => setState(() => _ended = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '⚖️ どっちが おおい?',
      topColor: const Color(0xFFEFF6E8),
      bottomColor: const Color(0xFFE6F0FF),
      overlays: [
        if (_ended)
          GameEndOverlay(
            emoji: '⚖️',
            result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
            onDone: () => Navigator.of(context).pop(),
          ),
        if (gameOver) buildGameOverOverlay(context),
      ],
      children: [
        const SizedBox(height: 6),
        Text(
          '「${_game.emoji}」が おおいのは どっち?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _sideCard(0, _game.leftCount)),
              const SizedBox(width: 12),
              Expanded(child: _sideCard(1, _game.rightCount)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RoundProgressDots(total: compareRounds, current: _game.round),
      ],
    );
  }

  Widget _sideCard(int side, int count) => Material(
    key: ValueKey('compare-$side'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    elevation: 3,
    shadowColor: const Color(0x1F3A3F52),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _choose(side),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < count; i++)
                Text(_game.emoji, style: const TextStyle(fontSize: 32)),
            ],
          ),
        ),
      ),
    ),
  );
}

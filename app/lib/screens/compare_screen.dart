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
    with
        TimerBagMixin<CompareScreen>,
        MistakeGameOverMixin<CompareScreen>,
        RoundGuessScreenMixin<CompareScreen> {
  late final _game = widget.game ?? CompareGame();

  @override
  GameController get controller => widget.controller;

  @override
  RoundGuessGame get game => _game;

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '⚖️ どっちが おおい?',
      topColor: const Color(0xFFEFF6E8),
      bottomColor: const Color(0xFFE6F0FF),
      overlays: buildRoundGuessOverlays(
        context,
        emoji: '⚖️',
        result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
      ),
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

  Widget _sideCard(int side, int count) => ChoiceCard(
    key: ValueKey('compare-$side'),
    radius: 24,
    onTap: () => choose(side),
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
  );
}

import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// けいさんタッチ(docs/game-design.md §5)。たしざん・ひきざんを3択で答える。
class MathScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final MathGame? game;

  const MathScreen({super.key, required this.controller, this.game});

  @override
  State<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends State<MathScreen>
    with
        TimerBagMixin<MathScreen>,
        MistakeGameOverMixin<MathScreen>,
        RoundGuessScreenMixin<MathScreen> {
  late final _game = widget.game ?? MathGame();

  @override
  GameController get controller => widget.controller;

  @override
  RoundGuessGame get game => _game;

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '➕ けいさんタッチ',
      topColor: const Color(0xFFE8F1FF),
      bottomColor: const Color(0xFFFFF0F5),
      overlays: buildRoundGuessOverlays(
        context,
        emoji: '➕',
        result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
      ),
      children: [
        const SizedBox(height: 6),
        const Text(
          'こたえは どれ?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_game.a} ${_game.isAdd ? '+' : '−'} ${_game.b} = ?',
              key: const ValueKey('math-problem'),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: inkColor,
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
        RoundProgressDots(
          total: mathRounds,
          current: _game.round,
          size: 10,
          trackColor: const Color(0xFFD9DEEA),
        ),
      ],
    );
  }

  Widget _choiceButton(int i) => ChoiceCard(
    key: ValueKey('math-choice-$i'),
    onTap: () => choose(i),
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
  );
}

import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// いろタッチ(docs/game-design.md §5)。ことばに惑わされず「いろ」をタッチ。
class StroopScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final StroopGame? game;

  const StroopScreen({super.key, required this.controller, this.game});

  @override
  State<StroopScreen> createState() => _StroopScreenState();
}

class _StroopScreenState extends State<StroopScreen>
    with
        TimerBagMixin<StroopScreen>,
        MistakeGameOverMixin<StroopScreen>,
        RoundGuessScreenMixin<StroopScreen> {
  late final _game = widget.game ?? StroopGame();

  @override
  GameController get controller => widget.controller;

  @override
  RoundGuessGame get game => _game;

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '🌈 いろタッチ',
      topColor: const Color(0xFFFFF3E0),
      bottomColor: const Color(0xFFE8F6EF),
      overlays: buildRoundGuessOverlays(
        context,
        emoji: '🌈',
        result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
      ),
      children: [
        const SizedBox(height: 6),
        const Text(
          'もじの 「いろ」を タッチ! ことばに だまされないで!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              stroopColors[_game.wordIndex].$1,
              key: const ValueKey('stroop-word'),
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: Color(stroopColors[_game.inkIndex].$2),
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
              for (var i = 0; i < stroopColors.length; i++) _colorPad(i),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RoundProgressDots(
          total: stroopRounds,
          current: _game.round,
          size: 10,
          trackColor: const Color(0xFFD9DEEA),
        ),
      ],
    );
  }

  Widget _colorPad(int i) => Material(
    key: ValueKey('stroop-$i'),
    color: Color(stroopColors[i].$2),
    borderRadius: BorderRadius.circular(20),
    elevation: 3,
    shadowColor: Color(stroopColors[i].$2).withValues(alpha: 0.5),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => choose(i),
      child: Center(
        child: Text(
          stroopColors[i].$1,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

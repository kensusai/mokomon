import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// もじさがし(docs/game-design.md §5)。おだいのひらがなを探してタッチ。
class KanaFindScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final KanaFindGame? game;

  const KanaFindScreen({super.key, required this.controller, this.game});

  @override
  State<KanaFindScreen> createState() => _KanaFindScreenState();
}

class _KanaFindScreenState extends State<KanaFindScreen>
    with TimerBagMixin<KanaFindScreen>, MistakeGameOverMixin<KanaFindScreen> {
  late final _game = widget.game ?? KanaFindGame();
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
      title: '🔤 もじさがし',
      topColor: const Color(0xFFEFF7DE),
      bottomColor: const Color(0xFFE3F2FF),
      overlays: [
        if (_ended)
          GameEndOverlay(
            emoji: '🔤',
            result: 'ぜんぶ みつけた! +${_game.reward} コイン!',
            onDone: () => Navigator.of(context).pop(),
          ),
        if (gameOver) buildGameOverOverlay(context),
      ],
      children: [
        const SizedBox(height: 6),
        Text(
          '「${_game.target}」は どれ?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: GridView.count(
                crossAxisCount: _game.cells.length >= 20 ? 5 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (var i = 0; i < _game.cells.length; i++) _cell(i),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        RoundProgressDots(total: kanaFindRounds, current: _game.round),
      ],
    );
  }

  Widget _cell(int i) => Material(
    key: ValueKey('kana-$i'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    elevation: 3,
    shadowColor: const Color(0x1F3A3F52),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _choose(i),
      child: Center(
        child: Text(
          _game.cells[i],
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

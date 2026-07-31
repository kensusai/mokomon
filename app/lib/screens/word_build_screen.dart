import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// ことばづくり(docs/game-design.md §5)。えもじのことばを文字を順にタッチして作る。
class WordBuildScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final WordBuildGame? game;

  const WordBuildScreen({super.key, required this.controller, this.game});

  @override
  State<WordBuildScreen> createState() => _WordBuildScreenState();
}

class _WordBuildScreenState extends State<WordBuildScreen>
    with TimerBagMixin<WordBuildScreen>, MistakeGameOverMixin<WordBuildScreen> {
  late final _game = widget.game ?? WordBuildGame();
  var _ended = false;

  @override
  GameController get controller => widget.controller;

  @override
  void resetMistakes() => _game.continueAfterFail();

  void _tap(int index) {
    if (_ended || finishing || gameOver) return;
    switch (_game.tap(index)) {
      case WordTap.progress:
        controller.sfx.play(Sfx.tap);
      case WordTap.wordComplete:
        controller.sfx.play(Sfx.happy);
      case WordTap.gameComplete:
        controller.sfx.play(Sfx.happy);
        finishing = true;
        later(const Duration(milliseconds: 400), () {
          controller.finishMinigame(_game.reward);
          setState(() => _ended = true);
        });
      case WordTap.wrong:
        controller.sfx.play(Sfx.wrong);
        if (_game.failed) failGame();
      case WordTap.ignored:
        return;
    }
    setState(() {});
  }

  /// できあがりの表示: 完成した字はそのまま、残りは「・」。
  String get _progressText => [
    for (var k = 0; k < _game.word.length; k++)
      k < _game.nextIndex ? _game.word[k] : '・',
  ].join(' ');

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '💬 ことばづくり',
      topColor: const Color(0xFFEDEBFF),
      bottomColor: const Color(0xFFFFF3E0),
      overlays: [
        if (_ended)
          GameEndOverlay(
            emoji: '💬',
            result: 'ぜんぶ できた! +${_game.reward} コイン!',
            onDone: () => Navigator.of(context).pop(),
          ),
        if (gameOver) buildGameOverOverlay(context),
      ],
      children: [
        const SizedBox(height: 6),
        const Text(
          'えもじの ことばを じゅんばんに タッチ!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_game.emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 10),
              Text(
                _progressText,
                key: const ValueKey('word-progress'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: inkColor,
                ),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [for (var i = 0; i < _game.cells.length; i++) _cell(i)],
          ),
        ),
        const SizedBox(height: 8),
        RoundProgressDots(total: wordRounds, current: _game.round),
      ],
    );
  }

  Widget _cell(int i) {
    final used = _game.used.contains(i);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: used ? 0.25 : 1,
      child: Material(
        key: ValueKey('word-$i'),
        color: used ? const Color(0xFFEAFAF1) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 3,
        shadowColor: const Color(0x1F3A3F52),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _tap(i),
          child: Center(
            child: Text(
              _game.cells[i],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: inkColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

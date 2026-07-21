import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';
import 'timer_bag.dart';

/// じゅんばんタッチ(docs/game-design.md §5)。1〜9を順に、はやくタッチ!
class OrderScreen extends StatefulWidget {
  final GameController controller;

  /// テストで並びを固定するフック。
  final OrderGame? game;

  const OrderScreen({super.key, required this.controller, this.game});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with TimerBagMixin<OrderScreen>, MistakeGameOverMixin<OrderScreen> {
  late final _game = widget.game ?? OrderGame();
  final _watch = Stopwatch();
  var _ended = false;
  var _coins = 0;

  @override
  GameController get controller => widget.controller;

  @override
  void resetMistakes() => _game.continueAfterFail();

  void _tap(int index) {
    if (_ended || gameOver) return;
    if (!_watch.isRunning) _watch.start();
    if (_game.tap(index)) {
      widget.controller.sfx.play(Sfx.tap);
      if (_game.finished) {
        _watch.stop();
        _coins = OrderGame.coinsForSeconds(_watch.elapsedMilliseconds / 1000.0);
        widget.controller.finishMinigame(_coins);
        setState(() => _ended = true);
        return;
      }
      setState(() {});
    } else {
      widget.controller.sfx.play(Sfx.wrong);
      if (_game.failed) {
        _watch.stop();
        failGame();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '🔢 じゅんばんタッチ',
      topColor: const Color(0xFFDFF7E8),
      bottomColor: const Color(0xFFE3F0FF),
      overlays: [
        if (_ended)
          GameEndOverlay(
            emoji: '🏆',
            result: 'ぜんぶ おせた! +$_coins コイン!',
            onDone: () => Navigator.of(context).pop(),
          ),
        if (gameOver) buildGameOverOverlay(context),
      ],
      children: [
        const SizedBox(height: 6),
        Text('つぎは 「${_game.finished ? '✨' : _game.next}」!  はやく タッチ!',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: ink2Color)),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: GridView.count(
                crossAxisCount: 3,
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
      ],
    );
  }

  Widget _cell(int i) {
    final done = _game.cells[i] < _game.next;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: done ? 0.25 : 1,
      child: Material(
        key: ValueKey('order-$i'),
        color: done ? const Color(0xFFEAFAF1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 3,
        shadowColor: const Color(0x1F3A3F52),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _tap(i),
          child: Center(
            child: Text('${_game.cells[i]}',
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: inkColor)),
          ),
        ),
      ),
    );
  }
}

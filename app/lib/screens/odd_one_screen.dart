import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';
import 'mistake_game_over.dart';

/// ちがうのどっち?(docs/game-design.md §5)。1つだけ違う絵文字を探す。
class OddOneScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final OddOneGame? game;

  const OddOneScreen({super.key, required this.controller, this.game});

  @override
  State<OddOneScreen> createState() => _OddOneScreenState();
}

class _OddOneScreenState extends State<OddOneScreen>
    with MistakeGameOverMixin<OddOneScreen> {
  late final _game = widget.game ?? OddOneGame();
  var _ended = false;
  final _timers = <Timer>[];

  @override
  GameController get controller => widget.controller;

  @override
  void resetMistakes() => _game.continueAfterFail();

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _choose(int index) {
    if (_ended || gameOver) return;
    if (_game.guess(index)) {
      widget.controller.sfx.play(Sfx.happy);
      if (_game.finished) {
        _timers.add(Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          widget.controller.finishMinigame(_game.reward);
          setState(() => _ended = true);
        }));
      }
      setState(() {});
    } else {
      widget.controller.sfx.play(Sfx.wrong);
      if (_game.failed) failGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0D9), Color(0xFFE3F2FF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    GameHeaderBar(
                      title: '👀 ちがうの どっち?',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('1つだけ ちがうのが いるよ!',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ink2Color)),
                          const SizedBox(height: 14),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 330),
                              child: GridView.count(
                                // 難化で最大25枚: 枚数に応じて列数を増やす
                                crossAxisCount: _game.cells.length >= 25
                                    ? 5
                                    : _game.cells.length >= 16
                                        ? 4
                                        : 3,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                children: [
                                  for (var i = 0; i < _game.cells.length; i++)
                                    _cell(i),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _dots(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_ended)
                GameEndOverlay(
                  emoji: '🏆',
                  result: 'ぜんぶ みつけた! +${_game.reward} コイン!',
                  onDone: () => Navigator.of(context).pop(),
                ),
              if (gameOver) buildGameOverOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(int i) {
    return Material(
      key: ValueKey('odd-$i'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: const Color(0x1F3A3F52),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _choose(i),
        child: Center(
          child: Text(_game.cells[i], style: const TextStyle(fontSize: 34)),
        ),
      ),
    );
  }

  Widget _dots() => RoundProgressDots(total: oddRounds, current: _game.round);
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';

/// かぞえてタッチ(docs/game-design.md §5)。対象をかぞえて3択で答える。
class CountScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final CountGame? game;

  const CountScreen({super.key, required this.controller, this.game});

  @override
  State<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<CountScreen> {
  late final _game = widget.game ?? CountGame();
  var _ended = false;
  final _timers = <Timer>[];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _choose(int index) {
    if (_ended) return;
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
            colors: [Color(0xFFE6F7FF), Color(0xFFFFF3E0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        BackIconButton(
                            onTap: () => Navigator.of(context).pop()),
                        const Expanded(
                          child: Text('🧮 かぞえてタッチ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: inkColor)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('「${_game.target}」は なんこ?',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ink2Color)),
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
                ),
              ),
              if (_ended)
                GameEndOverlay(
                  emoji: '🧮',
                  result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
                  onDone: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
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
              child: Text('${_game.choices[i]}',
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: inkColor)),
            ),
          ),
        ),
      );

  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < countRounds; i++)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _game.round
                    ? const Color(0xFF34C98E)
                    : const Color(0xFFD9DEEA),
              ),
            ),
        ],
      );
}

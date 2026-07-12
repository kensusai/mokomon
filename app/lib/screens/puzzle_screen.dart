import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';
import '../widgets/shape_painter.dart';

/// おなじのどれ?(docs/game-design.md §5)。8ラウンド、不正解ペナルティなし。
class PuzzleScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final PuzzleGame? game;

  const PuzzleScreen({super.key, required this.controller, this.game});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with SingleTickerProviderStateMixin {
  late final _game = widget.game ?? PuzzleGame();
  var _ended = false;
  var _locked = false;
  int? _shakingIndex;
  late final AnimationController _shake;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _shake.dispose();
    super.dispose();
  }

  void _choose(int index) {
    if (_locked || _ended) return;
    if (_game.guess(index)) {
      widget.controller.sfx.play(Sfx.happy);
      _locked = true;
      setState(() {});
      _timers.add(Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _locked = false;
        if (_game.finished) {
          widget.controller.finishMinigame(_game.reward);
          setState(() => _ended = true);
        } else {
          setState(() {});
        }
      }));
    } else {
      widget.controller.sfx.play(Sfx.wrong);
      setState(() => _shakingIndex = index);
      _shake.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _shakingIndex = null);
      });
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
            colors: [Color(0xFFF3EDFF), Color(0xFFE8F9EF)],
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
                          child: Text('🧩 おなじの どれ?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: inkColor)),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _targetCard(),
                          const SizedBox(height: 16),
                          _choices(),
                          const SizedBox(height: 16),
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
                  result: 'ぜんぶ せいかい! +${_game.reward} コイン!',
                  onDone: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F3A3F52),
                blurRadius: 24,
                offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          children: [
            const Text('これと おなじのは どれ?',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink2Color)),
            const SizedBox(height: 8),
            CustomPaint(
              size: const Size(96, 96),
              painter: ShapePainter(
                  shape: _game.target.shape, color: Color(_game.target.color)),
            ),
          ],
        ),
      );

  Widget _choices() => Row(
        children: [
          for (var i = 0; i < _game.choices.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _choice(i)),
          ],
        ],
      );

  Widget _choice(int i) {
    final piece = _game.choices[i];
    Widget cell = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: const Color(0x1F3A3F52),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _choose(i),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: CustomPaint(
            size: const Size(64, 64),
            painter:
                ShapePainter(shape: piece.shape, color: Color(piece.color)),
          ),
        ),
      ),
    );
    if (_shakingIndex == i) {
      cell = AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          // CSS shake: 25%で-8px、75%で+8px
          offset: Offset(8 * sin(_shake.value * 2 * pi), 0),
          child: child,
        ),
        child: cell,
      );
    }
    return AspectRatio(aspectRatio: 1, child: cell);
  }

  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < puzzleRounds; i++)
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _game.round
                    ? const Color(0xFF34C98E)
                    : const Color(0xFFDFE3EF),
              ),
            ),
        ],
      );
}

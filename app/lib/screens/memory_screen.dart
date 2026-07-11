import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';

/// ペアさがし(docs/game-design.md §5)。3×4=6ペア。
class MemoryScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final MemoryGame? game;

  const MemoryScreen({super.key, required this.controller, this.game});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late final _game = widget.game ?? MemoryGame();
  var _ended = false;
  final _timers = <Timer>[];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _flip(int index) {
    if (_ended) return;
    final result = _game.flip(index);
    switch (result) {
      case MemoryFlipResult.ignored:
        return;
      case MemoryFlipResult.first:
        widget.controller.sfx.play(Sfx.tap);
        setState(() {});
      case MemoryFlipResult.matched:
        widget.controller.sfx.play(Sfx.pop);
        setState(() {});
        if (_game.finished) {
          _timers.add(Timer(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            widget.controller.finishMinigame(memoryReward);
            setState(() => _ended = true);
          }));
        }
      case MemoryFlipResult.mismatched:
        widget.controller.sfx.play(Sfx.wrong);
        setState(() {});
        _timers.add(Timer(const Duration(milliseconds: 750), () {
          if (!mounted) return;
          setState(_game.hideMismatch);
        }));
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
            colors: [Color(0xFFE2F3FF), Color(0xFFFFF0E2)],
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
                          child: Text('🃏 ペアさがし',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3A3F52))),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 4 / 5,
                            children: [
                              for (var i = 0; i < _game.cards.length; i++)
                                _MemoryCard(
                                  key: ValueKey('mem-$i'),
                                  emoji: _game.cards[i],
                                  faceUp: _game.faceUp.contains(i) ||
                                      _game.matched.contains(i),
                                  matched: _game.matched.contains(i),
                                  onTap: () => _flip(i),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_ended)
                GameEndOverlay(
                  emoji: '🎉',
                  result: 'ぜんぶ みつけた! +$memoryReward コイン!',
                  onDone: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3D回転フリップするカード(CSS .memcard 相当、0.35秒)。
class _MemoryCard extends StatelessWidget {
  final String emoji;
  final bool faceUp;
  final bool matched;
  final VoidCallback onTap;

  const _MemoryCard({
    super.key,
    required this.emoji,
    required this.faceUp,
    required this.matched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: matched ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: matched ? 0.3 : 1,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: faceUp ? 1 : 0),
          duration: const Duration(milliseconds: 350),
          builder: (context, t, _) {
            final angle = t * pi;
            final showFront = angle > pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0017) // perspective 600px相当
                ..rotateY(angle),
              child: showFront
                  // 前面は鏡像にならないようさらに180°回す
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: _face(front: true),
                    )
                  : _face(front: false),
            );
          },
        ),
      ),
    );
  }

  Widget _face({required bool front}) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: front
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFAB9DFF), Color(0xFF7C6CF0)],
                ),
          color: front ? Colors.white : null,
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F3A3F52), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: front
            ? Text(emoji, style: const TextStyle(fontSize: 44))
            : const Text('❓',
                style: TextStyle(fontSize: 30, color: Colors.white)),
      );
}

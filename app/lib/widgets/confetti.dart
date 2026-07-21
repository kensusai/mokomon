import 'dart:math';

import 'package:flutter/material.dart';

const _confettiEmoji = ['🎉', '⭐', '💛', '💚', '💙', '🎀', '✨'];

/// 紙吹雪。マウント時に一度だけ [count] 個の絵文字を上から降らせる。
/// プロトタイプの confettiBurst() に対応。
class ConfettiBurst extends StatefulWidget {
  final int count;
  const ConfettiBurst({super.key, this.count = 28});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const _maxMs = 3800; // 最長 delay 0.6s + duration 3.2s
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _maxMs),
  )..forward();
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _pieces = List.generate(widget.count, (i) {
      return _Piece(
        emoji: _confettiEmoji[i % _confettiEmoji.length],
        x: rng.nextDouble(),
        delayMs: (rng.nextDouble() * 600).round(),
        durationMs: (1600 + rng.nextDouble() * 1600).round(),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final nowMs = _c.value * _maxMs;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final p in _pieces)
                  if (nowMs >= p.delayMs && nowMs < p.delayMs + p.durationMs)
                    Positioned(
                      left: p.x * box.maxWidth,
                      top:
                          -20 +
                          (box.maxHeight + 40) *
                              ((nowMs - p.delayMs) / p.durationMs),
                      child: Transform.rotate(
                        angle: 4 * pi * ((nowMs - p.delayMs) / p.durationMs),
                        child: Text(
                          p.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Piece {
  final String emoji;
  final double x;
  final int delayMs;
  final int durationMs;
  _Piece({
    required this.emoji,
    required this.x,
    required this.delayMs,
    required this.durationMs,
  });
}

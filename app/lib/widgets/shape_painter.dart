import 'package:flutter/material.dart';

import '../logic/minigames.dart';

/// パズルの図形描画(プロトタイプ shapeSvg、viewBox 100x100)。
class ShapePainter extends CustomPainter {
  final PuzzleShape shape;
  final Color color;
  ShapePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    canvas.scale(s, s);
    final paint = Paint()..color = color;
    switch (shape) {
      case PuzzleShape.circle:
        canvas.drawCircle(const Offset(50, 50), 38, paint);
      case PuzzleShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 14, 72, 72),
            const Radius.circular(14),
          ),
          paint,
        );
      case PuzzleShape.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(50, 12)
            ..lineTo(90, 82)
            ..lineTo(10, 82)
            ..close(),
          paint,
        );
      case PuzzleShape.star:
        canvas.drawPath(
          Path()
            ..moveTo(50, 8)
            ..lineTo(61, 36)
            ..lineTo(92, 38)
            ..lineTo(68, 58)
            ..lineTo(76, 89)
            ..lineTo(50, 71)
            ..lineTo(24, 89)
            ..lineTo(32, 58)
            ..lineTo(8, 38)
            ..lineTo(39, 36)
            ..close(),
          paint,
        );
      case PuzzleShape.heart:
        canvas.drawPath(
          Path()
            ..moveTo(50, 86)
            ..cubicTo(20, 64, 8, 44, 16, 28)
            ..cubicTo(24, 12, 44, 14, 50, 30)
            ..cubicTo(56, 14, 76, 12, 84, 28)
            ..cubicTo(92, 44, 80, 64, 50, 86)
            ..close(),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(ShapePainter old) =>
      old.shape != shape || old.color != color;
}

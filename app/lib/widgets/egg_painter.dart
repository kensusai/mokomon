import 'package:flutter/material.dart';

/// たまご描画。プロトタイプの #eggG (viewBox 300x300) を移植。
/// [cracks] はタップ回数(0-2)。[golden] は種族3の金のたまご。
class EggPainter extends CustomPainter {
  final int cracks;
  final bool golden;

  EggPainter({required this.cracks, required this.golden});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300.0;
    canvas.scale(s, s);

    final shell = Path()
      ..moveTo(150, 50)
      ..cubicTo(210, 50, 245, 120, 245, 180)
      ..cubicTo(245, 235, 205, 265, 150, 265)
      ..cubicTo(95, 265, 55, 235, 55, 180)
      ..cubicTo(55, 120, 90, 50, 150, 50)
      ..close();

    final fill = Paint();
    if (golden) {
      fill.color = const Color(0xFFFFE9A0);
    } else {
      fill.shader = const RadialGradient(
        center: Alignment(0, -0.3),
        radius: 0.75,
        colors: [Colors.white, Color(0xFFFFE9C9)],
      ).createShader(const Rect.fromLTWH(55, 50, 190, 215));
    }
    canvas.drawPath(shell, fill);
    canvas.drawPath(
        shell,
        Paint()
          ..color = golden ? const Color(0xFFF0B429) : const Color(0xFFF3C98B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);

    final spot = Paint()
      ..color = golden ? const Color(0xFFFFD23E) : const Color(0xFFFFD9A0);
    canvas.drawCircle(const Offset(120, 140), 12, spot);
    canvas.drawCircle(const Offset(185, 190), 9, spot);
    canvas.drawCircle(const Offset(150, 105), 7, spot);

    final crackPaint = Paint()
      ..color = const Color(0xFFD9A35E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (cracks >= 1) {
      final c1 = Path()
        ..moveTo(115, 80)
        ..relativeLineTo(14, 12)
        ..relativeLineTo(-10, 12)
        ..relativeLineTo(16, 10);
      canvas.drawPath(c1, crackPaint);
    }
    if (cracks >= 2) {
      final c2 = Path()
        ..moveTo(175, 95)
        ..relativeLineTo(-12, 14)
        ..relativeLineTo(14, 10)
        ..relativeLineTo(-8, 14);
      canvas.drawPath(c2, crackPaint);
    }
  }

  @override
  bool shouldRepaint(EggPainter old) =>
      old.cracks != cracks || old.golden != golden;
}

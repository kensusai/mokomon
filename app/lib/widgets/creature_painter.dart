import 'package:flutter/material.dart';

import '../data/species.dart';

/// クリーチャー描画。プロトタイプのSVG(viewBox 300x300)を移植。
/// 体パスの座標はプロトタイプと同一。size に合わせてスケールする。
class CreaturePainter extends CustomPainter {
  final int speciesIndex;
  final int stage; // 1..3 (0=たまごは EggPainter を使う)
  final bool sad;
  final Color bodyColor;

  CreaturePainter({
    required this.speciesIndex,
    required this.stage,
    required this.sad,
    Color? bodyColor,
  }) : bodyColor = bodyColor ?? speciesList[speciesIndex].color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300.0;
    canvas.scale(s, s);

    // キング=1.14 / ベビー=0.7(足元アンカー)。docs §3
    final scale = stage == 1 ? 0.7 : (stage == 3 ? 1.14 : 1.0);
    canvas.translate(150 * (1 - scale), 270 * (1 - scale));
    canvas.scale(scale, scale);

    _paintBody(canvas);
    _paintFace(canvas);
    // TODO: 種族アクセサリ(耳/トゲ/星)、王冠、きせかえ、模様レイヤー
  }

  /// 体: SVG "M150,42 C222,42 262,104 262,172 C262,242 212,268 150,268
  ///           C88,268 38,242 38,172 C38,104 78,42 150,42 Z"
  void _paintBody(Canvas canvas) {
    final body = Path()
      ..moveTo(150, 42)
      ..cubicTo(222, 42, 262, 104, 262, 172)
      ..cubicTo(262, 242, 212, 268, 150, 268)
      ..cubicTo(88, 268, 38, 242, 38, 172)
      ..cubicTo(38, 104, 78, 42, 150, 42)
      ..close();
    canvas.drawPath(body, Paint()..color = bodyColor);

    // 足
    final foot = Paint()..color = _shade(bodyColor, -36);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(112, 258), width: 48, height: 24),
        foot);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(188, 258), width: 48, height: 24),
        foot);
  }

  /// デフォルト顔(種族0-3)。変顔(4-6)は docs §4 / プロトタイプ faceSvg() を参照して追加する。
  void _paintFace(Canvas canvas) {
    final ink = Paint()..color = const Color(0xFF3A3F52);
    canvas.drawCircle(const Offset(112, 150), 13, ink);
    canvas.drawCircle(const Offset(188, 150), 13, ink);
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(116, 145), 4.5, white);
    canvas.drawCircle(const Offset(192, 145), 4.5, white);

    final cheek = Paint()..color = const Color(0xB3FF9CC2);
    canvas.drawCircle(const Offset(95, 180), 11, cheek);
    canvas.drawCircle(const Offset(205, 180), 11, cheek);

    final mouth = Paint()
      ..color = const Color(0xFF3A3F52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (sad) {
      path.moveTo(132, 196);
      path.quadraticBezierTo(150, 182, 168, 196);
    } else {
      path.moveTo(132, 185);
      path.quadraticBezierTo(150, 202, 168, 185);
    }
    canvas.drawPath(path, mouth);
  }

  static Color _shade(Color c, int amt) {
    double cl(double v) => (v + amt / 255.0).clamp(0.0, 1.0);
    return Color.from(alpha: 1, red: cl(c.r), green: cl(c.g), blue: cl(c.b));
  }

  @override
  bool shouldRepaint(CreaturePainter old) =>
      old.speciesIndex != speciesIndex ||
      old.stage != stage ||
      old.sad != sad ||
      old.bodyColor != bodyColor;
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/species.dart';

/// 線・目などの基本色(プロトタイプ --ink)
const _ink = Color(0xFF3A3F52);

/// クリーチャー描画。プロトタイプのSVG(viewBox 300x300)を移植。
/// 体パスの座標はプロトタイプと同一。size に合わせてスケールする。
/// たまご(stage 0)は EggPainter を使うこと。
class CreaturePainter extends CustomPainter {
  final int speciesIndex;
  final int stage; // 1..3
  final bool sad;
  final Color bodyColor;
  final String? equipHead;
  final String? equipFace;

  /// お絵かき模様(300x300、体パスでクリップして重ねる)
  final ui.Image? pattern;

  CreaturePainter({
    required this.speciesIndex,
    required this.stage,
    required this.sad,
    Color? bodyColor,
    this.equipHead,
    this.equipFace,
    this.pattern,
  }) : bodyColor = bodyColor ?? speciesList[speciesIndex].color;

  /// 体: SVG "M150,42 C222,42 262,104 262,172 C262,242 212,268 150,268
  ///           C88,268 38,242 38,172 C38,104 78,42 150,42 Z"
  static Path bodyPath() => Path()
    ..moveTo(150, 42)
    ..cubicTo(222, 42, 262, 104, 262, 172)
    ..cubicTo(262, 242, 212, 268, 150, 268)
    ..cubicTo(88, 268, 38, 242, 38, 172)
    ..cubicTo(38, 104, 78, 42, 150, 42)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300.0;
    canvas.scale(s, s);

    // キング=1.14 / ベビー=0.7(足元アンカー)。docs §3
    final scale = stage == 1 ? 0.7 : (stage == 3 ? 1.14 : 1.0);
    canvas.translate(150 * (1 - scale), 270 * (1 - scale));
    canvas.scale(scale, scale);

    _paintAccessories(canvas);
    _paintBody(canvas);
    _paintFace(canvas);
    if (stage >= 3 && equipHead == null) _paintCrown(canvas);
    if (equipFace != null) _paintItem(canvas, equipFace!);
    if (equipHead != null) _paintItem(canvas, equipHead!);
  }

  // ---------- body ----------

  void _paintBody(Canvas canvas) {
    final body = bodyPath();
    canvas.drawPath(body, Paint()..color = bodyColor);

    if (pattern != null) {
      canvas.save();
      canvas.clipPath(body);
      canvas.drawImageRect(
        pattern!,
        Rect.fromLTWH(
            0, 0, pattern!.width.toDouble(), pattern!.height.toDouble()),
        const Rect.fromLTWH(0, 0, 300, 300),
        Paint(),
      );
      canvas.restore();
    }

    final foot = Paint()..color = shade(bodyColor, -36);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(112, 258), width: 48, height: 24),
        foot);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(188, 258), width: 48, height: 24),
        foot);
  }

  // ---------- 種族アクセサリ(体の後ろに描く) ----------

  void _paintAccessories(Canvas canvas) {
    final acc = Paint()..color = shade(bodyColor, -22);
    switch (speciesIndex) {
      case 0: // moko: stage2+ で小さい耳
        if (stage >= 2) {
          canvas.drawPath(
              Path()
                ..moveTo(85, 70)
                ..cubicTo(70, 20, 110, 15, 118, 55)
                ..close(),
              acc);
          canvas.drawPath(
              Path()
                ..moveTo(215, 70)
                ..cubicTo(230, 20, 190, 15, 182, 55)
                ..close(),
              acc);
        }
      case 1: // pyon: うさ耳 + 内耳ハイライト
        canvas.drawPath(
            Path()
              ..moveTo(108, 78)
              ..cubicTo(82, -8, 138, -6, 132, 70)
              ..close(),
            acc);
        canvas.drawPath(
            Path()
              ..moveTo(192, 78)
              ..cubicTo(218, -8, 162, -6, 168, 70)
              ..close(),
            acc);
        final inner = Paint()..color = Colors.white.withValues(alpha: 0.5);
        canvas.drawPath(
            Path()
              ..moveTo(112, 60)
              ..cubicTo(100, 14, 126, 14, 124, 58)
              ..close(),
            inner);
        canvas.drawPath(
            Path()
              ..moveTo(188, 60)
              ..cubicTo(200, 14, 174, 14, 176, 58)
              ..close(),
            inner);
      case 2: // toge: 頭にトゲ
        canvas.drawPath(
            Path()
              ..moveTo(92, 64)
              ..lineTo(104, 26)
              ..lineTo(124, 54)
              ..lineTo(150, 18)
              ..lineTo(176, 54)
              ..lineTo(196, 26)
              ..lineTo(208, 64)
              ..close(),
            acc);
      case 3: // pika: 星の角(head装備中は非表示)
        if (equipHead == null) {
          final star = Path()
            ..moveTo(150, 2)
            ..lineTo(158, 20)
            ..lineTo(178, 22)
            ..lineTo(163, 35)
            ..lineTo(168, 54)
            ..lineTo(150, 43)
            ..lineTo(132, 54)
            ..lineTo(137, 35)
            ..lineTo(122, 22)
            ..lineTo(142, 20)
            ..close();
          canvas.drawPath(star, Paint()..color = const Color(0xFFFFB200));
          canvas.drawPath(
              star,
              Paint()
                ..color = const Color(0xFFE89B00)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..strokeJoin = StrokeJoin.round);
        }
      case 7: // nyan: ねこ耳(三角)+内耳
        canvas.drawPath(
            Path()
              ..moveTo(82, 80)
              ..lineTo(92, 18)
              ..lineTo(138, 52)
              ..close(),
            acc);
        canvas.drawPath(
            Path()
              ..moveTo(218, 80)
              ..lineTo(208, 18)
              ..lineTo(162, 52)
              ..close(),
            acc);
        final innerEar = Paint()..color = Colors.white.withValues(alpha: 0.45);
        canvas.drawPath(
            Path()
              ..moveTo(94, 68)
              ..lineTo(99, 34)
              ..lineTo(124, 52)
              ..close(),
            innerEar);
        canvas.drawPath(
            Path()
              ..moveTo(206, 68)
              ..lineTo(201, 34)
              ..lineTo(176, 52)
              ..close(),
            innerEar);
    }
  }

  // ---------- 顔(プロトタイプ faceSvg() を移植) ----------

  void _paintFace(Canvas canvas) {
    switch (speciesIndex) {
      case 4:
        _faceBero(canvas);
      case 5:
        _faceBuu(canvas);
      case 6:
        _faceMedama(canvas);
      case 7:
        _faceNyan(canvas);
      case 8:
        _faceDandy(canvas);
      default:
        _faceDefault(canvas);
    }
  }

  Paint get _inkFill => Paint()..color = _ink;
  Paint _inkStroke(double w) => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _cheeks(Canvas canvas, double lx, double rx, double y) {
    final cheek = Paint()..color = const Color(0xFFFF9CC2).withValues(alpha: 0.7);
    canvas.drawCircle(Offset(lx, y), 11, cheek);
    canvas.drawCircle(Offset(rx, y), 11, cheek);
  }

  void _faceDefault(Canvas canvas) {
    canvas.drawCircle(const Offset(112, 150), 13, _inkFill);
    canvas.drawCircle(const Offset(188, 150), 13, _inkFill);
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(116, 145), 4.5, white);
    canvas.drawCircle(const Offset(192, 145), 4.5, white);
    _cheeks(canvas, 95, 205, 180);

    final mouth = Path();
    if (sad) {
      mouth.moveTo(132, 196);
      mouth.quadraticBezierTo(150, 182, 168, 196);
    } else {
      mouth.moveTo(132, 185);
      mouth.quadraticBezierTo(150, 202, 168, 185);
    }
    canvas.drawPath(mouth, _inkStroke(6));
  }

  /// bero: 大小バラバラの目玉 + 垂れた舌
  void _faceBero(Canvas canvas) {
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(105, 138), 27, white);
    canvas.drawCircle(const Offset(105, 138), 27, _inkStroke(5));
    canvas.drawCircle(const Offset(98, 130), 11, _inkFill);
    canvas.drawCircle(const Offset(194, 155), 15, white);
    canvas.drawCircle(const Offset(194, 155), 15, _inkStroke(5));
    canvas.drawCircle(const Offset(199, 161), 7, _inkFill);

    if (sad) {
      final wavy = Path()
        ..moveTo(122, 202)
        ..relativeQuadraticBezierTo(9, -9, 19, 0)
        ..relativeQuadraticBezierTo(9, 9, 19, 0)
        ..relativeQuadraticBezierTo(9, -9, 19, 0);
      canvas.drawPath(wavy, _inkStroke(6));
      return;
    }
    final mouth = Path()
      ..moveTo(118, 186)
      ..quadraticBezierTo(150, 204, 182, 184);
    canvas.drawPath(mouth, _inkStroke(6));
    final tongue = Path()
      ..moveTo(143, 193)
      ..quadraticBezierTo(146, 238, 162, 235)
      ..quadraticBezierTo(176, 231, 166, 191)
      ..close();
    canvas.drawPath(tongue, Paint()..color = const Color(0xFFFF7EB0));
    canvas.drawPath(
        tongue,
        Paint()
          ..color = const Color(0xFFE85D94)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round);
    final centerLine = Path()
      ..moveTo(154, 198)
      ..quadraticBezierTo(157, 215, 160, 226);
    canvas.drawPath(
        centerLine,
        Paint()
          ..color = const Color(0xFFE85D94)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
  }

  /// buu: 小さな目 + 巨大ぶた鼻 + 出っ歯
  void _faceBuu(Canvas canvas) {
    canvas.drawCircle(const Offset(97, 136), 7, _inkFill);
    canvas.drawCircle(const Offset(203, 136), 7, _inkFill);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 168), width: 72, height: 54),
        Paint()..color = const Color(0xFFFF9CB5));
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 168), width: 72, height: 54),
        Paint()
          ..color = const Color(0xFFE37F9C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    final nostril = Paint()..color = const Color(0xFFD95F85);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(136, 168), width: 16, height: 24),
        nostril);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(164, 168), width: 16, height: 24),
        nostril);

    if (sad) {
      canvas.drawLine(const Offset(82, 120), const Offset(108, 130), _inkStroke(6));
      canvas.drawLine(const Offset(218, 120), const Offset(192, 130), _inkStroke(6));
      final mouth = Path()
        ..moveTo(134, 216)
        ..quadraticBezierTo(150, 205, 166, 216);
      canvas.drawPath(mouth, _inkStroke(6));
      return;
    }
    final mouth = Path()
      ..moveTo(116, 200)
      ..quadraticBezierTo(150, 224, 184, 200);
    canvas.drawPath(mouth, _inkStroke(6));
    for (final x in [133.0, 152.0]) {
      final tooth = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 202, 15, 17), const Radius.circular(3));
      canvas.drawRRect(tooth, Paint()..color = Colors.white);
      canvas.drawRRect(
          tooth,
          Paint()
            ..color = const Color(0xFFD8DBE8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  /// medama: 一つ目 + 極太一本眉
  void _faceMedama(Canvas canvas) {
    canvas.save();
    canvas.translate(150, 93);
    canvas.rotate((sad ? 6 : -3) * 3.14159265 / 180);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-42, -7.5, 84, 15),
            const Radius.circular(7.5)),
        _inkFill);
    canvas.restore();

    canvas.drawCircle(const Offset(150, 142), 36, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(150, 142), 36, _inkStroke(5));
    canvas.drawCircle(const Offset(150, 146), 17, Paint()..color = const Color(0xFF6CC4FF));
    canvas.drawCircle(const Offset(150, 146), 9, _inkFill);
    canvas.drawCircle(const Offset(157, 138), 4.5, Paint()..color = Colors.white);
    _cheeks(canvas, 100, 200, 185);

    if (sad) {
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(150, 206), width: 20, height: 26),
          _inkFill);
      return;
    }
    final mouth = Path()
      ..moveTo(122, 192)
      ..quadraticBezierTo(150, 224, 178, 192)
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFF8A4A5E));
    for (final x in [137.0, 151.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 192, 11, 10), const Radius.circular(2)),
          Paint()..color = Colors.white);
    }
  }

  /// nyan: ねこ目+ひげ+ωのくち+ピンクの鼻
  void _faceNyan(Canvas canvas) {
    canvas.drawCircle(const Offset(112, 150), 13, _inkFill);
    canvas.drawCircle(const Offset(188, 150), 13, _inkFill);
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(116, 145), 4.5, white);
    canvas.drawCircle(const Offset(192, 145), 4.5, white);
    _cheeks(canvas, 95, 205, 180);

    final whisker = _inkStroke(4);
    canvas.drawLine(const Offset(52, 158), const Offset(90, 164), whisker);
    canvas.drawLine(const Offset(48, 178), const Offset(90, 178), whisker);
    canvas.drawLine(const Offset(52, 198), const Offset(90, 192), whisker);
    canvas.drawLine(const Offset(248, 158), const Offset(210, 164), whisker);
    canvas.drawLine(const Offset(252, 178), const Offset(210, 178), whisker);
    canvas.drawLine(const Offset(248, 198), const Offset(210, 192), whisker);

    // 鼻(小さな逆三角)
    canvas.drawPath(
        Path()
          ..moveTo(143, 172)
          ..lineTo(157, 172)
          ..lineTo(150, 181)
          ..close(),
        Paint()..color = const Color(0xFFFF6EA6));

    final mouth = Path();
    if (sad) {
      mouth.moveTo(132, 200);
      mouth.quadraticBezierTo(150, 186, 168, 200);
    } else {
      // ω
      mouth.moveTo(130, 188);
      mouth.quadraticBezierTo(140, 200, 150, 189);
      mouth.quadraticBezierTo(160, 200, 170, 188);
    }
    canvas.drawPath(mouth, _inkStroke(6));
  }

  /// dandy: ちいさな目+極太まゆ+巨大くるくるヒゲ
  void _faceDandy(Canvas canvas) {
    canvas.drawCircle(const Offset(108, 134), 7, _inkFill);
    canvas.drawCircle(const Offset(192, 134), 7, _inkFill);

    // まゆ(悲しいときは八の字)
    void brow(double cx, double cy, double deg) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(deg * 3.14159265 / 180);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-26, -8, 52, 16), const Radius.circular(8)),
          _inkFill);
      canvas.restore();
    }

    brow(108, 108, sad ? 14 : -8);
    brow(192, 108, sad ? -14 : 8);

    // ヒゲ(こげ茶・先端カール)
    final hige = Paint()..color = const Color(0xFF5C4033);
    canvas.drawPath(
        Path()
          ..moveTo(150, 172)
          ..cubicTo(132, 160, 100, 162, 86, 178)
          ..cubicTo(80, 186, 86, 196, 96, 194)
          ..cubicTo(118, 190, 140, 184, 150, 180)
          ..close(),
        hige);
    canvas.drawPath(
        Path()
          ..moveTo(150, 172)
          ..cubicTo(168, 160, 200, 162, 214, 178)
          ..cubicTo(220, 186, 214, 196, 204, 194)
          ..cubicTo(182, 190, 160, 184, 150, 180)
          ..close(),
        hige);
    canvas.drawCircle(const Offset(90, 190), 8, hige);
    canvas.drawCircle(const Offset(210, 190), 8, hige);

    final mouth = Path();
    if (sad) {
      mouth.moveTo(138, 216);
      mouth.quadraticBezierTo(150, 206, 162, 216);
    } else {
      mouth.moveTo(138, 208);
      mouth.quadraticBezierTo(150, 220, 162, 208);
    }
    canvas.drawPath(mouth, _inkStroke(6));
  }

  // ---------- 王冠(キング、head装備中は非表示) ----------

  void _paintCrown(Canvas canvas) {
    final crown = Path()
      ..moveTo(120, 45)
      ..lineTo(128, 22)
      ..lineTo(142, 38)
      ..lineTo(150, 14)
      ..lineTo(158, 38)
      ..lineTo(172, 22)
      ..lineTo(180, 45)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD23E));
    canvas.drawPath(
        crown,
        Paint()
          ..color = const Color(0xFFF0A92D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round);
  }

  // ---------- きせかえ(プロトタイプ ITEM_SVG を移植) ----------

  void _paintItem(Canvas canvas, String key) {
    switch (key) {
      case 'ribbon':
        canvas.save();
        canvas.translate(196, 44);
        canvas.rotate(18 * 3.14159265 / 180);
        final wing = Paint()..color = const Color(0xFFFF6EA6);
        canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(-30, -16)
              ..lineTo(-30, 16)
              ..close(),
            wing);
        canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(30, -16)
              ..lineTo(30, 16)
              ..close(),
            wing);
        canvas.drawCircle(Offset.zero, 8, Paint()..color = const Color(0xFFFF4F96));
        canvas.restore();
      case 'flower':
        canvas.save();
        canvas.translate(104, 40);
        final petal = Paint()..color = const Color(0xFFFF9CC2);
        for (final o in const [
          Offset(0, -13),
          Offset(12, -4),
          Offset(8, 10),
          Offset(-8, 10),
          Offset(-12, -4),
        ]) {
          canvas.drawCircle(o, 9, petal);
        }
        canvas.drawCircle(Offset.zero, 7, Paint()..color = const Color(0xFFFFD23E));
        canvas.restore();
      case 'strawhat':
        final straw = Paint()..color = const Color(0xFFFFD23E);
        final strawStroke = Paint()
          ..color = const Color(0xFFEAB63A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        final dome = Path()
          ..moveTo(112, 52)
          ..cubicTo(112, 16, 188, 16, 188, 52)
          ..close();
        canvas.drawPath(dome, straw);
        canvas.drawPath(dome, strawStroke);
        final brim = Rect.fromCenter(
            center: const Offset(150, 54), width: 144, height: 28);
        canvas.drawOval(brim, straw);
        canvas.drawOval(brim, strawStroke);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(112, 40, 76, 10), const Radius.circular(5)),
            Paint()..color = const Color(0xFFFF8F1F));
      case 'tophat':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(85, 46, 130, 16), const Radius.circular(8)),
            _inkFill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(107, 2, 86, 52), const Radius.circular(9)),
            _inkFill);
        canvas.drawRect(const Rect.fromLTWH(107, 36, 86, 12),
            Paint()..color = const Color(0xFFFF6EA6));
      case 'glasses':
        final stroke = _inkStroke(6);
        canvas.drawCircle(const Offset(112, 150), 25, stroke);
        canvas.drawCircle(const Offset(188, 150), 25, stroke);
        canvas.drawLine(const Offset(137, 150), const Offset(163, 150), stroke);
      case 'sunglass':
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(84, 131, 54, 36),
                const Radius.circular(13)),
            _inkFill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(162, 131, 54, 36),
                const Radius.circular(13)),
            _inkFill);
        canvas.drawRect(const Rect.fromLTWH(136, 141, 28, 8), _inkFill);
        final temple = Paint()..color = const Color(0xFF6B7288);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(92, 137, 18, 7),
                const Radius.circular(3.5)),
            temple);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(170, 137, 18, 7),
                const Radius.circular(3.5)),
            temple);
    }
  }

  static Color shade(Color c, int amt) {
    double cl(double v) => (v + amt / 255.0).clamp(0.0, 1.0);
    return Color.from(alpha: 1, red: cl(c.r), green: cl(c.g), blue: cl(c.b));
  }

  @override
  bool shouldRepaint(CreaturePainter old) =>
      old.speciesIndex != speciesIndex ||
      old.stage != stage ||
      old.sad != sad ||
      old.bodyColor != bodyColor ||
      old.equipHead != equipHead ||
      old.equipFace != equipFace ||
      old.pattern != pattern;
}

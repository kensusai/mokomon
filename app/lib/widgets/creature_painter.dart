import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/species.dart';
import 'creature_faces.dart';
import 'creature_items.dart';

/// クリーチャー描画。プロトタイプのSVG(viewBox 300x300)を移植。
/// 体パスの座標はプロトタイプと同一。size に合わせてスケールする。
/// たまご(stage 0)は EggPainter を使うこと。
class CreaturePainter extends CustomPainter {
  final int speciesIndex;
  final int stage; // 1..3
  final bool sad;

  /// リアクション中の誇張表情(null なら通常の種族顔)。約1秒で戻す。
  final CreatureMood? mood;
  final Color bodyColor;
  final String? equipHead;
  final String? equipFace;

  /// お絵かき模様(300x300、体パスでクリップして重ねる)
  final ui.Image? pattern;

  CreaturePainter({
    required this.speciesIndex,
    required this.stage,
    required this.sad,
    this.mood,
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

  /// ベビー専用の丸い素体(進化の見た目差を大きくするため別シルエット)。
  static Path babyBodyPath() => Path()
    ..moveTo(150, 82)
    ..cubicTo(224, 82, 254, 136, 254, 182)
    ..cubicTo(254, 238, 212, 268, 150, 268)
    ..cubicTo(88, 268, 46, 238, 46, 182)
    ..cubicTo(46, 136, 76, 82, 150, 82)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300.0;
    canvas.scale(s, s);

    // キング=1.2 / ベビー=0.62(足元アンカー)。docs §3
    final scale = stage == 1 ? 0.62 : (stage == 3 ? 1.2 : 1.0);
    canvas.translate(150 * (1 - scale), 270 * (1 - scale));
    canvas.scale(scale, scale);

    // アクセサリ(耳・トゲ・星)は stage2 から。キングは大型化して威厳を出す
    if (stage >= 2) {
      if (stage == 3) {
        canvas.save();
        canvas.translate(150, 64);
        canvas.scale(1.18, 1.18);
        canvas.translate(-150, -64);
      }
      _paintAccessories(canvas);
      if (stage == 3) canvas.restore();
    }
    _paintBody(canvas);
    if (mood != null) {
      paintExpressionFace(canvas, mood: mood!);
    } else {
      paintCreatureFace(canvas, speciesIndex: speciesIndex, sad: sad);
    }
    if (stage >= 3 && equipHead == null) _paintCrown(canvas);
    if (equipFace != null) paintEquipItem(canvas, equipFace!);
    if (equipHead != null) paintEquipItem(canvas, equipHead!);
  }

  // ---------- body ----------

  void _paintBody(Canvas canvas) {
    if (stage == 3) _paintMantle(canvas);

    final body = stage == 1 ? babyBodyPath() : bodyPath();
    canvas.drawPath(body, Paint()..color = bodyColor);

    // キングはおなかに明るいパッチ(体格の変化を強調)
    if (stage == 3) {
      canvas.save();
      canvas.clipPath(body);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 212), width: 110, height: 86),
        Paint()..color = shade(bodyColor, 34),
      );
      canvas.restore();
    }

    if (pattern != null) {
      canvas.save();
      canvas.clipPath(body);
      canvas.drawImageRect(
        pattern!,
        Rect.fromLTWH(
          0,
          0,
          pattern!.width.toDouble(),
          pattern!.height.toDouble(),
        ),
        const Rect.fromLTWH(0, 0, 300, 300),
        Paint(),
      );
      canvas.restore();
    }

    // 手(腕)は stage2 から生える
    if (stage >= 2) {
      final arm = Paint()..color = shade(bodyColor, -18);
      for (final side in const [-1, 1]) {
        canvas.save();
        canvas.translate(150 + side * 100, 194);
        canvas.rotate(side * 35 * pi / 180);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 46, height: 22),
          arm,
        );
        canvas.restore();
      }
    }

    final foot = Paint()..color = shade(bodyColor, -36);
    final footW = stage == 1 ? 38.0 : 48.0;
    for (final x in const [112.0, 188.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 258), width: footW, height: 24),
        foot,
      );
    }
  }

  /// キングの王家マント(体の後ろ・すその波+金の縁取り)。
  void _paintMantle(Canvas canvas) {
    final mantle = Path()
      ..moveTo(108, 92)
      ..cubicTo(42, 128, 16, 200, 28, 260)
      ..quadraticBezierTo(58, 246, 84, 260)
      ..quadraticBezierTo(117, 244, 150, 260)
      ..quadraticBezierTo(183, 244, 216, 260)
      ..quadraticBezierTo(242, 246, 272, 260)
      ..cubicTo(284, 200, 258, 128, 192, 92)
      ..close();
    canvas.drawPath(mantle, Paint()..color = const Color(0xFFD6506E));
    canvas.drawPath(
      mantle,
      Paint()
        ..color = const Color(0xFFFFD23E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  // ---------- 種族アクセサリ(体の後ろに描く) ----------

  /// 種族アクセサリ。呼び出し側で stage>=2 にゲートされている。
  void _paintAccessories(Canvas canvas) {
    final acc = Paint()..color = shade(bodyColor, -22);
    switch (speciesIndex) {
      case 0: // moko: 小さい耳
        canvas.drawPath(
          Path()
            ..moveTo(85, 70)
            ..cubicTo(70, 20, 110, 15, 118, 55)
            ..close(),
          acc,
        );
        canvas.drawPath(
          Path()
            ..moveTo(215, 70)
            ..cubicTo(230, 20, 190, 15, 182, 55)
            ..close(),
          acc,
        );
      case 1: // pyon: うさ耳 + 内耳ハイライト
        canvas.drawPath(
          Path()
            ..moveTo(108, 78)
            ..cubicTo(82, -8, 138, -6, 132, 70)
            ..close(),
          acc,
        );
        canvas.drawPath(
          Path()
            ..moveTo(192, 78)
            ..cubicTo(218, -8, 162, -6, 168, 70)
            ..close(),
          acc,
        );
        final inner = Paint()..color = Colors.white.withValues(alpha: 0.5);
        canvas.drawPath(
          Path()
            ..moveTo(112, 60)
            ..cubicTo(100, 14, 126, 14, 124, 58)
            ..close(),
          inner,
        );
        canvas.drawPath(
          Path()
            ..moveTo(188, 60)
            ..cubicTo(200, 14, 174, 14, 176, 58)
            ..close(),
          inner,
        );
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
          acc,
        );
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
              ..strokeJoin = StrokeJoin.round,
          );
        }
      case 9: // mojya: もじゃもじゃアフロ
        for (final c in const [
          Offset(90, 70),
          Offset(120, 48),
          Offset(150, 40),
          Offset(180, 48),
          Offset(210, 70),
          Offset(105, 95),
          Offset(195, 95),
        ]) {
          canvas.drawCircle(c, 34, acc);
        }
      case 12: // nemu: アホ毛(くるん)
        final ahoge = Path()
          ..moveTo(150, 60)
          ..cubicTo(146, 26, 176, 18, 180, 40)
          ..cubicTo(182, 54, 168, 58, 162, 50);
        canvas.drawPath(
          ahoge,
          Paint()
            ..color = shade(bodyColor, -22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
      case 13: // robo: アンテナ
        canvas.drawLine(
          const Offset(150, 62),
          const Offset(150, 22),
          Paint()
            ..color = shade(bodyColor, -40)
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          const Offset(150, 16),
          11,
          Paint()..color = const Color(0xFFFF6E6E),
        );
      case 7: // nyan: ねこ耳(三角)+内耳
        canvas.drawPath(
          Path()
            ..moveTo(82, 80)
            ..lineTo(92, 18)
            ..lineTo(138, 52)
            ..close(),
          acc,
        );
        canvas.drawPath(
          Path()
            ..moveTo(218, 80)
            ..lineTo(208, 18)
            ..lineTo(162, 52)
            ..close(),
          acc,
        );
        final innerEar = Paint()..color = Colors.white.withValues(alpha: 0.45);
        canvas.drawPath(
          Path()
            ..moveTo(94, 68)
            ..lineTo(99, 34)
            ..lineTo(124, 52)
            ..close(),
          innerEar,
        );
        canvas.drawPath(
          Path()
            ..moveTo(206, 68)
            ..lineTo(201, 34)
            ..lineTo(176, 52)
            ..close(),
          innerEar,
        );
    }
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
        ..strokeJoin = StrokeJoin.round,
    );
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
      old.mood != mood ||
      old.bodyColor != bodyColor ||
      old.equipHead != equipHead ||
      old.equipFace != equipFace ||
      old.pattern != pattern;
}

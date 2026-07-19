import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/species.dart';
import 'creature_faces.dart';
import 'ui_kit.dart';

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
    if (equipFace != null) _paintItem(canvas, equipFace!);
    if (equipHead != null) _paintItem(canvas, equipHead!);
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
          Rect.fromCenter(
              center: const Offset(150, 212), width: 110, height: 86),
          Paint()..color = shade(bodyColor, 34));
      canvas.restore();
    }

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

    // 手(腕)は stage2 から生える
    if (stage >= 2) {
      final arm = Paint()..color = shade(bodyColor, -18);
      canvas.save();
      canvas.translate(50, 194);
      canvas.rotate(-35 * 3.14159265 / 180);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 46, height: 22), arm);
      canvas.restore();
      canvas.save();
      canvas.translate(250, 194);
      canvas.rotate(35 * 3.14159265 / 180);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 46, height: 22), arm);
      canvas.restore();
    }

    final foot = Paint()..color = shade(bodyColor, -36);
    final footW = stage == 1 ? 38.0 : 48.0;
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(112, 258), width: footW, height: 24),
        foot);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(188, 258), width: footW, height: 24),
        foot);
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
          ..strokeJoin = StrokeJoin.round);
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
            acc);
        canvas.drawPath(
            Path()
              ..moveTo(215, 70)
              ..cubicTo(230, 20, 190, 15, 182, 55)
              ..close(),
            acc);
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
              ..strokeCap = StrokeCap.round);
      case 13: // robo: アンテナ
        canvas.drawLine(
            const Offset(150, 62),
            const Offset(150, 22),
            Paint()
              ..color = shade(bodyColor, -40)
              ..strokeWidth = 7
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(const Offset(150, 16), 11,
            Paint()..color = const Color(0xFFFF6E6E));
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
        canvas.drawCircle(
            Offset.zero, 8, Paint()..color = const Color(0xFFFF4F96));
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
        canvas.drawCircle(
            Offset.zero, 7, Paint()..color = const Color(0xFFFFD23E));
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
            inkFill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(107, 2, 86, 52), const Radius.circular(9)),
            inkFill);
        canvas.drawRect(const Rect.fromLTWH(107, 36, 86, 12),
            Paint()..color = const Color(0xFFFF6EA6));
      case 'glasses':
        final stroke = inkStroke(6);
        canvas.drawCircle(const Offset(112, 150), 25, stroke);
        canvas.drawCircle(const Offset(188, 150), 25, stroke);
        canvas.drawLine(const Offset(137, 150), const Offset(163, 150), stroke);
      case 'sunglass':
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(84, 131, 54, 36),
                const Radius.circular(13)),
            inkFill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(162, 131, 54, 36),
                const Radius.circular(13)),
            inkFill);
        canvas.drawRect(const Rect.fromLTWH(136, 141, 28, 8), inkFill);
        final temple = Paint()..color = const Color(0xFF6B7288);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(92, 137, 18, 7),
                const Radius.circular(3.5)),
            temple);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(170, 137, 18, 7),
                const Radius.circular(3.5)),
            temple);
      case 'party': // パーティーぼうし(しましま三角+ぽんぽん)
        final cone = Path()
          ..moveTo(150, -8)
          ..lineTo(116, 58)
          ..lineTo(184, 58)
          ..close();
        canvas.drawPath(cone, Paint()..color = const Color(0xFFFF6EA6));
        canvas.save();
        canvas.clipPath(cone);
        final stripe = Paint()..color = const Color(0xFFFFD23E);
        canvas.drawRect(const Rect.fromLTWH(100, 8, 100, 12), stripe);
        canvas.drawRect(const Rect.fromLTWH(100, 34, 100, 12), stripe);
        canvas.restore();
        canvas.drawCircle(
            const Offset(150, -8), 9, Paint()..color = const Color(0xFF54B9FF));
      case 'wizard': // とんがりぼうし(むらさき+星)
        final hat = Path()
          ..moveTo(150, -14)
          ..lineTo(112, 52)
          ..lineTo(188, 52)
          ..close();
        canvas.drawPath(hat, Paint()..color = const Color(0xFF7C6CF0));
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(150, 54), width: 108, height: 20),
            Paint()..color = const Color(0xFF6555D6));
        _star(canvas, const Offset(150, 22), 10, const Color(0xFFFFD23E));
      case 'tiara': // ティアラ(金バンド+3つの山+宝石)
        canvas.drawArc(
            Rect.fromCircle(center: const Offset(150, 76), radius: 52),
            3.5,
            2.4,
            false,
            Paint()
              ..color = const Color(0xFFFFD23E)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9);
        for (final d in const [
          (Offset(122, 34), 7.0),
          (Offset(150, 22), 10.0),
          (Offset(178, 34), 7.0),
        ]) {
          canvas.drawCircle(
              d.$1, d.$2, Paint()..color = const Color(0xFFFF6EA6));
          canvas.drawCircle(
              d.$1,
              d.$2,
              Paint()
                ..color = const Color(0xFFF0A92D)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3);
        }
      case 'cap': // キャップ(ドーム+つば)
        final dome = Path()
          ..moveTo(108, 56)
          ..cubicTo(108, 12, 192, 12, 192, 56)
          ..close();
        canvas.drawPath(dome, Paint()..color = const Color(0xFF3BA4EC));
        canvas.drawCircle(
            const Offset(150, 14), 7, Paint()..color = const Color(0xFF2E86C4));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(140, 48, 92, 14), const Radius.circular(7)),
            Paint()..color = const Color(0xFF2E86C4));
      case 'flowercrown': // はなかんむり
        for (var i = 0; i < 5; i++) {
          final cx = 106.0 + i * 22;
          final cy = i.isEven ? 46.0 : 38.0;
          final petal = Paint()
            ..color =
                i.isEven ? const Color(0xFFFF9CC2) : const Color(0xFFFFD23E);
          for (final a in const [0.0, 1.26, 2.51, 3.77, 5.03]) {
            canvas.drawCircle(
                Offset(cx + 7 * cos(a), cy + 7 * sin(a)), 5, petal);
          }
          canvas.drawCircle(
              Offset(cx, cy),
              4,
              Paint()
                ..color = i.isEven ? const Color(0xFFFFD23E) : Colors.white);
        }
      case 'propeller': // プロペラぼうし
        canvas.drawArc(
            Rect.fromCircle(center: const Offset(150, 58), radius: 40),
            3.14159,
            3.14159,
            true,
            Paint()..color = const Color(0xFFFF8F1F));
        canvas.drawLine(
            const Offset(150, 22),
            const Offset(150, 40),
            Paint()
              ..color = inkColor
              ..strokeWidth = 5);
        final blade = Paint()..color = const Color(0xFF54B9FF);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(118, 20), width: 52, height: 14),
            blade);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(182, 20), width: 52, height: 14),
            blade);
        canvas.drawCircle(
            const Offset(150, 20), 7, Paint()..color = const Color(0xFFFFD23E));
      case 'bearears': // くまみみ
        final ear = Paint()..color = const Color(0xFF9C6B44);
        final inner = Paint()..color = const Color(0xFFD9A97E);
        canvas.drawCircle(const Offset(102, 58), 26, ear);
        canvas.drawCircle(const Offset(198, 58), 26, ear);
        canvas.drawCircle(const Offset(102, 60), 14, inner);
        canvas.drawCircle(const Offset(198, 60), 14, inner);
      case 'halo': // てんしのわ
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(150, 10), width: 92, height: 24),
            Paint()
              ..color = const Color(0xFFFFD23E)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8);
      case 'heartglass': // ハートめがね
        _heart(canvas, const Offset(112, 148), 52, const Color(0xFFFF4F96));
        _heart(canvas, const Offset(188, 148), 52, const Color(0xFFFF4F96));
        canvas.drawLine(
            const Offset(134, 148),
            const Offset(166, 148),
            Paint()
              ..color = const Color(0xFFFF4F96)
              ..strokeWidth = 6);
      case 'starglass': // ほしめがね
        _star(canvas, const Offset(112, 150), 58, const Color(0xFFFFB300));
        _star(canvas, const Offset(188, 150), 58, const Color(0xFFFFB300));
        canvas.drawLine(
            const Offset(134, 150),
            const Offset(166, 150),
            Paint()
              ..color = const Color(0xFFFFB300)
              ..strokeWidth = 6);
      case 'groucho': // はなメガネ(めがね+大きな鼻+ひげ)
        final stroke = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;
        canvas.drawCircle(const Offset(112, 148), 24, stroke);
        canvas.drawCircle(const Offset(188, 148), 24, stroke);
        canvas.drawLine(const Offset(136, 148), const Offset(164, 148), stroke);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(150, 178), width: 34, height: 42),
            Paint()..color = const Color(0xFFF2A29B));
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(150, 205), width: 64, height: 18),
            Paint()..color = const Color(0xFF5C4033));
      case 'clownnose': // ピエロのはな
        canvas.drawCircle(const Offset(150, 170), 17,
            Paint()..color = const Color(0xFFFF4B4B));
        canvas.drawCircle(const Offset(144, 164), 5,
            Paint()..color = Colors.white.withValues(alpha: 0.7));
      case 'monocle': // モノクル(かた目+くさり)
        canvas.drawCircle(
            const Offset(188, 150),
            24,
            Paint()
              ..color = const Color(0xFFF0A92D)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6);
        final chain = Path()
          ..moveTo(206, 166)
          ..quadraticBezierTo(220, 190, 212, 214);
        canvas.drawPath(
            chain,
            Paint()
              ..color = const Color(0xFFF0A92D)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
      case 'cheekseal': // ほっぺシール(ハート)
        _heart(canvas, const Offset(95, 180), 20, const Color(0xFFFF4F96));
        _heart(canvas, const Offset(205, 180), 20, const Color(0xFFFF4F96));
      case 'eyepatch': // かいぞくがんたい(右目)
        canvas.drawLine(
            const Offset(64, 122),
            const Offset(228, 158),
            Paint()
              ..color = inkColor
              ..strokeWidth = 9);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(188, 150), width: 52, height: 44),
            Paint()..color = inkColor);
      case 'whiskers': // ねこひげ+ピンクの鼻
        final w = Paint()
          ..color = inkColor
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(46, 160), const Offset(92, 166), w);
        canvas.drawLine(const Offset(44, 180), const Offset(92, 180), w);
        canvas.drawLine(const Offset(46, 200), const Offset(92, 194), w);
        canvas.drawLine(const Offset(254, 160), const Offset(208, 166), w);
        canvas.drawLine(const Offset(256, 180), const Offset(208, 180), w);
        canvas.drawLine(const Offset(254, 200), const Offset(208, 194), w);
        canvas.drawPath(
            Path()
              ..moveTo(143, 170)
              ..lineTo(157, 170)
              ..lineTo(150, 179)
              ..close(),
            Paint()..color = const Color(0xFFFF6EA6));
      case 'mask': // ますく
        final maskRect = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: const Offset(150, 196), width: 116, height: 74),
            const Radius.circular(24));
        canvas.drawRRect(maskRect, Paint()..color = Colors.white);
        canvas.drawRRect(
            maskRect,
            Paint()
              ..color = const Color(0xFFD8DBE8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
        final strap = Paint()
          ..color = const Color(0xFFD8DBE8)
          ..strokeWidth = 5;
        canvas.drawLine(const Offset(92, 186), const Offset(58, 168), strap);
        canvas.drawLine(const Offset(208, 186), const Offset(242, 168), strap);
      case 'starcheeks': // キラキラほっぺ
        _star(canvas, const Offset(95, 180), 26, const Color(0xFFFFB300));
        _star(canvas, const Offset(205, 180), 26, const Color(0xFFFFB300));
        _star(canvas, const Offset(108, 202), 14, const Color(0xFFFFD23E));
        _star(canvas, const Offset(192, 202), 14, const Color(0xFFFFD23E));
    }
  }

  /// アイテム用の小さな星(中心・幅・色)。
  static void _star(Canvas canvas, Offset c, double size, Color color) {
    final r = size / 2;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -3.14159 / 2 + i * 3.14159 / 5;
      final p = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// アイテム用の小さなハート(中心・幅・色)。
  static void _heart(Canvas canvas, Offset c, double size, Color color) {
    final w = size / 2;
    final path = Path()
      ..moveTo(c.dx, c.dy + w)
      ..cubicTo(c.dx - w * 1.4, c.dy, c.dx - w * 0.9, c.dy - w * 1.1, c.dx,
          c.dy - w * 0.3)
      ..cubicTo(
          c.dx + w * 0.9, c.dy - w * 1.1, c.dx + w * 1.4, c.dy, c.dx, c.dy + w)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
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

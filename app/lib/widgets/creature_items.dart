import 'dart:math';

import 'package:flutter/material.dart';

import 'creature_faces.dart';
import 'ui_kit.dart';

/// きせかえアイテムの描画(プロトタイプ ITEM_SVG を移植)。
/// creature_faces.dart と同じ分割方針で CreaturePainter から切り出した
/// (docs/review-findings.md #30)。座標系は viewBox 300x300。
// ---------- きせかえ(プロトタイプ ITEM_SVG を移植) ----------

void paintEquipItem(Canvas canvas, String key) {
  switch (key) {
    case 'ribbon':
      canvas.save();
      canvas.translate(196, 44);
      canvas.rotate(18 * pi / 180);
      final wing = Paint()..color = const Color(0xFFFF6EA6);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(-30, -16)
          ..lineTo(-30, 16)
          ..close(),
        wing,
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(30, -16)
          ..lineTo(30, 16)
          ..close(),
        wing,
      );
      canvas.drawCircle(
        Offset.zero,
        8,
        Paint()..color = const Color(0xFFFF4F96),
      );
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
        Offset.zero,
        7,
        Paint()..color = const Color(0xFFFFD23E),
      );
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
        center: const Offset(150, 54),
        width: 144,
        height: 28,
      );
      canvas.drawOval(brim, straw);
      canvas.drawOval(brim, strawStroke);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(112, 40, 76, 10),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFFF8F1F),
      );
    case 'tophat':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(85, 46, 130, 16),
          const Radius.circular(8),
        ),
        inkFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(107, 2, 86, 52),
          const Radius.circular(9),
        ),
        inkFill,
      );
      canvas.drawRect(
        const Rect.fromLTWH(107, 36, 86, 12),
        Paint()..color = const Color(0xFFFF6EA6),
      );
    case 'glasses':
      final stroke = inkStroke(6);
      canvas.drawCircle(const Offset(112, 150), 25, stroke);
      canvas.drawCircle(const Offset(188, 150), 25, stroke);
      _eyeBridge(canvas, 137, 163, 150, inkColor, 6);
    case 'sunglass':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(84, 131, 54, 36),
          const Radius.circular(13),
        ),
        inkFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(162, 131, 54, 36),
          const Radius.circular(13),
        ),
        inkFill,
      );
      canvas.drawRect(const Rect.fromLTWH(136, 141, 28, 8), inkFill);
      final temple = Paint()..color = const Color(0xFF6B7288);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(92, 137, 18, 7),
          const Radius.circular(3.5),
        ),
        temple,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(170, 137, 18, 7),
          const Radius.circular(3.5),
        ),
        temple,
      );
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
        const Offset(150, -8),
        9,
        Paint()..color = const Color(0xFF54B9FF),
      );
    case 'wizard': // とんがりぼうし(むらさき+星)
      final hat = Path()
        ..moveTo(150, -14)
        ..lineTo(112, 52)
        ..lineTo(188, 52)
        ..close();
      canvas.drawPath(hat, Paint()..color = const Color(0xFF7C6CF0));
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 54), width: 108, height: 20),
        Paint()..color = const Color(0xFF6555D6),
      );
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
          ..strokeWidth = 9,
      );
      for (final d in const [
        (Offset(122, 34), 7.0),
        (Offset(150, 22), 10.0),
        (Offset(178, 34), 7.0),
      ]) {
        canvas.drawCircle(d.$1, d.$2, Paint()..color = const Color(0xFFFF6EA6));
        canvas.drawCircle(
          d.$1,
          d.$2,
          Paint()
            ..color = const Color(0xFFF0A92D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    case 'cap': // キャップ(ドーム+つば)
      final dome = Path()
        ..moveTo(108, 56)
        ..cubicTo(108, 12, 192, 12, 192, 56)
        ..close();
      canvas.drawPath(dome, Paint()..color = const Color(0xFF3BA4EC));
      canvas.drawCircle(
        const Offset(150, 14),
        7,
        Paint()..color = const Color(0xFF2E86C4),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(140, 48, 92, 14),
          const Radius.circular(7),
        ),
        Paint()..color = const Color(0xFF2E86C4),
      );
    case 'flowercrown': // はなかんむり
      for (var i = 0; i < 5; i++) {
        final cx = 106.0 + i * 22;
        final cy = i.isEven ? 46.0 : 38.0;
        final petal = Paint()
          ..color =
              i.isEven ? const Color(0xFFFF9CC2) : const Color(0xFFFFD23E);
        for (final a in const [0.0, 1.26, 2.51, 3.77, 5.03]) {
          canvas.drawCircle(Offset(cx + 7 * cos(a), cy + 7 * sin(a)), 5, petal);
        }
        canvas.drawCircle(
          Offset(cx, cy),
          4,
          Paint()..color = i.isEven ? const Color(0xFFFFD23E) : Colors.white,
        );
      }
    case 'propeller': // プロペラぼうし
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(150, 58), radius: 40),
        pi,
        pi,
        true,
        Paint()..color = const Color(0xFFFF8F1F),
      );
      canvas.drawLine(
        const Offset(150, 22),
        const Offset(150, 40),
        Paint()
          ..color = inkColor
          ..strokeWidth = 5,
      );
      final blade = Paint()..color = const Color(0xFF54B9FF);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(118, 20), width: 52, height: 14),
        blade,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(182, 20), width: 52, height: 14),
        blade,
      );
      canvas.drawCircle(
        const Offset(150, 20),
        7,
        Paint()..color = const Color(0xFFFFD23E),
      );
    case 'bearears': // くまみみ
      final ear = Paint()..color = const Color(0xFF9C6B44);
      final inner = Paint()..color = const Color(0xFFD9A97E);
      canvas.drawCircle(const Offset(102, 58), 26, ear);
      canvas.drawCircle(const Offset(198, 58), 26, ear);
      canvas.drawCircle(const Offset(102, 60), 14, inner);
      canvas.drawCircle(const Offset(198, 60), 14, inner);
    case 'halo': // てんしのわ
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 10), width: 92, height: 24),
        Paint()
          ..color = const Color(0xFFFFD23E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
    case 'heartglass': // ハートめがね
      _heart(canvas, const Offset(112, 148), 52, const Color(0xFFFF4F96));
      _heart(canvas, const Offset(188, 148), 52, const Color(0xFFFF4F96));
      _eyeBridge(canvas, 134, 166, 148, const Color(0xFFFF4F96), 6);
    case 'starglass': // ほしめがね
      _star(canvas, const Offset(112, 150), 58, const Color(0xFFFFB300));
      _star(canvas, const Offset(188, 150), 58, const Color(0xFFFFB300));
      _eyeBridge(canvas, 134, 166, 150, const Color(0xFFFFB300), 6);
    case 'groucho': // はなメガネ(めがね+大きな鼻+ひげ)
      final stroke = Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawCircle(const Offset(112, 148), 24, stroke);
      canvas.drawCircle(const Offset(188, 148), 24, stroke);
      _eyeBridge(canvas, 136, 164, 148, inkColor, 6);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 178), width: 34, height: 42),
        Paint()..color = const Color(0xFFF2A29B),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 205), width: 64, height: 18),
        Paint()..color = const Color(0xFF5C4033),
      );
    case 'clownnose': // ピエロのはな
      canvas.drawCircle(
        const Offset(150, 170),
        17,
        Paint()..color = const Color(0xFFFF4B4B),
      );
      canvas.drawCircle(
        const Offset(144, 164),
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    case 'monocle': // モノクル(かた目+くさり)
      canvas.drawCircle(
        const Offset(188, 150),
        24,
        Paint()
          ..color = const Color(0xFFF0A92D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      final chain = Path()
        ..moveTo(206, 166)
        ..quadraticBezierTo(220, 190, 212, 214);
      canvas.drawPath(
        chain,
        Paint()
          ..color = const Color(0xFFF0A92D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    case 'cheekseal': // ほっぺシール(ハート)
      _heart(canvas, const Offset(95, 180), 20, const Color(0xFFFF4F96));
      _heart(canvas, const Offset(205, 180), 20, const Color(0xFFFF4F96));
    case 'eyepatch': // かいぞくがんたい(右目)
      canvas.drawLine(
        const Offset(64, 122),
        const Offset(228, 158),
        Paint()
          ..color = inkColor
          ..strokeWidth = 9,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(188, 150), width: 52, height: 44),
        Paint()..color = inkColor,
      );
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
        Paint()..color = const Color(0xFFFF6EA6),
      );
    case 'mask': // ますく
      final maskRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(150, 196), width: 116, height: 74),
        const Radius.circular(24),
      );
      canvas.drawRRect(maskRect, Paint()..color = Colors.white);
      canvas.drawRRect(
        maskRect,
        Paint()
          ..color = const Color(0xFFD8DBE8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
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
    case 'pumpkinhat': // かぼちゃぼうし
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 42), width: 92, height: 60),
        Paint()..color = const Color(0xFFFF8F1F),
      );
      final rib = Paint()
        ..color = const Color(0xFFE0701A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final dx in const [-24.0, 0.0, 24.0]) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(150 + dx, 42), width: 20, height: 58),
          pi / 2,
          pi,
          false,
          rib,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(144, 6, 12, 16),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF5FA857),
      );
    case 'snowhat': // ゆきのぼうし
      final dome = Path()
        ..moveTo(106, 56)
        ..cubicTo(106, 10, 194, 10, 194, 56)
        ..close();
      canvas.drawPath(dome, Paint()..color = Colors.white);
      canvas.drawPath(
        dome,
        Paint()
          ..color = const Color(0xFFBBDFFB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(100, 46, 100, 16),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0xFFBBDFFB),
      );
      canvas.drawCircle(
        const Offset(150, 10),
        11,
        Paint()..color = Colors.white,
      );
    case 'gradcap': // がくしぼう
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(118, 38, 64, 14),
          const Radius.circular(4),
        ),
        inkFill,
      );
      canvas.drawPath(
        Path()
          ..moveTo(150, 4)
          ..lineTo(206, 30)
          ..lineTo(150, 56)
          ..lineTo(94, 30)
          ..close(),
        inkFill,
      );
      canvas.drawCircle(
        const Offset(150, 30),
        6,
        Paint()..color = const Color(0xFFFFD23E),
      );
      canvas.drawLine(
        const Offset(150, 30),
        const Offset(168, 54),
        Paint()
          ..color = const Color(0xFFFFD23E)
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        const Offset(168, 56),
        5,
        Paint()..color = const Color(0xFFFFD23E),
      );
    case 'rabbitears': // うさみみカチューシャ
      final earOuter = Paint()..color = Colors.white;
      final earInner = Paint()..color = const Color(0xFFFF9CC2);
      for (final dx in const [-26.0, 26.0]) {
        canvas.save();
        canvas.translate(150 + dx, 20);
        canvas.rotate(dx > 0 ? 0.15 : -0.15);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 22, height: 62),
          earOuter,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 10, height: 44),
          earInner,
        );
        canvas.restore();
      }
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(150, 58), radius: 40),
        3.4,
        2.0,
        false,
        Paint()
          ..color = const Color(0xFFF2C9DE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    case 'beeantenna': // みつばちカチューシャ
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(150, 70), radius: 46),
        3.4,
        2.0,
        false,
        Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      for (final dx in const [-20.0, 20.0]) {
        canvas.drawLine(
          Offset(150 + dx, 40),
          Offset(150 + dx * 1.3, 8),
          Paint()
            ..color = inkColor
            ..strokeWidth = 4,
        );
        canvas.drawCircle(
          Offset(150 + dx * 1.3, 8),
          8,
          Paint()..color = const Color(0xFFFFD23E),
        );
      }
    case 'sunflowerhat': // ひまわりぼうし
      canvas.save();
      canvas.translate(150, 36);
      final petal = Paint()..color = const Color(0xFFFFD23E);
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawCircle(Offset(20 * cos(a), 20 * sin(a)), 13, petal);
      }
      canvas.drawCircle(
        Offset.zero,
        15,
        Paint()..color = const Color(0xFF8B5E34),
      );
      canvas.restore();
    case 'xmashat': // クリスマスぼうし
      final cone = Path()
        ..moveTo(112, 50)
        ..quadraticBezierTo(150, -20, 196, 30)
        ..lineTo(112, 50)
        ..close();
      canvas.drawPath(cone, Paint()..color = const Color(0xFFE84C4C));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(104, 42, 96, 16),
          const Radius.circular(8),
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        const Offset(196, 30),
        11,
        Paint()..color = Colors.white,
      );
    case 'donuthat': // ドーナツぼうし
      canvas.drawCircle(
        const Offset(150, 30),
        24,
        Paint()
          ..color = const Color(0xFFF5A9C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      const sprinkles = [
        Color(0xFFFFD23E),
        Color(0xFF54B9FF),
        Color(0xFF34C98E),
        Color(0xFFFF6EA6),
        Color(0xFFFFFFFF),
      ];
      for (var i = 0; i < 7; i++) {
        final a = i * 2 * pi / 7;
        canvas.drawCircle(
          Offset(150 + 24 * cos(a), 30 + 24 * sin(a)),
          3,
          Paint()..color = sprinkles[i % sprinkles.length],
        );
      }
    case 'goggles': // ゴーグル
      final rim = Paint()..color = const Color(0xFF3BA4EC);
      canvas.drawCircle(const Offset(112, 150), 28, rim);
      canvas.drawCircle(const Offset(188, 150), 28, rim);
      canvas.drawCircle(
        const Offset(112, 150),
        21,
        Paint()..color = const Color(0xFFBEE6FF),
      );
      canvas.drawCircle(
        const Offset(188, 150),
        21,
        Paint()..color = const Color(0xFFBEE6FF),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(130, 142, 40, 16),
          const Radius.circular(8),
        ),
        rim,
      );
    case 'pignose': // ぶたばな
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 188), width: 52, height: 38),
        Paint()..color = const Color(0xFFFFAFC0),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 188), width: 52, height: 38),
        Paint()
          ..color = const Color(0xFFE8869C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(139, 188), width: 8, height: 12),
        Paint()..color = const Color(0xFFC96C82),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(161, 188), width: 8, height: 12),
        Paint()..color = const Color(0xFFC96C82),
      );
    case 'bandaid': // ばんそうこう
      canvas.save();
      canvas.translate(96, 196);
      canvas.rotate(-0.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, -8, 36, 16),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFFF3D2B3),
      );
      canvas.drawCircle(
        const Offset(-8, 0),
        1.6,
        Paint()..color = const Color(0xFFCBA37C),
      );
      canvas.drawCircle(
        const Offset(8, 0),
        1.6,
        Paint()..color = const Color(0xFFCBA37C),
      );
      canvas.restore();
    case 'teardrop': // なみだステッカー
      final drop = Path()
        ..moveTo(112, 158)
        ..quadraticBezierTo(122, 176, 112, 188)
        ..quadraticBezierTo(102, 176, 112, 158)
        ..close();
      canvas.drawPath(drop, Paint()..color = const Color(0xFF6CC4FF));
      canvas.drawPath(
        drop,
        Paint()
          ..color = const Color(0xFF3BA4EC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    case 'kissmark': // キスマーク
      final lip = Paint()..color = const Color(0xFFE8497B);
      canvas.save();
      canvas.translate(112, 178);
      canvas.rotate(-0.3);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-6, 0), width: 20, height: 14),
        lip,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(6, 0), width: 20, height: 14),
        lip,
      );
      canvas.restore();
    case 'mooncheek': // つきのほっぺ(三日月シール)
      canvas.saveLayer(
        Rect.fromCircle(center: const Offset(205, 182), radius: 16),
        Paint(),
      );
      canvas.drawCircle(
        const Offset(205, 182),
        14,
        Paint()..color = const Color(0xFFFFD9A0),
      );
      canvas.drawCircle(
        const Offset(211, 178),
        13,
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();
    case 'flowercheek': // おはなシール
      canvas.save();
      canvas.translate(95, 190);
      final cheekPetal = Paint()..color = const Color(0xFFFFC2E0);
      for (final a in const [0.0, 1.26, 2.51, 3.77, 5.03]) {
        canvas.drawCircle(Offset(6 * cos(a), 6 * sin(a)), 5, cheekPetal);
      }
      canvas.drawCircle(
        Offset.zero,
        4,
        Paint()..color = const Color(0xFFFFD23E),
      );
      canvas.restore();
    case 'rainbowglass': // にじめがね
      final frame = inkStroke(5);
      canvas.drawCircle(const Offset(112, 150), 25, frame);
      canvas.drawCircle(const Offset(188, 150), 25, frame);
      _eyeBridge(canvas, 137, 163, 150, inkColor, 5);
      const rainbow = [
        Color(0xFFFF6EA6),
        Color(0xFFFFAB49),
        Color(0xFFFFD23E),
        Color(0xFF34C98E),
        Color(0xFF54B9FF),
        Color(0xFF9B8CFF),
      ];
      for (final cx in const [112.0, 188.0]) {
        canvas.save();
        canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: Offset(cx, 150), radius: 23)),
        );
        for (var i = 0; i < rainbow.length; i++) {
          canvas.drawRect(
            Rect.fromLTWH(cx - 23, 127.0 + i * 7.6, 46, 8),
            Paint()..color = rainbow[i],
          );
        }
        canvas.restore();
      }
  }
}

/// めがね系アイテムの左右レンズをつなぐ橋。
void _eyeBridge(
  Canvas canvas,
  double leftX,
  double rightX,
  double y,
  Color color,
  double strokeWidth,
) {
  canvas.drawLine(
    Offset(leftX, y),
    Offset(rightX, y),
    Paint()
      ..color = color
      ..strokeWidth = strokeWidth,
  );
}

/// アイテム用の小さな星(中心・幅・色)。
void _star(Canvas canvas, Offset c, double size, Color color) {
  final r = size / 2;
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + i * pi / 5;
    final p = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

/// アイテム用の小さなハート(中心・幅・色)。
void _heart(Canvas canvas, Offset c, double size, Color color) {
  final w = size / 2;
  final path = Path()
    ..moveTo(c.dx, c.dy + w)
    ..cubicTo(
      c.dx - w * 1.4,
      c.dy,
      c.dx - w * 0.9,
      c.dy - w * 1.1,
      c.dx,
      c.dy - w * 0.3,
    )
    ..cubicTo(
      c.dx + w * 0.9,
      c.dy - w * 1.1,
      c.dx + w * 1.4,
      c.dy,
      c.dx,
      c.dy + w,
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

import 'dart:math';

import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// 種族ごとの顔描画(CreaturePainter から分離)。座標系は 300x300。
/// 悲しい顔バリアントは docs/game-design.md §4。

/// 種族ごとの顔を描く(プロトタイプ faceSvg() の移植)。
void paintCreatureFace(
  Canvas canvas, {
  required int speciesIndex,
  required bool sad,
}) {
  switch (speciesIndex) {
    case 4:
      _faceBero(canvas, sad);
    case 5:
      _faceBuu(canvas, sad);
    case 6:
      _faceMedama(canvas, sad);
    case 7:
      _faceNyan(canvas, sad);
    case 8:
      _faceDandy(canvas, sad);
    case 9:
      _faceMojya(canvas, sad);
    case 10:
      _faceGuru(canvas, sad);
    case 11:
      _facePaku(canvas, sad);
    case 12:
      _faceNemu(canvas, sad);
    case 13:
      _faceRobo(canvas, sad);
    case 14:
      _faceObake(canvas, sad);
    default:
      _faceDefault(canvas, sad);
  }
}

Paint get inkFill => Paint()..color = inkColor;
Paint inkStroke(double w) => Paint()
  ..color = inkColor
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

void _cheeks(Canvas canvas, double lx, double rx, double y) {
  final cheek = Paint()..color = const Color(0xFFFF9CC2).withValues(alpha: 0.7);
  canvas.drawCircle(Offset(lx, y), 11, cheek);
  canvas.drawCircle(Offset(rx, y), 11, cheek);
}

void _faceDefault(Canvas canvas, bool sad) {
  canvas.drawCircle(const Offset(112, 150), 13, inkFill);
  canvas.drawCircle(const Offset(188, 150), 13, inkFill);
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
  canvas.drawPath(mouth, inkStroke(6));
}

/// bero: 大小バラバラの目玉 + 垂れた舌
void _faceBero(Canvas canvas, bool sad) {
  final white = Paint()..color = Colors.white;
  canvas.drawCircle(const Offset(105, 138), 27, white);
  canvas.drawCircle(const Offset(105, 138), 27, inkStroke(5));
  canvas.drawCircle(const Offset(98, 130), 11, inkFill);
  canvas.drawCircle(const Offset(194, 155), 15, white);
  canvas.drawCircle(const Offset(194, 155), 15, inkStroke(5));
  canvas.drawCircle(const Offset(199, 161), 7, inkFill);

  if (sad) {
    final wavy = Path()
      ..moveTo(122, 202)
      ..relativeQuadraticBezierTo(9, -9, 19, 0)
      ..relativeQuadraticBezierTo(9, 9, 19, 0)
      ..relativeQuadraticBezierTo(9, -9, 19, 0);
    canvas.drawPath(wavy, inkStroke(6));
    return;
  }
  final mouth = Path()
    ..moveTo(118, 186)
    ..quadraticBezierTo(150, 204, 182, 184);
  canvas.drawPath(mouth, inkStroke(6));
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
      ..strokeJoin = StrokeJoin.round,
  );
  final centerLine = Path()
    ..moveTo(154, 198)
    ..quadraticBezierTo(157, 215, 160, 226);
  canvas.drawPath(
    centerLine,
    Paint()
      ..color = const Color(0xFFE85D94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round,
  );
}

/// buu: 小さな目 + 巨大ぶた鼻 + 出っ歯
void _faceBuu(Canvas canvas, bool sad) {
  canvas.drawCircle(const Offset(97, 136), 7, inkFill);
  canvas.drawCircle(const Offset(203, 136), 7, inkFill);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 168), width: 72, height: 54),
    Paint()..color = const Color(0xFFFF9CB5),
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 168), width: 72, height: 54),
    Paint()
      ..color = const Color(0xFFE37F9C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );
  final nostril = Paint()..color = const Color(0xFFD95F85);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(136, 168), width: 16, height: 24),
    nostril,
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(164, 168), width: 16, height: 24),
    nostril,
  );

  if (sad) {
    canvas.drawLine(
      const Offset(82, 120),
      const Offset(108, 130),
      inkStroke(6),
    );
    canvas.drawLine(
      const Offset(218, 120),
      const Offset(192, 130),
      inkStroke(6),
    );
    final mouth = Path()
      ..moveTo(134, 216)
      ..quadraticBezierTo(150, 205, 166, 216);
    canvas.drawPath(mouth, inkStroke(6));
    return;
  }
  final mouth = Path()
    ..moveTo(116, 200)
    ..quadraticBezierTo(150, 224, 184, 200);
  canvas.drawPath(mouth, inkStroke(6));
  for (final x in [133.0, 152.0]) {
    final tooth = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, 202, 15, 17),
      const Radius.circular(3),
    );
    canvas.drawRRect(tooth, Paint()..color = Colors.white);
    canvas.drawRRect(
      tooth,
      Paint()
        ..color = const Color(0xFFD8DBE8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// medama: 一つ目 + 極太一本眉
void _faceMedama(Canvas canvas, bool sad) {
  canvas.save();
  canvas.translate(150, 93);
  canvas.rotate((sad ? 6 : -3) * pi / 180);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-42, -7.5, 84, 15),
      const Radius.circular(7.5),
    ),
    inkFill,
  );
  canvas.restore();

  canvas.drawCircle(const Offset(150, 142), 36, Paint()..color = Colors.white);
  canvas.drawCircle(const Offset(150, 142), 36, inkStroke(5));
  canvas.drawCircle(
    const Offset(150, 146),
    17,
    Paint()..color = const Color(0xFF6CC4FF),
  );
  canvas.drawCircle(const Offset(150, 146), 9, inkFill);
  canvas.drawCircle(const Offset(157, 138), 4.5, Paint()..color = Colors.white);
  _cheeks(canvas, 100, 200, 185);

  if (sad) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 206), width: 20, height: 26),
      inkFill,
    );
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
        Rect.fromLTWH(x, 192, 11, 10),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
  }
}

/// nyan: ねこ目+ひげ+ωのくち+ピンクの鼻
void _faceNyan(Canvas canvas, bool sad) {
  canvas.drawCircle(const Offset(112, 150), 13, inkFill);
  canvas.drawCircle(const Offset(188, 150), 13, inkFill);
  final white = Paint()..color = Colors.white;
  canvas.drawCircle(const Offset(116, 145), 4.5, white);
  canvas.drawCircle(const Offset(192, 145), 4.5, white);
  _cheeks(canvas, 95, 205, 180);

  final whisker = inkStroke(4);
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
    Paint()..color = const Color(0xFFFF6EA6),
  );

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
  canvas.drawPath(mouth, inkStroke(6));
}

/// dandy: ちいさな目+極太まゆ+巨大くるくるヒゲ
void _faceDandy(Canvas canvas, bool sad) {
  canvas.drawCircle(const Offset(108, 134), 7, inkFill);
  canvas.drawCircle(const Offset(192, 134), 7, inkFill);

  // まゆ(悲しいときは八の字)
  void brow(double cx, double cy, double deg) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(deg * pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -8, 52, 16),
        const Radius.circular(8),
      ),
      inkFill,
    );
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
    hige,
  );
  canvas.drawPath(
    Path()
      ..moveTo(150, 172)
      ..cubicTo(168, 160, 200, 162, 214, 178)
      ..cubicTo(220, 186, 214, 196, 204, 194)
      ..cubicTo(182, 190, 160, 184, 150, 180)
      ..close(),
    hige,
  );
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
  canvas.drawPath(mouth, inkStroke(6));
}

/// mojya: もじゃもじゃ頭に埋もれた ちいさな目と口
void _faceMojya(Canvas canvas, bool sad) {
  canvas.drawCircle(const Offset(120, 158), 7, inkFill);
  canvas.drawCircle(const Offset(180, 158), 7, inkFill);
  _cheeks(canvas, 98, 202, 182);
  final mouth = Path();
  if (sad) {
    mouth.moveTo(138, 200);
    mouth.quadraticBezierTo(150, 190, 162, 200);
  } else {
    mouth.moveTo(138, 192);
    mouth.quadraticBezierTo(150, 204, 162, 192);
  }
  canvas.drawPath(mouth, inkStroke(5));
}

/// guru: ぐるぐる目+ふらふらの口
void _faceGuru(Canvas canvas, bool sad) {
  for (final cx in [112.0, 188.0]) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, 150), radius: 15),
      0,
      4.7,
      false,
      inkStroke(6),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, 150), radius: 7),
      3.1,
      4.7,
      false,
      inkStroke(5),
    );
  }
  _cheeks(canvas, 95, 205, 182);
  // ふらふら波線の口(悲しいときは波が下向きに)
  final mouth = Path()..moveTo(124, sad ? 202 : 194);
  final amp = sad ? -7.0 : 7.0;
  mouth.relativeQuadraticBezierTo(9, amp, 17, 0);
  mouth.relativeQuadraticBezierTo(9, -amp, 17, 0);
  mouth.relativeQuadraticBezierTo(9, amp, 17, 0);
  canvas.drawPath(mouth, inkStroke(6));
}

/// paku: 顔の半分が口。目は上のほうに ちょこん
void _facePaku(Canvas canvas, bool sad) {
  canvas.drawCircle(const Offset(122, 112), 9, inkFill);
  canvas.drawCircle(const Offset(178, 112), 9, inkFill);
  if (sad) {
    final mouth = Path()
      ..moveTo(96, 216)
      ..quadraticBezierTo(150, 176, 204, 216);
    canvas.drawPath(mouth, inkStroke(9));
    return;
  }
  final mouth = Path()
    ..moveTo(92, 150)
    ..quadraticBezierTo(150, 132, 208, 150)
    ..quadraticBezierTo(214, 226, 150, 238)
    ..quadraticBezierTo(86, 226, 92, 150)
    ..close();
  canvas.drawPath(mouth, inkFill);
  canvas.save();
  canvas.clipPath(mouth);
  // 上の歯と舌
  canvas.drawRect(
    const Rect.fromLTWH(92, 138, 116, 22),
    Paint()..color = Colors.white,
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 236), width: 84, height: 52),
    Paint()..color = const Color(0xFFFF7EB0),
  );
  canvas.restore();
}

/// nemu: いつも寝てる。とじた目+よだれ+すーすー
void _faceNemu(Canvas canvas, bool sad) {
  final eye = inkStroke(6);
  canvas.drawLine(const Offset(98, 152), const Offset(128, 152), eye);
  canvas.drawLine(const Offset(172, 152), const Offset(202, 152), eye);
  _cheeks(canvas, 95, 205, 180);
  final mouth = Path();
  if (sad) {
    mouth.moveTo(136, 202);
    mouth.quadraticBezierTo(150, 192, 164, 202);
  } else {
    mouth.moveTo(140, 194);
    mouth.quadraticBezierTo(150, 202, 160, 194);
  }
  canvas.drawPath(mouth, inkStroke(5));
  // よだれ
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(168, 210), width: 12, height: 18),
    Paint()..color = const Color(0xAA9CD8FF),
  );
}

/// robo: 四角い目+ギザギザの口
void _faceRobo(Canvas canvas, bool sad) {
  for (final cx in [112.0, 188.0]) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, 148), width: 34, height: 28),
      const Radius.circular(6),
    );
    canvas.drawRRect(r, Paint()..color = Colors.white);
    canvas.drawRRect(r, inkStroke(5));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, sad ? 154 : 148),
        width: 12,
        height: 12,
      ),
      inkFill,
    );
  }
  final mouth = Path()..moveTo(120, sad ? 204 : 196);
  final amp = sad ? -10.0 : 10.0;
  mouth.relativeLineTo(10, amp);
  mouth.relativeLineTo(10, -amp);
  mouth.relativeLineTo(10, amp);
  mouth.relativeLineTo(10, -amp);
  mouth.relativeLineTo(10, amp);
  mouth.relativeLineTo(10, -amp);
  canvas.drawPath(mouth, inkStroke(6));
}

/// obake: うつろな たて長の目+まんまるの口
void _faceObake(Canvas canvas, bool sad) {
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(115, 148), width: 20, height: 34),
    inkFill,
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(185, 148), width: 20, height: 34),
    inkFill,
  );
  if (sad) {
    final mouth = Path()
      ..moveTo(132, 206)
      ..quadraticBezierTo(150, 192, 168, 206);
    canvas.drawPath(mouth, inkStroke(6));
    // なみだ
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(107, 176), width: 10, height: 16),
      Paint()..color = const Color(0xAA9CD8FF),
    );
    return;
  }
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 202), width: 34, height: 42),
    inkFill,
  );
}

// ---------- リアクション用の大げさ表情(全種族共通・一時的に顔を差し替える) ----------

/// リアクション中だけ出す誇張表情。docs/game-design.md §3。
enum CreatureMood { happy, surprised, yum }

/// 種族の顔の代わりに描く漫画的な表情(約1秒で元に戻る)。
void paintExpressionFace(Canvas canvas, {required CreatureMood mood}) {
  switch (mood) {
    case CreatureMood.happy:
      _happyFace(canvas);
    case CreatureMood.surprised:
      _surprisedFace(canvas);
    case CreatureMood.yum:
      _yumFace(canvas);
  }
}

/// にっこり: ∩∩の目+大きく開いた口+ほっぺ
void _happyFace(Canvas canvas) {
  final eye = inkStroke(9);
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(112, 152), radius: 18),
    pi,
    pi,
    false,
    eye,
  );
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(188, 152), radius: 18),
    pi,
    pi,
    false,
    eye,
  );

  final cheek = Paint()
    ..color = const Color(0xFFFF9CC2).withValues(alpha: 0.85);
  canvas.drawCircle(const Offset(90, 178), 14, cheek);
  canvas.drawCircle(const Offset(210, 178), 14, cheek);

  // 大きく開けて笑う口(下半円)+舌
  final mouth = Path()
    ..moveTo(112, 185)
    ..quadraticBezierTo(150, 248, 188, 185)
    ..close();
  canvas.drawPath(mouth, inkFill);
  canvas.save();
  canvas.clipPath(mouth);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 228), width: 56, height: 34),
    Paint()..color = const Color(0xFFFF7EB0),
  );
  canvas.restore();
}

/// びっくり: まん丸目+高い眉+ちいさな「お」の口
void _surprisedFace(Canvas canvas) {
  final white = Paint()..color = Colors.white;
  for (final cx in [112.0, 188.0]) {
    canvas.drawCircle(Offset(cx, 150), 22, white);
    canvas.drawCircle(Offset(cx, 150), 22, inkStroke(5));
    canvas.drawCircle(Offset(cx, 152), 7, inkFill);
  }
  // 高く上がった眉
  final brow = inkStroke(7);
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(112, 118), radius: 16),
    3.4,
    2.6,
    false,
    brow,
  );
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(188, 118), radius: 16),
    3.4,
    2.6,
    false,
    brow,
  );
  // 「お」の口
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 202), width: 22, height: 28),
    inkFill,
  );
}

/// あーん: とじた目+大きく開けた口+舌(ごはん用)
void _yumFace(Canvas canvas) {
  final eye = inkStroke(8);
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(112, 148), radius: 15),
    pi,
    pi,
    false,
    eye,
  );
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(188, 148), radius: 15),
    pi,
    pi,
    false,
    eye,
  );
  _cheeks(canvas, 92, 208, 176);

  final mouth = Rect.fromCenter(
    center: const Offset(150, 205),
    width: 62,
    height: 46,
  );
  canvas.drawOval(mouth, inkFill);
  canvas.save();
  canvas.clipPath(Path()..addOval(mouth));
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 222), width: 44, height: 26),
    Paint()..color = const Color(0xFFFF7EB0),
  );
  canvas.restore();
}

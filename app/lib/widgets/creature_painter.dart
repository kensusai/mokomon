import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/species.dart';
import 'creature_bodies.dart';
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

  /// 体形(輪郭)。ベビーは共通素体、stage2 以降は種族ごとの
  /// シルエット(creature_bodies.dart)。おえかきのマスクもこれを使う。
  static Path bodyPathFor(int species, int stage) =>
      stage <= 1 ? babyBodyPath() : bodySpecFor(species, stage).path;

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

    // キング=1.25 / ベビー=0.62(足元アンカー)。docs §3
    // こどもFB「進化が微々たる」: 中間を小さめ(0.95)にして段差を強調
    final scale = stage == 1
        ? 0.62
        : stage == kingStage
        ? 1.25
        : stage == 3
        ? 1.1
        : 0.95;
    canvas.translate(150 * (1 - scale), 270 * (1 - scale));
    canvas.scale(scale, scale);

    // stage2 以降は種族ごとの体形(輪郭+前後の装飾)。creature_bodies.dart
    final spec = stage >= 2
        ? bodySpecFor(speciesIndex, stage, equipHead: equipHead)
        : null;
    _paintBody(canvas, spec);
    spec?.front?.call(canvas, bodyColor);
    if (mood != null) {
      paintExpressionFace(canvas, mood: mood!);
    } else if (spec?.ownFace != null) {
      spec!.ownFace!(canvas, bodyColor, sad);
    } else {
      paintCreatureFace(canvas, speciesIndex: speciesIndex, sad: sad);
    }
    if (stage >= kingStage && equipHead == null && (spec?.crown ?? true)) {
      _paintCrown(canvas);
    }
    if (equipFace != null) paintEquipItem(canvas, equipFace!);
    if (equipHead != null) paintEquipItem(canvas, equipHead!);
  }

  // ---------- body ----------

  void _paintBody(Canvas canvas, BodySpec? spec) {
    if (stage == kingStage && (spec?.mantle ?? true)) _paintMantle(canvas);
    spec?.back?.call(canvas, bodyColor);

    final body = spec?.path ?? babyBodyPath();
    canvas.drawPath(body, Paint()..color = bodyColor);

    // キングはおなかに明るいパッチ(体格の変化を強調)
    if (stage == kingStage) {
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

    // 手(腕)は stage2 から生える(体形に手足を含む種族は描かない)
    if (stage >= 2 && (spec?.arms ?? true)) {
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

    if (spec?.feet ?? true) {
      final foot = Paint()..color = shade(bodyColor, -36);
      final footW = stage == 1 ? 38.0 : 48.0;
      for (final x in const [112.0, 188.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 258), width: footW, height: 24),
          foot,
        );
      }
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

/// 体色を amt(-255..255)ぶん明るく/暗くする(輪郭・手足・装飾の影用)。
Color shade(Color c, int amt) {
  double cl(double v) => (v + amt / 255.0).clamp(0.0, 1.0);
  return Color.from(alpha: 1, red: cl(c.r), green: cl(c.g), blue: cl(c.b));
}

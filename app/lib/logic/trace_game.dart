/// なぞってかこう(docs/game-design.md §5)。
/// 点線の形を指でなぞり、カバー率で星1〜3を獲得する。
library;

import 'dart:math';
import 'dart:ui';

/// 1セッションでなぞる形の数
const traceShapesPerSession = 3;

/// 判定: ターゲット点から この距離以内に線が通れば「なぞれた」
const traceHitDistance = 26.0;

/// 形の定義(300x300座標系)。
Path traceShapePath(String key) {
  switch (key) {
    case 'star':
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? 110.0 : 48.0;
        final a = -pi / 2 + i * pi / 5;
        final p = Offset(150 + r * cos(a), 158 + r * sin(a));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    case 'heart':
      return Path()
        ..moveTo(150, 250)
        ..cubicTo(60, 185, 30, 120, 55, 75)
        ..cubicTo(80, 30, 140, 40, 150, 95)
        ..cubicTo(160, 40, 220, 30, 245, 75)
        ..cubicTo(270, 120, 240, 185, 150, 250)
        ..close();
    case 'moon':
      return Path()
        ..moveTo(190, 40)
        ..arcToPoint(const Offset(190, 260),
            radius: const Radius.circular(115), clockwise: false)
        ..arcToPoint(const Offset(190, 40),
            radius: const Radius.circular(150), clockwise: true)
        ..close();
    case 'lightning':
      return Path()
        ..moveTo(170, 30)
        ..lineTo(95, 165)
        ..lineTo(145, 165)
        ..lineTo(120, 270)
        ..lineTo(205, 130)
        ..lineTo(155, 130)
        ..close();
    default: // circle
      return Path()
        ..addOval(Rect.fromCircle(center: const Offset(150, 150), radius: 105));
  }
}

const traceShapeKeys = ['star', 'heart', 'circle', 'moon', 'lightning'];

/// 形の輪郭上のターゲット点(等間隔サンプル)。
List<Offset> traceTargets(String key, {int count = 28}) {
  final metrics = traceShapePath(key).computeMetrics().toList();
  final total = metrics.fold(0.0, (a, m) => a + m.length);
  final targets = <Offset>[];
  var step = total / count;
  var next = 0.0;
  for (final m in metrics) {
    while (next < m.length) {
      final t = m.getTangentForOffset(next);
      if (t != null) targets.add(t.position);
      next += step;
    }
    next -= m.length;
  }
  return targets;
}

/// なぞりの採点: ターゲット点のうち、線が近くを通った割合。
double traceCoverage(List<Offset> targets, List<Offset> strokePoints) {
  if (targets.isEmpty || strokePoints.isEmpty) return 0;
  var hits = 0;
  for (final t in targets) {
    for (final p in strokePoints) {
      if ((t - p).distance <= traceHitDistance) {
        hits++;
        break;
      }
    }
  }
  return hits / targets.length;
}

/// カバー率 → 星(1〜3)とコイン。
(int stars, int coins) traceScore(double coverage) {
  if (coverage >= 0.85) return (3, 4);
  if (coverage >= 0.55) return (2, 3);
  return (1, 1);
}

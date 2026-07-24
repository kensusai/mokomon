import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../data/species.dart';
import 'creature_painter.dart' show shade;

/// 種族ごとの体形定義(こどもFB「イラストが全部似ている」)。
///
/// stage2 以降の体は種族ごとに別シルエットを持ち、進化パラメータ
/// t(stage2=0 / stage3=0.5 / キング=1)で輪郭そのものが育つ。
/// 顔は creature_faces.dart が (85..215, 115..210) 付近に描くため、
/// どの体形もこの領域を輪郭内に含めること。
class BodySpec {
  /// 体の輪郭。模様(おえかき)のクリップにもこのパスを使う。
  final Path path;

  /// 共通の腕・足を描くか(体形に手足を含む種族は false)。
  final bool arms;
  final bool feet;

  /// 体の後ろに描く装飾(たてがみ・しっぽ等)。
  final void Function(Canvas canvas, Color bodyColor)? back;

  /// 体の上に描く装飾(角・ひれ・ボルト等)。顔より先に描く。
  final void Function(Canvas canvas, Color bodyColor)? front;

  const BodySpec(
    this.path, {
    this.arms = true,
    this.feet = true,
    this.back,
    this.front,
  });
}

Path _oval(double cx, double cy, double w, double h) =>
    Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h));

Path _circle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

Path _rotOval(double cx, double cy, double w, double h, double deg) {
  final m = Matrix4Fallback.rotationAt(cx, cy, deg * pi / 180);
  return _oval(cx, cy, w, h).transform(m);
}

Path _poly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final pt in pts.skip(1)) {
    p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

Path _rrect(double l, double t, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)),
  );

Path _union(Iterable<Path> parts) =>
    parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));

/// dart:ui だけで回転行列を作る小さなヘルパー(vector_math 依存を避ける)。
class Matrix4Fallback {
  static Float64List rotationAt(double cx, double cy, double rad) {
    final c = cos(rad), s = sin(rad);
    // 平行移動(cx,cy) → 回転 → 平行移動(-cx,-cy) を1つの列優先4x4に畳む
    return Float64List.fromList([
      c, s, 0, 0, //
      -s, c, 0, 0, //
      0, 0, 1, 0, //
      cx - c * cx + s * cy, cy - s * cx - c * cy, 0, 1,
    ]);
  }
}

/// まわりに三角のとげ/毛を生やした円(とげ・もじゃ・ぴか用)。
Path _spikyCircle(
  double cx,
  double cy,
  double r,
  int count,
  double len, {
  double phase = 0,
}) {
  final parts = <Path>[_circle(cx, cy, r)];
  for (var i = 0; i < count; i++) {
    final a = phase + i * 2 * pi / count;
    final tip = Offset(cx + (r + len) * cos(a), cy + (r + len) * sin(a));
    final base1 = Offset(
      cx + r * 0.92 * cos(a - 0.22),
      cy + r * 0.92 * sin(a - 0.22),
    );
    final base2 = Offset(
      cx + r * 0.92 * cos(a + 0.22),
      cy + r * 0.92 * sin(a + 0.22),
    );
    parts.add(_poly([base1, tip, base2]));
  }
  return _union(parts);
}

/// 種族×進化段階の体形。stage が 1 以下の場合は呼ばないこと
/// (ベビーは CreaturePainter.babyBodyPath() の共通素体)。
BodySpec bodySpecFor(int species, int stage, {String? equipHead}) {
  final t = stage >= kingStage ? 1.0 : (stage == 3 ? 0.5 : 0.0);
  switch (species) {
    case 0: // moko: もこもこ雲ボディ。育つほどもこもこが増える
      return BodySpec(
        _union([
          _circle(150, 180, 92),
          for (var i = 0; i < 8; i++)
            _circle(
              150 + (92 + 6 * t) * cos(pi + i * pi / 7),
              168 + (86 + 6 * t) * sin(pi + i * pi / 7),
              24 + 10 * t,
            ),
        ]),
      );
    case 1: // pyon: 長い耳と大きなあんよが輪郭ごと生えたうさぎ
      return BodySpec(
        _union([
          _oval(150, 185, 158, 165),
          _rotOval(116, 72 - 18 * t, 42, 116 + 34 * t, -10),
          _rotOval(184, 72 - 18 * t, 42, 116 + 34 * t, 10),
          _oval(108, 262, 60, 26),
          _oval(192, 262, 60, 26),
        ]),
        feet: false,
        front: (canvas, body) {
          final inner = Paint()..color = const Color(0x73FFFFFF);
          canvas.drawPath(
            _rotOval(116, 74 - 18 * t, 20, 74 + 26 * t, -10),
            inner,
          );
          canvas.drawPath(
            _rotOval(184, 74 - 18 * t, 20, 74 + 26 * t, 10),
            inner,
          );
        },
      );
    case 2: // toge: 角ばったいわ+とげの結晶ボディ
      return BodySpec(
        _poly([
          Offset(150, 46 - 22 * t),
          const Offset(205, 84),
          Offset(246 + 8 * t, 152),
          const Offset(234, 226),
          const Offset(150, 266),
          const Offset(66, 226),
          Offset(54 - 8 * t, 152),
          const Offset(95, 84),
        ]),
      );
    case 3: // pika: たいようボディ。輪郭ごと光線が伸びる
      return BodySpec(
        _spikyCircle(150, 172, 96, 8, 18 + 26 * t, phase: -pi / 2),
        front: equipHead != null
            ? null
            : (canvas, body) {
                final star = _poly([
                  Offset(150, 30 - 26 * t),
                  const Offset(160, 58),
                  const Offset(150, 74),
                  const Offset(140, 58),
                ]);
                canvas.drawPath(star, Paint()..color = const Color(0xFFFFB200));
              },
      );
    case 4: // bero: とろけたゼリーボディ(すそから したたる)
      return BodySpec(
        _union([
          _rotOval(150, 158, 176, 188, -3 - 3 * t),
          _oval(108, 258, 40, 34),
          _oval(154, 264, 34, 30),
          _oval(196, 252 + 8 * t, 36, 30),
        ]),
        feet: false,
      );
    case 5: // buu: どっしり体型+まきまきしっぽ
      return BodySpec(
        _union([
          _oval(150, 198, 212 + 12 * t, 148),
          _oval(150, 122, 152, 96),
          _circle(260, 198, 14 + 8 * t),
        ]),
      );
    case 6: // medama: たてに伸びるたまご体型
      return BodySpec(
        _union([
          _oval(150, 104 - 14 * t, 112, 112),
          _oval(150, 198, 164, 144),
          _oval(150, 150, 136, 160 + 24 * t),
        ]),
      );
    case 7: // nyan: みみ・しっぽ一体のねこシルエット
      return BodySpec(
        _union([
          _oval(150, 185, 168, 162),
          _poly([
            const Offset(92, 100),
            Offset(100, 28 - 14 * t),
            const Offset(142, 74),
          ]),
          _poly([
            const Offset(208, 100),
            Offset(200, 28 - 14 * t),
            const Offset(158, 74),
          ]),
          _rotOval(243, 218, 78 + 22 * t, 26, -34),
        ]),
        front: (canvas, body) {
          final inner = Paint()..color = const Color(0x66FFFFFF);
          canvas.drawPath(
            _poly([
              const Offset(102, 88),
              const Offset(106, 46),
              const Offset(132, 74),
            ]),
            inner,
          );
          canvas.drawPath(
            _poly([
              const Offset(198, 88),
              const Offset(194, 46),
              const Offset(168, 74),
            ]),
            inner,
          );
        },
      );
    case 8: // dandy: しかくいジェントルマン体型
      return BodySpec(
        _rrect(64 - 6 * t, 84, 172 + 12 * t, 184, 40),
        front: (canvas, body) {
          // むねもとのベスト風のかげ
          canvas.drawPath(
            _poly([
              const Offset(118, 226),
              Offset(150, 252 + 6 * t),
              const Offset(182, 226),
              const Offset(150, 236),
            ]),
            Paint()..color = shade(body, -22),
          );
        },
      );
    case 9: // mojya: 全身もじゃもじゃ
      return BodySpec(_spikyCircle(150, 176, 90, 14, 16 + 16 * t, phase: 0.2));
    case 10: // guru: かたむいた ぐるぐるボディ
      return BodySpec(
        _union([
          _rotOval(158, 170, 184, 186, 6 + 4 * t),
          _circle(98, 216, 52),
          _circle(122, 86 - 10 * t, 30),
        ]),
      );
    case 11: // paku: おさかなボディ(せびれ・おびれ・むなびれ)
      return BodySpec(
        _union([
          _oval(150, 182, 216, 148),
          _poly([
            const Offset(244, 182),
            Offset(288 + 8 * t, 138 - 8 * t),
            Offset(288 + 8 * t, 226 + 8 * t),
          ]),
          _poly([
            Offset(150, 92 - 18 * t),
            const Offset(118, 122),
            const Offset(182, 122),
          ]),
        ]),
        arms: false,
        feet: false,
        front: (canvas, body) {
          final fin = Paint()..color = shade(body, -18);
          canvas.drawPath(_rotOval(64, 206, 52, 22, 30), fin);
        },
      );
    case 12: // nemu: くたっと下ぶくれの ねむねむボディ
      return BodySpec(
        _union([
          _oval(150, 196 + 6 * t, 192 + 12 * t, 148),
          _oval(150, 140, 150, 120),
          _rotOval(74, 152, 40, 92, 24),
          _rotOval(226, 152, 40, 92, -24),
        ]),
        back: t >= 1.0
            ? (canvas, body) {
                // キングは三日月をだっこ
                final moon = Path.combine(
                  PathOperation.difference,
                  _circle(252, 84, 30),
                  _circle(264, 76, 26),
                );
                canvas.drawPath(moon, Paint()..color = const Color(0xFFFFE08A));
              }
            : null,
      );
    case 13: // robo: 四角いボディ+アンテナ+キャタピラ
      return BodySpec(
        _union([
          _rrect(72 - 6 * t, 88, 156 + 12 * t, 172, 22),
          _rrect(146, 42, 8, 52, 4),
          _rrect(86, 246, 128, 22, 10),
        ]),
        feet: false,
        front: (canvas, body) {
          canvas.drawCircle(
            const Offset(150, 38),
            10 + 4 * t,
            Paint()..color = const Color(0xFFFF6E6E),
          );
          final bolt = Paint()..color = shade(body, -30);
          canvas.drawCircle(const Offset(92, 112), 7, bolt);
          canvas.drawCircle(const Offset(208, 112), 7, bolt);
        },
      );
    case 14: // obake: すそがひらひらのおばけ(足なし・浮遊)
      final hem = 236 + 10 * t;
      return BodySpec(
        _union([
          _circle(150, 140 - 8 * t, 96),
          _poly([
            const Offset(54, 140),
            const Offset(246, 140),
            Offset(246, hem),
            Offset(222, hem + 26),
            Offset(198, hem),
            Offset(174, hem + 26),
            Offset(150, hem),
            Offset(126, hem + 26),
            Offset(102, hem),
            Offset(78, hem + 26),
            Offset(54, hem),
          ]),
        ]),
        arms: false,
        feet: false,
      );
    case 15: // yuni: ポニー体型(四本あし+たてがみ+つの)。キングは首も脚も伸びる
      final legTop = 218.0 - 16 * t;
      return BodySpec(
        _union([
          _circle(150, 132 - 10 * t, 76 + 8 * t),
          _oval(150, 194 - 10 * t, 168 + 20 * t, 96 + 12 * t),
          _poly([
            const Offset(106, 74),
            Offset(96, 26 - 12 * t),
            const Offset(136, 58),
          ]),
          _poly([
            const Offset(194, 74),
            Offset(204, 26 - 12 * t),
            const Offset(164, 58),
          ]),
          for (final x in const [106.0, 134.0, 166.0, 194.0])
            _rrect(x - 10 - 4 * t, legTop, 20 + 4 * t, 268 - legTop, 9),
        ]),
        feet: false,
        back: (canvas, body) {
          // たてがみ(キングはレインボー)と しっぽ
          final maneColors = t >= 1.0
              ? const [Color(0xFFFF9CC2), Color(0xFFFFD98A), Color(0xFF9BD4FF)]
              : [shade(body, -28)];
          for (var layer = 0; layer < maneColors.length; layer++) {
            final paint = Paint()..color = maneColors[layer];
            final off = layer * 16.0;
            canvas.drawPath(
              _rotOval(66 - off * 0.3, 110 + off, 58, 130 + 34 * t, 20),
              paint,
            );
            canvas.drawPath(
              _rotOval(80 - off * 0.3, 176 + off * 0.8, 46, 96 + 22 * t, 10),
              paint,
            );
          }
          final tail = Paint()..color = maneColors.first;
          canvas.drawPath(_rotOval(240, 206, 88 + 24 * t, 28, 42), tail);
          if (t >= 1.0) {
            canvas.drawPath(
              _rotOval(236, 222, 76, 22, 56),
              Paint()..color = maneColors[2],
            );
          }
        },
        front: equipHead != null
            ? null
            : (canvas, body) {
                final horn = _poly([
                  const Offset(138, 70),
                  Offset(150, 12 - 14 * t),
                  const Offset(162, 70),
                ]);
                canvas.drawPath(horn, Paint()..color = const Color(0xFFFFE08A));
                final stripe = Paint()
                  ..color = const Color(0xFFE8A94C)
                  ..strokeWidth = 4
                  ..strokeCap = StrokeCap.round;
                canvas.drawLine(
                  const Offset(142, 52),
                  const Offset(158, 44),
                  stripe,
                );
                canvas.drawLine(
                  const Offset(145, 36),
                  const Offset(156, 30),
                  stripe,
                );
              },
      );
    default:
      return BodySpec(
        Path()
          ..moveTo(150, 42)
          ..cubicTo(222, 42, 262, 104, 262, 172)
          ..cubicTo(262, 242, 212, 268, 150, 268)
          ..cubicTo(88, 268, 38, 242, 38, 172)
          ..cubicTo(38, 104, 78, 42, 150, 42)
          ..close(),
      );
  }
}

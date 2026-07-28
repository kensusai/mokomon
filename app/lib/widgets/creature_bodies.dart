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

  /// 共通の顔システムを使わず自前で顔まで描く(横向きデザイン等)。
  /// リアクション表情(mood)中は共通の誇張顔が優先される。
  final void Function(Canvas canvas, Color bodyColor, bool sad)? ownFace;

  /// キングの王家マント・王冠を描くか(横向きデザイン等で邪魔なら false)。
  final bool mantle;
  final bool crown;

  const BodySpec(
    this.path, {
    this.arms = true,
    this.feet = true,
    this.back,
    this.front,
    this.ownFace,
    this.mantle = true,
    this.crown = true,
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

/// 固有パーツの固定色(体色の濃淡と別系統にして種族の配色をばらけさせる)。
const _pink = Color(0xFFFF9CC2);
const _gold = Color(0xFFFFD23E);
const _paleGold = Color(0xFFFFE08A);
const _goldShade = Color(0xFFE8A94C);
const _sky = Color(0xFF9BD4FF);
const _navy = Color(0xFF4A5390);
const _red = Color(0xFFFF6E6E);
const _orange = Color(0xFFFFA94D);
const _leaf = Color(0xFF57B66A);
const _mud = Color(0xFF9C6B44);

/// 4方向にとがる小さなキラキラ(ねむキングの星など)。
Path _sparkle(double cx, double cy, double r) => _poly([
  Offset(cx, cy - r),
  Offset(cx + r * 0.3, cy - r * 0.3),
  Offset(cx + r, cy),
  Offset(cx + r * 0.3, cy + r * 0.3),
  Offset(cx, cy + r),
  Offset(cx - r * 0.3, cy + r * 0.3),
  Offset(cx - r, cy),
  Offset(cx - r * 0.3, cy - r * 0.3),
]);

/// 種族×進化段階の体形。stage が 1 以下の場合は呼ばないこと
/// (ベビーは CreaturePainter.babyBodyPath() の共通素体)。
///
/// 進化は「サイズが少し育つ」ではなく**段階ごとに部位が増える**方針
/// (こどもFB「進化具合が微々たる」)。stage3 で新パーツ、キングで
/// 固有の必殺装飾が付く。
BodySpec bodySpecFor(int species, int stage, {String? equipHead}) {
  final t = stage >= kingStage ? 1.0 : (stage == 3 ? 0.5 : 0.0);
  final s3 = stage >= 3;
  final king = stage >= kingStage;
  switch (species) {
    case 0: // moko: 雲 → 芽が生える → 花ばたけキング
      return BodySpec(
        _union([
          _circle(150, 180, 92),
          for (var i = 0; i < 8; i++)
            _circle(
              150 + (92 + 8 * t) * cos(pi + i * pi / 7),
              168 + (86 + 8 * t) * sin(pi + i * pi / 7),
              24 + 12 * t,
            ),
        ]),
        front: (canvas, body) {
          if (s3 && equipHead == null) {
            // あたまから芽
            final stem = Paint()
              ..color = _leaf
              ..strokeWidth = 7
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(const Offset(150, 66), const Offset(150, 34), stem);
            final leafPaint = Paint()..color = _leaf;
            canvas.drawPath(_rotOval(132, 30, 34, 16, -28), leafPaint);
            canvas.drawPath(_rotOval(168, 30, 34, 16, 28), leafPaint);
          }
          if (king) {
            // 花ばたけ(5弁の花)
            for (final (cx, cy) in const [
              (84.0, 120.0),
              (218.0, 132.0),
              (108.0, 232.0),
              (204.0, 226.0),
            ]) {
              for (var i = 0; i < 5; i++) {
                final a = -pi / 2 + i * 2 * pi / 5;
                canvas.drawCircle(
                  Offset(cx + 9 * cos(a), cy + 9 * sin(a)),
                  6,
                  Paint()..color = _pink,
                );
              }
              canvas.drawCircle(
                Offset(cx, cy),
                5.5,
                Paint()..color = _paleGold,
              );
            }
          }
        },
      );
    case 1: // pyon: うさぎ → 耳がのびてリボン → もふもふ胸毛の女王
      return BodySpec(
        _union([
          _oval(150, 185, 158, 165),
          _rotOval(116, 76 - 34 * t, 42 + 6 * t, 108 + 62 * t, -10),
          _rotOval(184, 76 - 34 * t, 42 + 6 * t, 108 + 62 * t, 10),
          _oval(108, 262, 60, 26),
          _oval(192, 262, 60, 26),
        ]),
        feet: false,
        front: (canvas, body) {
          final inner = Paint()..color = const Color(0x73FFFFFF);
          canvas.drawPath(
            _rotOval(116, 78 - 34 * t, 20, 70 + 44 * t, -10),
            inner,
          );
          canvas.drawPath(
            _rotOval(184, 78 - 34 * t, 20, 70 + 44 * t, 10),
            inner,
          );
          if (king) {
            // もふもふの胸毛
            final fluff = Paint()..color = const Color(0xB3FFFFFF);
            for (final (cx, cy, r) in const [
              (128.0, 222.0, 17.0),
              (150.0, 230.0, 19.0),
              (172.0, 222.0, 17.0),
            ]) {
              canvas.drawCircle(Offset(cx, cy), r, fluff);
            }
          }
          if (s3) {
            // 左耳の大きなリボン
            final bow = Paint()..color = _red;
            final size = king ? 1.25 : 1.0;
            canvas.save();
            canvas.translate(110, 96 - 34 * t);
            canvas.rotate(-0.2);
            canvas.scale(size, size);
            canvas.drawPath(
              _poly([
                const Offset(-24, -12),
                const Offset(0, 0),
                const Offset(-24, 12),
              ]),
              bow,
            );
            canvas.drawPath(
              _poly([
                const Offset(24, -12),
                const Offset(0, 0),
                const Offset(24, 12),
              ]),
              bow,
            );
            canvas.drawCircle(Offset.zero, 6, bow);
            canvas.restore();
          }
        },
      );
    case 2: // toge: 結晶 → いなずまが生える → かみなり嵐のキング
      return BodySpec(
        _poly([
          Offset(150, 46 - 26 * t),
          const Offset(205, 84),
          Offset(246 + 10 * t, 152),
          const Offset(234, 226),
          const Offset(150, 266),
          const Offset(66, 226),
          Offset(54 - 10 * t, 152),
          const Offset(95, 84),
        ]),
        back: king
            ? (canvas, body) {
                // 浮かぶ雷のかけら
                final spark = Paint()..color = _gold;
                canvas.drawPath(
                  _poly([
                    const Offset(34, 96),
                    const Offset(52, 66),
                    const Offset(56, 92),
                  ]),
                  spark,
                );
                canvas.drawPath(
                  _poly([
                    const Offset(266, 96),
                    const Offset(248, 66),
                    const Offset(244, 92),
                  ]),
                  spark,
                );
              }
            : null,
        front: s3
            ? (canvas, body) {
                // 体からつき出す いなずま
                final bolt = Paint()..color = _gold;
                final k = king ? 1.4 : 1.0;
                canvas.save();
                canvas.translate(58, 140);
                canvas.scale(k, k);
                canvas.drawPath(
                  _poly([
                    const Offset(6, 0),
                    const Offset(-26, 6),
                    const Offset(-8, 12),
                    const Offset(-34, 26),
                    const Offset(2, 16),
                  ]),
                  bolt,
                );
                canvas.restore();
                canvas.save();
                canvas.translate(242, 140);
                canvas.scale(-k, k);
                canvas.drawPath(
                  _poly([
                    const Offset(6, 0),
                    const Offset(-26, 6),
                    const Offset(-8, 12),
                    const Offset(-34, 26),
                    const Offset(2, 16),
                  ]),
                  bolt,
                );
                canvas.restore();
              }
            : null,
      );
    case 3: // pika: たいよう → 光線が増える → 二重コロナのキング
      return BodySpec(
        _spikyCircle(150, 172, 96, s3 ? 12 : 8, 18 + 26 * t, phase: -pi / 2),
        back: king
            ? (canvas, body) {
                canvas.drawPath(
                  _spikyCircle(150, 172, 100, 12, 62, phase: -pi / 2 + pi / 12),
                  Paint()..color = _orange,
                );
              }
            : null,
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
    case 4: // bero: ゼリー → あわが出る → 水たまりでとろけるキング
      return BodySpec(
        _union([
          _rotOval(150, 158, 176, 188, -3 - 4 * t),
          _oval(108, 258, 40, 34),
          _oval(154, 264, 34, 30),
          _oval(196, 252 + 8 * t, 36, 30),
        ]),
        feet: false,
        back: king
            ? (canvas, body) {
                canvas.drawOval(
                  Rect.fromCenter(
                    center: const Offset(150, 262),
                    width: 250,
                    height: 30,
                  ),
                  Paint()..color = shade(body, 40),
                );
              }
            : null,
        front: s3
            ? (canvas, body) {
                final bubble = Paint()..color = const Color(0x66FFFFFF);
                canvas.drawCircle(const Offset(226, 96), 12, bubble);
                canvas.drawCircle(const Offset(246, 66), 8, bubble);
                if (king) {
                  canvas.drawCircle(const Offset(256, 110), 6, bubble);
                }
              }
            : null,
      );
    case 5: // buu: ぶた → どろんこ模様 → 天使のはねで飛ぶキング
      return BodySpec(
        _union([
          _oval(150, 198, 212 + 12 * t, 148),
          _oval(150, 122, 152, 96),
          _circle(260, 198, 14 + 8 * t),
        ]),
        back: king
            ? (canvas, body) {
                final wing = Paint()..color = const Color(0xF2FFFFFF);
                for (final side in const [-1.0, 1.0]) {
                  canvas.save();
                  canvas.translate(150 + side * 118, 150);
                  canvas.scale(side, 1);
                  canvas.drawPath(
                    _union([
                      _rotOval(-20, -10, 70, 30, -30),
                      _rotOval(-12, 8, 56, 24, -18),
                      _rotOval(-6, 24, 44, 20, -8),
                    ]),
                    wing,
                  );
                  canvas.restore();
                }
              }
            : null,
        front: s3
            ? (canvas, body) {
                final mudPaint = Paint()..color = _mud;
                canvas.drawPath(_rotOval(92, 236, 44, 18, -10), mudPaint);
                canvas.drawPath(_rotOval(212, 240, 36, 16, 12), mudPaint);
                if (king) {
                  canvas.drawPath(_rotOval(150, 252, 30, 12, 0), mudPaint);
                }
              }
            : null,
      );
    case 6: // medama: たまご → 目のまわりが光る → 小さな目玉をしたがえるキング
      return BodySpec(
        _union([
          _oval(150, 104 - 18 * t, 112, 112),
          _oval(150, 198, 164, 144),
          _oval(150, 150, 136, 160 + 30 * t),
        ]),
        back: king
            ? (canvas, body) {
                for (final (cx, cy) in const [(48.0, 130.0), (252.0, 130.0)]) {
                  canvas.drawCircle(
                    Offset(cx, cy),
                    20,
                    Paint()..color = const Color(0xFFFFFFFF),
                  );
                  canvas.drawCircle(
                    Offset(cx, cy),
                    9,
                    Paint()..color = const Color(0xFF3A66C8),
                  );
                  canvas.drawCircle(
                    Offset(cx, cy),
                    4,
                    Paint()..color = const Color(0xFF15224E),
                  );
                }
              }
            : null,
        front: s3
            ? (canvas, body) {
                canvas.drawCircle(
                  const Offset(150, 148),
                  58,
                  Paint()
                    ..color = const Color(0x59FFFFFF)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = king ? 14 : 8,
                );
              }
            : null,
      );
    case 7: // nyan: ねこ → しま模様 → 金のすずと二本しっぽのキング
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
          _rotOval(243, 218, 78 + 26 * t, 26, -34),
          if (king) _rotOval(238, 190, 92, 24, -52),
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
          if (s3) {
            final stripe = Paint()..color = shade(body, -34);
            canvas.drawPath(_rotOval(150, 96, 14, 34, 0), stripe);
            canvas.drawPath(_rotOval(128, 100, 12, 28, -14), stripe);
            canvas.drawPath(_rotOval(172, 100, 12, 28, 14), stripe);
          }
          if (king) {
            canvas.drawCircle(
              const Offset(150, 246),
              13,
              Paint()..color = _gold,
            );
            canvas.drawCircle(
              const Offset(150, 242),
              3.5,
              Paint()..color = _goldShade,
            );
            canvas.drawLine(
              const Offset(150, 246),
              const Offset(150, 256),
              Paint()
                ..color = _goldShade
                ..strokeWidth = 3,
            );
          }
        },
      );
    case 8: // dandy: しかく紳士 → 赤い蝶ネクタイ → タキシードのキング
      return BodySpec(
        _rrect(64 - 8 * t, 84, 172 + 16 * t, 184, 40),
        front: (canvas, body) {
          if (king) {
            // 白シャツ+ボタン
            canvas.drawPath(
              _poly([
                const Offset(122, 224),
                const Offset(150, 268),
                const Offset(178, 224),
                const Offset(150, 240),
              ]),
              Paint()..color = const Color(0xFFFFFFFF),
            );
            final button = Paint()..color = const Color(0xFF3A3F52);
            canvas.drawCircle(const Offset(150, 252), 3, button);
            canvas.drawCircle(const Offset(150, 262), 3, button);
          } else {
            canvas.drawPath(
              _poly([
                const Offset(118, 226),
                Offset(150, 252 + 6 * t),
                const Offset(182, 226),
                const Offset(150, 236),
              ]),
              Paint()..color = shade(body, -22),
            );
          }
          if (s3) {
            final bow = Paint()..color = _red;
            canvas.drawPath(
              _poly([
                const Offset(128, 218),
                const Offset(148, 226),
                const Offset(128, 236),
              ]),
              bow,
            );
            canvas.drawPath(
              _poly([
                const Offset(172, 218),
                const Offset(152, 226),
                const Offset(172, 236),
              ]),
              bow,
            );
            canvas.drawCircle(const Offset(150, 227), 5, bow);
          }
        },
      );
    case 9: // mojya: もじゃ → 毛がのびる → たてがみが光るキング
      return BodySpec(
        _spikyCircle(150, 176, 90, s3 ? 16 : 12, 14 + 26 * t, phase: 0.2),
        front: king
            ? (canvas, body) {
                canvas.drawPath(
                  _spikyCircle(150, 168, 64, 12, 14, phase: 0.4),
                  Paint()..color = shade(body, 30),
                );
              }
            : null,
      );
    case 10: // guru: かたむき → もっとかたむく → たつまきになるキング
      return BodySpec(
        king
            ? _union([
                _rotOval(158, 140, 190, 150, 8),
                _poly([
                  const Offset(70, 160),
                  const Offset(230, 160),
                  const Offset(150, 268),
                ]),
                _rotOval(150, 190, 150, 60, -4),
                _rotOval(152, 232, 96, 40, 5),
              ])
            : _union([
                _rotOval(158, 170, 184, 186, 6 + 8 * t),
                _circle(98, 216, 52),
                _circle(122, 86 - 14 * t, 30),
              ]),
        feet: !king,
        front: king
            ? (canvas, body) {
                final windPaint = Paint()
                  ..color = const Color(0x8CFFFFFF)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 7
                  ..strokeCap = StrokeCap.round;
                canvas.drawArc(
                  Rect.fromCenter(
                    center: const Offset(150, 196),
                    width: 130,
                    height: 40,
                  ),
                  pi * 0.1,
                  pi * 0.9,
                  false,
                  windPaint,
                );
                canvas.drawArc(
                  Rect.fromCenter(
                    center: const Offset(151, 236),
                    width: 84,
                    height: 30,
                  ),
                  pi * 1.1,
                  pi * 0.9,
                  false,
                  windPaint,
                );
              }
            : null,
      );
    case 11: // paku: さかな → ひれが育つ → しおをふくクジラ級キング
      return BodySpec(
        _union([
          _oval(150, 182, 216 + 14 * t, 148 + 10 * t),
          _poly([
            const Offset(244, 182),
            Offset(288 + 10 * t, 138 - 10 * t),
            Offset(288 + 10 * t, 226 + 10 * t),
          ]),
          _poly([
            Offset(150, 92 - 22 * t),
            const Offset(118, 122),
            const Offset(182, 122),
          ]),
        ]),
        arms: false,
        feet: false,
        back: king
            ? (canvas, body) {
                // しおふき
                final water = Paint()
                  ..color = _sky
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 8
                  ..strokeCap = StrokeCap.round;
                canvas.drawArc(
                  Rect.fromCenter(
                    center: const Offset(120, 52),
                    width: 60,
                    height: 60,
                  ),
                  pi * 0.9,
                  pi * 0.6,
                  false,
                  water,
                );
                canvas.drawArc(
                  Rect.fromCenter(
                    center: const Offset(180, 52),
                    width: 60,
                    height: 60,
                  ),
                  pi * 1.5,
                  pi * 0.6,
                  false,
                  water,
                );
                final drop = Paint()..color = _sky;
                canvas.drawCircle(const Offset(96, 34), 7, drop);
                canvas.drawCircle(const Offset(204, 34), 7, drop);
                canvas.drawCircle(const Offset(150, 22), 8, drop);
              }
            : null,
        front: (canvas, body) {
          final fin = Paint()..color = shade(body, -18);
          canvas.drawPath(_rotOval(64, 206, 52 + 18 * t, 22 + 8 * t, 30), fin);
          if (s3) {
            final bubble = Paint()..color = const Color(0x59FFFFFF);
            canvas.drawCircle(const Offset(52, 132), 9, bubble);
            canvas.drawCircle(const Offset(36, 108), 6, bubble);
          }
        },
      );
    case 12: // nemu: ねむねむ → ナイトキャップ → 三日月と星のキング
      return BodySpec(
        _union([
          _oval(150, 196 + 6 * t, 192 + 12 * t, 148),
          _oval(150, 140, 150, 120),
          _rotOval(74, 152, 40, 92, 24),
          _rotOval(226, 152, 40, 92, -24),
        ]),
        back: king
            ? (canvas, body) {
                final moon = Path.combine(
                  PathOperation.difference,
                  _circle(254, 78, 32),
                  _circle(268, 68, 28),
                );
                canvas.drawPath(moon, Paint()..color = _paleGold);
              }
            : null,
        front: (canvas, body) {
          if (s3 && equipHead == null) {
            // ナイトキャップ(先っぽ垂れ+ポンポン)
            final cap = Paint()..color = _navy;
            canvas.drawPath(
              _poly([
                const Offset(94, 92),
                const Offset(150, 58),
                const Offset(206, 92),
                const Offset(216, 76),
                const Offset(234, 96),
              ]),
              cap,
            );
            canvas.drawPath(_rotOval(150, 82, 124, 30, 0), cap);
            canvas.drawCircle(
              const Offset(238, 100),
              11,
              Paint()..color = const Color(0xFFFFFFFF),
            );
          }
          if (king) {
            final starPaint = Paint()..color = _gold;
            canvas.drawPath(_sparkle(56, 92, 12), starPaint);
            canvas.drawPath(_sparkle(84, 56, 8), starPaint);
            canvas.drawPath(_sparkle(226, 210, 9), starPaint);
          }
        },
      );
    case 13: // robo: ろぼ → むねにモニター → 金メッキのキングメカ
      return BodySpec(
        _union([
          _rrect(72 - 8 * t, 88, 156 + 16 * t, 172, 22),
          _rrect(146, 42, 8, 52, 4),
          if (king) _rrect(108, 50, 8, 44, 4),
          if (king) _rrect(184, 50, 8, 44, 4),
          _rrect(86, 246, 128, 22, 10),
        ]),
        feet: false,
        front: (canvas, body) {
          canvas.drawCircle(
            const Offset(150, 38),
            10 + 4 * t,
            Paint()..color = _red,
          );
          if (king) {
            canvas.drawCircle(const Offset(112, 46), 7, Paint()..color = _gold);
            canvas.drawCircle(const Offset(188, 46), 7, Paint()..color = _gold);
          }
          final bolt = Paint()..color = shade(body, -30);
          canvas.drawCircle(const Offset(92, 112), 7, bolt);
          canvas.drawCircle(const Offset(208, 112), 7, bolt);
          if (s3) {
            // むねのモニター
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: const Offset(150, 234),
                  width: 74,
                  height: 30,
                ),
                const Radius.circular(6),
              ),
              Paint()..color = const Color(0xFF23304F),
            );
            final line = Paint()
              ..color = const Color(0xFF6BFF9C)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round;
            canvas.drawPath(
              Path()
                ..moveTo(122, 234)
                ..lineTo(138, 234)
                ..lineTo(146, 226)
                ..lineTo(156, 242)
                ..lineTo(164, 234)
                ..lineTo(178, 234),
              line..style = PaintingStyle.stroke,
            );
          }
          if (king) {
            // 金メッキの角あて
            final gold = Paint()..color = _gold;
            canvas.drawPath(
              _poly([
                const Offset(64, 88),
                const Offset(100, 88),
                const Offset(64, 124),
              ]),
              gold,
            );
            canvas.drawPath(
              _poly([
                const Offset(236, 88),
                const Offset(200, 88),
                const Offset(236, 124),
              ]),
              gold,
            );
          }
        },
      );
    case 14: // obake: おばけ → おててが生える → かぼちゃの相棒つきキング
      final hem = 236 + 12 * t;
      return BodySpec(
        _union([
          _circle(150, 140 - 10 * t, 96),
          if (s3) _rotOval(50, 150, 56, 26, -32),
          if (s3) _rotOval(250, 150, 56, 26, 32),
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
        front: king
            ? (canvas, body) {
                // 足もとのかぼちゃの相棒
                canvas.drawPath(
                  _union([
                    _oval(56, 248, 30, 38),
                    _oval(72, 248, 30, 38),
                    _oval(88, 248, 30, 38),
                  ]),
                  Paint()..color = _orange,
                );
                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromLTWH(68, 218, 8, 14),
                    const Radius.circular(3),
                  ),
                  Paint()..color = _leaf,
                );
                final facePaint = Paint()..color = const Color(0xFF4A2E12);
                canvas.drawPath(
                  _poly([
                    const Offset(62, 242),
                    const Offset(68, 234),
                    const Offset(74, 242),
                  ]),
                  facePaint,
                );
                canvas.drawPath(
                  _poly([
                    const Offset(72, 242),
                    const Offset(78, 234),
                    const Offset(84, 242),
                  ]),
                  facePaint,
                );
                canvas.drawArc(
                  Rect.fromCenter(
                    center: const Offset(73, 252),
                    width: 20,
                    height: 12,
                  ),
                  0,
                  pi,
                  false,
                  facePaint
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3,
                );
              }
            : null,
      );
    case 15: // yuni: ポニー → たてがみ2色+つばさ → 🦄横向きのキングゆにこーん
      if (king) {
        // 🦄 そのものの横向きバスト(こどもFB)。顔・王冠も専用描画
        final bust = _union([
          Path()
            ..moveTo(205, 268)
            ..cubicTo(212, 180, 202, 122, 180, 94)
            ..cubicTo(166, 72, 142, 64, 122, 76)
            ..cubicTo(102, 88, 76, 106, 62, 120)
            ..cubicTo(50, 130, 50, 144, 62, 150)
            ..cubicTo(76, 158, 94, 158, 106, 162)
            ..cubicTo(122, 168, 130, 180, 134, 198)
            ..cubicTo(140, 226, 142, 248, 143, 268)
            ..close(),
          _poly([
            const Offset(148, 82),
            const Offset(162, 34),
            const Offset(182, 80),
          ]),
          _poly([
            const Offset(178, 92),
            const Offset(196, 50),
            const Offset(206, 98),
          ]),
        ]);
        return BodySpec(
          bust,
          arms: false,
          feet: false,
          mantle: false,
          crown: false,
          back: (canvas, body) {
            // 流れるレインボーのたてがみ
            const mane = [_pink, _paleGold, _sky, Color(0xFFC9A7FF)];
            for (var i = 0; i < mane.length; i++) {
              final paint = Paint()..color = mane[i];
              final off = i * 20.0;
              canvas.drawPath(
                _rotOval(
                  216 + off * 0.5,
                  120 + off * 1.6,
                  56,
                  150 - off * 0.4,
                  14 + i * 4,
                ),
                paint,
              );
            }
          },
          front: (canvas, body) {
            // 金の角(しま入り)
            final horn = _poly([
              const Offset(116, 84),
              const Offset(72, 8),
              const Offset(142, 66),
            ]);
            canvas.drawPath(horn, Paint()..color = _paleGold);
            final stripe = Paint()
              ..color = _goldShade
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              const Offset(104, 62),
              const Offset(126, 54),
              stripe,
            );
            canvas.drawLine(
              const Offset(92, 42),
              const Offset(112, 34),
              stripe,
            );
            // まえがみ
            canvas.drawPath(
              _rotOval(146, 74, 56, 26, -24),
              Paint()..color = _pink,
            );
            // 王冠(頭のうしろにちょこん)
            final crownPath = _poly([
              const Offset(196, 66),
              const Offset(202, 42),
              const Offset(212, 58),
              const Offset(224, 40),
              const Offset(230, 64),
            ]);
            canvas.drawPath(crownPath, Paint()..color = _gold);
            // 耳のうち側
            canvas.drawPath(
              _poly([
                const Offset(156, 76),
                const Offset(163, 46),
                const Offset(174, 74),
              ]),
              Paint()..color = const Color(0x73FFFFFF),
            );
          },
          ownFace: (canvas, body, sad) {
            // よこ顔: まつげつきの目・鼻・ほっぺ・口
            canvas.drawCircle(
              const Offset(118, 118),
              10,
              Paint()..color = const Color(0xFF3A3F52),
            );
            canvas.drawCircle(
              const Offset(121, 114),
              3.5,
              Paint()..color = const Color(0xFFFFFFFF),
            );
            final lash = Paint()
              ..color = const Color(0xFF3A3F52)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              const Offset(107, 108),
              const Offset(99, 102),
              lash,
            );
            canvas.drawLine(
              const Offset(105, 116),
              const Offset(96, 113),
              lash,
            );
            canvas.drawCircle(
              const Offset(112, 140),
              9,
              Paint()..color = const Color(0xB3FF9CC2),
            );
            canvas.drawCircle(
              const Offset(72, 132),
              3.5,
              Paint()..color = const Color(0xFF3A3F52),
            );
            final mouth = Paint()
              ..color = const Color(0xFF3A3F52)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..strokeCap = StrokeCap.round;
            if (sad) {
              canvas.drawArc(
                Rect.fromCenter(
                  center: const Offset(80, 150),
                  width: 18,
                  height: 10,
                ),
                pi,
                pi,
                false,
                mouth,
              );
              canvas.drawCircle(
                const Offset(104, 132),
                5,
                Paint()..color = _sky,
              );
            } else {
              canvas.drawArc(
                Rect.fromCenter(
                  center: const Offset(80, 144),
                  width: 18,
                  height: 12,
                ),
                0,
                pi,
                false,
                mouth,
              );
            }
          },
        );
      }
      final legTop = 218.0 - 8 * t;
      return BodySpec(
        _union([
          _circle(150, 132, 76),
          _oval(150, 194, 168, 96),
          _poly([
            const Offset(106, 74),
            Offset(96, 26 - 8 * t),
            const Offset(136, 58),
          ]),
          _poly([
            const Offset(194, 74),
            Offset(204, 26 - 8 * t),
            const Offset(164, 58),
          ]),
          for (final x in const [106.0, 134.0, 166.0, 194.0])
            _rrect(x - 10, legTop, 20, 268 - legTop, 9),
        ]),
        feet: false,
        back: (canvas, body) {
          final maneColors = s3 ? const [_pink, _sky] : const [_pink];
          for (var layer = 0; layer < maneColors.length; layer++) {
            final paint = Paint()..color = maneColors[layer];
            final off = layer * 16.0;
            canvas.drawPath(
              _rotOval(66 - off * 0.3, 110 + off, 58, 130, 20),
              paint,
            );
            canvas.drawPath(
              _rotOval(80 - off * 0.3, 176 + off * 0.8, 46, 96, 10),
              paint,
            );
          }
          canvas.drawPath(
            _rotOval(240, 206, 88, 28, 42),
            Paint()..color = _pink,
          );
          if (s3) {
            canvas.drawPath(
              _rotOval(236, 222, 76, 22, 56),
              Paint()..color = _sky,
            );
          }
        },
        front: equipHead != null
            ? null
            : (canvas, body) {
                final horn = _poly([
                  const Offset(138, 70),
                  Offset(150, 12 - 8 * t),
                  const Offset(162, 70),
                ]);
                canvas.drawPath(horn, Paint()..color = _paleGold);
                final stripe = Paint()
                  ..color = _goldShade
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

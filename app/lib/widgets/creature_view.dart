import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import 'creature_faces.dart';
import 'creature_painter.dart';
import 'egg_painter.dart';

/// タップ時の一回きりアニメーション(CSS bounce/munch/wiggle 相当)。
/// spin はお絵かきを褒められたとき等の「うれしい!」回転。
enum CreatureAnim { bounce, munch, wiggle, spin }

/// ホーム画面のいきもの表示。浮遊・グロー・キングのオーラ・
/// タップアニメーションをまとめる。親は GlobalKey 経由で [play] を呼ぶ。
class CreatureView extends StatefulWidget {
  final GameState state;
  final ui.Image? pattern;
  const CreatureView({super.key, required this.state, this.pattern});

  @override
  State<CreatureView> createState() => CreatureViewState();
}

class CreatureViewState extends State<CreatureView>
    with TickerProviderStateMixin {
  late final AnimationController _floaty = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final AnimationController _tap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  CreatureAnim? _current;

  CreatureMood? _mood;
  Timer? _moodTimer;

  /// 一時的に誇張表情へ切り替える(自動で元に戻る)。
  void flashMood(
    CreatureMood mood, {
    Duration duration = const Duration(milliseconds: 950),
  }) {
    _moodTimer?.cancel();
    setState(() => _mood = mood);
    _moodTimer = Timer(duration, () {
      if (mounted) setState(() => _mood = null);
    });
  }

  void play(CreatureAnim anim) {
    _current = anim;
    _tap.duration = Duration(
      milliseconds: switch (anim) {
        CreatureAnim.munch => 800,
        CreatureAnim.spin => 700,
        _ => 500,
      },
    );
    _tap.forward(from: 0);
  }

  @override
  void dispose() {
    _moodTimer?.cancel();
    _floaty.dispose();
    _glow.dispose();
    _tap.dispose();
    super.dispose();
  }

  /// 進化予兆 or 金のたまごで金色グロー(数値は出さない)。
  bool get _glowing =>
      widget.state.nearEvolve ||
      (widget.state.species == 3 && widget.state.stage == 0);

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final painter = s.stage == 0
        ? EggPainter(cracks: min(s.eggTaps, 2), golden: s.species == 3)
        : CreaturePainter(
            speciesIndex: s.species,
            stage: s.stage,
            sad: s.isSad,
            mood: _mood,
            bodyColor: Color(s.color),
            equipHead: s.equipHead,
            equipFace: s.equipFace,
            pattern: widget.pattern,
          ) as CustomPainter;

    return AnimatedBuilder(
      animation: Listenable.merge([_floaty, _glow, _tap]),
      builder: (context, _) {
        final floatY = -8 * Curves.easeInOut.transform(_floaty.value);
        Widget core = CustomPaint(size: Size.infinite, painter: painter);

        if (_glowing) {
          core = DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFFD23E,
                  ).withValues(alpha: 0.45 + 0.5 * _glow.value),
                  blurRadius: 6 + 18 * _glow.value,
                  spreadRadius: 2 + 6 * _glow.value,
                ),
              ],
            ),
            child: core,
          );
        }

        core = Transform.translate(
          offset: Offset(0, floatY),
          child: Transform(
            alignment: Alignment.center,
            transform: _tapTransform(),
            child: core,
          ),
        );

        if (s.stage == 3) {
          core = Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: -40,
                right: -40,
                top: -40,
                bottom: -40,
                child: RotationTransition(
                  turns: _floaty, // ゆっくり回っていれば十分(8s厳密でなくてよい)
                  child: const CustomPaint(painter: _AuraPainter()),
                ),
              ),
              Positioned.fill(child: core),
            ],
          );
        }
        return AspectRatio(aspectRatio: 1, child: core);
      },
    );
  }

  /// CSS keyframes bounce/munch/wiggle の区分線形移植。
  Matrix4 _tapTransform() {
    final t = _tap.value;
    if (_current == null || _tap.status == AnimationStatus.dismissed) {
      return Matrix4.identity();
    }
    switch (_current!) {
      case CreatureAnim.bounce:
        // 0%(1,1) 30%(1.08,.9) 60%(.95,1.06) 100%(1,1)
        final (sx, sy) = _key3(t, 0.30, 0.60, (1.08, 0.9), (0.95, 1.06));
        return Matrix4.diagonal3Values(sx, sy, 1);
      case CreatureAnim.munch:
        // 0%(1,1) 25%(1.06,.94) 50%(.96,1.05) 75%(1.05,.95) 100%(1,1)
        if (t < 0.25) {
          final k = t / 0.25;
          return Matrix4.diagonal3Values(
            _lerp(1, 1.06, k),
            _lerp(1, 0.94, k),
            1,
          );
        } else if (t < 0.5) {
          final k = (t - 0.25) / 0.25;
          return Matrix4.diagonal3Values(
            _lerp(1.06, 0.96, k),
            _lerp(0.94, 1.05, k),
            1,
          );
        } else if (t < 0.75) {
          final k = (t - 0.5) / 0.25;
          return Matrix4.diagonal3Values(
            _lerp(0.96, 1.05, k),
            _lerp(1.05, 0.95, k),
            1,
          );
        }
        final k = (t - 0.75) / 0.25;
        return Matrix4.diagonal3Values(_lerp(1.05, 1, k), _lerp(0.95, 1, k), 1);
      case CreatureAnim.wiggle:
        // 0%(0deg) 25%(-7deg) 75%(7deg) 100%(0deg)
        final deg = t < 0.25
            ? _lerp(0, -7, t / 0.25)
            : t < 0.75
                ? _lerp(-7, 7, (t - 0.25) / 0.5)
                : _lerp(7, 0, (t - 0.75) / 0.25);
        return Matrix4.rotationZ(deg * pi / 180);
      case CreatureAnim.spin:
        // うれしい! の1回転(減速)+軽い伸び
        final e = Curves.easeOut.transform(t);
        final pop = 1 + 0.12 * sin(pi * t);
        return Matrix4.rotationZ(2 * pi * e)
          ..multiply(Matrix4.diagonal3Values(pop, pop, 1));
    }
  }

  (double, double) _key3(
    double t,
    double p1,
    double p2,
    (double, double) k1,
    (double, double) k2,
  ) {
    if (t < p1) {
      final k = t / p1;
      return (_lerp(1, k1.$1, k), _lerp(1, k1.$2, k));
    } else if (t < p2) {
      final k = (t - p1) / (p2 - p1);
      return (_lerp(k1.$1, k2.$1, k), _lerp(k1.$2, k2.$2, k));
    }
    final k = (t - p2) / (1 - p2);
    return (_lerp(k2.$1, 1, k), _lerp(k2.$2, 1, k));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// キングの金色オーラ: 回転する放射ウェッジ+中心からの円形フェード。
/// CSS repeating-conic-gradient + mask radial-gradient の移植。
class _AuraPainter extends CustomPainter {
  const _AuraPainter();
  static const color = Color(0x66FFD23E);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color, color.withValues(alpha: 0)],
        stops: const [0, 0.35, 0.7],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    const wedgeRad = 12 * pi / 180;
    for (var i = 0; i < 15; i++) {
      final start = i * 24 * pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius),
            start,
            wedgeRad,
            false,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => false;
}

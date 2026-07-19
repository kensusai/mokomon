import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import 'celebrate_overlay.dart';
import 'confetti.dart';
import 'creature_painter.dart';

/// 進化カットシーン(docs/game-design.md §3)。
/// 暗転 → 白シルエット振動2.4s → 白フラッシュ → 新形態リビール+紙吹雪。
/// リビール時点で [GameController.applyEvolution] を呼び状態を確定する。
Future<void> showEvolution(
    BuildContext context, GameController controller, int newStage) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) =>
          _EvolutionScreen(controller: controller, newStage: newStage),
    ),
  );
}

class _EvolutionScreen extends StatefulWidget {
  final GameController controller;
  final int newStage;
  const _EvolutionScreen({required this.controller, required this.newStage});

  @override
  State<_EvolutionScreen> createState() => _EvolutionScreenState();
}

class _EvolutionScreenState extends State<_EvolutionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _rays =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))
        ..repeat();

  final _timers = <Timer>[];
  var _revealed = false;

  @override
  void initState() {
    super.initState();
    _shake.forward();
    // カットシーン中はBGMを止めて演出音を主役にする
    widget.controller.sfx.syncBgm(suspend: true);
    widget.controller.sfx.play(Sfx.evoRiser);
    _timers.add(Timer(const Duration(milliseconds: 2150), () {
      if (!mounted) return;
      _flash.forward(from: 0);
      widget.controller.sfx.play(Sfx.shine);
    }));
    _timers.add(Timer(const Duration(milliseconds: 2550), _reveal));
  }

  void _reveal() {
    if (!mounted) return;
    widget.controller.applyEvolution(widget.newStage);
    // 「〜にしんかした!!」の瞬間は勝利曲で派手に(こどもFB)
    widget.controller.sfx.playOverrideBgm(Sfx.victoryTune, loop: false);
    setState(() => _revealed = true);
    _pop.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.sfx.clearOverrideBgm(); // ホームBGMへ
    for (final t in _timers) {
      t.cancel();
    }
    _shake.dispose();
    _flash.dispose();
    _pop.dispose();
    _rays.dispose();
    super.dispose();
  }

  String get _text {
    final sp = widget.controller.state.currentSpecies;
    return widget.newStage == 3
        ? '${sp.names[3]} たんじょう!!'
        : '${sp.names[2]} に しんかした!!';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.controller.state;
    final size = MediaQuery.sizeOf(context);
    final creatureSize = min(size.width * 0.6, 270.0);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF3D4666), Color(0xFF20253D)],
          ),
        ),
        child: Stack(
          children: [
            // 回転する光条
            Positioned.fill(
              child: Opacity(
                opacity: _revealed ? 1 : 0.35,
                child: RotationTransition(
                  turns: _rays,
                  child: const CustomPaint(
                    painter: _RaysPainter(),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            if (_revealed)
              const Positioned.fill(child: ConfettiBurst(count: 34)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: creatureSize,
                    height: creatureSize,
                    child: _revealed ? _revealCreature(s) : _silhouette(s),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 36,
                    child: _revealed
                        ? Text(_text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800))
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Visibility(
                    visible: _revealed,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: StartButton(
                      label: 'すごい!!',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
            // 白フラッシュ(0%→25%で不透明→100%で透明)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flash,
                  builder: (context, _) {
                    final t = _flash.value;
                    final o = _flash.isAnimating || t > 0
                        ? (t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75)
                        : 0.0;
                    return Container(
                        color: Colors.white.withValues(alpha: o.clamp(0, 1)));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 進化前の姿を真っ白なシルエットで震わせる(CSS evoShake 相当)。
  Widget _silhouette(dynamic s) {
    final old = CreaturePainter(
      speciesIndex: s.species,
      stage: widget.newStage - 1,
      sad: false,
      bodyColor: Color(s.color),
      equipHead: s.equipHead,
      equipFace: s.equipFace,
    );
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final (scale, deg) = _shakeKeyframes(t);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1, 1)
            ..rotateZ(deg * pi / 180),
          child: child,
        );
      },
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: CustomPaint(painter: old, size: Size.infinite),
      ),
    );
  }

  Widget _revealCreature(dynamic s) {
    return ScaleTransition(
      scale: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
      ]).animate(_pop),
      child: CustomPaint(
        painter: CreaturePainter(
          speciesIndex: s.species,
          stage: s.stage,
          sad: false,
          bodyColor: Color(s.color),
          equipHead: s.equipHead,
          equipFace: s.equipFace,
        ),
        size: Size.infinite,
      ),
    );
  }

  /// CSS evoShake: 振幅漸増で震えながら拡大。
  (double, double) _shakeKeyframes(double t) {
    const keys = [
      (0.00, 0.85, 0.0),
      (0.20, 0.88, -3.0),
      (0.40, 0.92, 3.0),
      (0.55, 0.98, -5.0),
      (0.70, 1.05, 5.0),
      (0.82, 1.12, -7.0),
      (0.92, 1.20, 7.0),
      (1.00, 1.28, 0.0),
    ];
    for (var i = 1; i < keys.length; i++) {
      if (t <= keys[i].$1) {
        final (t0, s0, r0) = keys[i - 1];
        final (t1, s1, r1) = keys[i];
        final k = (t - t0) / (t1 - t0);
        return (s0 + (s1 - s0) * k, r0 + (r1 - r0) * k);
      }
    }
    return (1.28, 0);
  }
}

/// 白い光条(CSS repeating-conic-gradient 10deg/20deg 相当)。
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.longestSide * 1.2;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.13);
    const wedge = 10 * pi / 180;
    for (var i = 0; i < 18; i++) {
      final start = i * 20 * pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(Rect.fromCircle(center: center, radius: radius), start, wedge,
              false)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}

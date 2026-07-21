import 'dart:async';

import 'package:flutter/material.dart';

/// 絵文字パーティクルの重ね描き層。プロトタイプの particle() に対応。
/// 親は `GlobalKey<ParticleFieldState>` 経由で [ParticleFieldState.spawn] を呼ぶ。
class ParticleField extends StatefulWidget {
  const ParticleField({super.key});

  @override
  State<ParticleField> createState() => ParticleFieldState();
}

class ParticleFieldState extends State<ParticleField> {
  final _items = <_Particle>[];
  var _seq = 0;

  /// [position] はこのウィジェットのローカル座標。
  void spawn(String emoji, Offset position) {
    setState(() => _items.add(_Particle(_seq++, emoji, position)));
  }

  /// 💨用: 横に流れて消えるパーティクル(CSS puffout 相当)。
  void spawnPuff(
    String emoji,
    Offset position, {
    required double driftX,
    Duration delay = Duration.zero,
  }) {
    setState(
      () => _items.add(
        _Particle(_seq++, emoji, position, driftX: driftX, delay: delay),
      ),
    );
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _items.removeWhere((p) => p.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final p in _items)
            if (p.driftX == null)
              _RisingEmoji(
                key: ValueKey(p.id),
                emoji: p.emoji,
                position: p.position,
                onDone: () => _remove(p.id),
              )
            else
              _DriftingEmoji(
                key: ValueKey(p.id),
                emoji: p.emoji,
                position: p.position,
                driftX: p.driftX!,
                delay: p.delay,
                onDone: () => _remove(p.id),
              ),
        ],
      ),
    );
  }
}

class _Particle {
  final int id;
  final String emoji;
  final Offset position;
  final double? driftX;
  final Duration delay;
  _Particle(
    this.id,
    this.emoji,
    this.position, {
    this.driftX,
    this.delay = Duration.zero,
  });
}

/// 1秒で 70px 上昇しつつフェードアウト+拡大(CSS rise 相当)。
class _RisingEmoji extends StatefulWidget {
  final String emoji;
  final Offset position;
  final VoidCallback onDone;

  const _RisingEmoji({
    super.key,
    required this.emoji,
    required this.position,
    required this.onDone,
  });

  @override
  State<_RisingEmoji> createState() => _RisingEmojiState();
}

class _RisingEmojiState extends State<_RisingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return Positioned(
          left: widget.position.dx - 12,
          top: widget.position.dy - 12 - 70 * t,
          child: Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 0.6 + 0.7 * t,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
        );
      },
    );
  }
}

/// 💨: 遅延後、横に流れながら拡大して消える(1.2秒)。
class _DriftingEmoji extends StatefulWidget {
  final String emoji;
  final Offset position;
  final double driftX;
  final Duration delay;
  final VoidCallback onDone;

  const _DriftingEmoji({
    super.key,
    required this.emoji,
    required this.position,
    required this.driftX,
    required this.delay,
    required this.onDone,
  });

  @override
  State<_DriftingEmoji> createState() => _DriftingEmojiState();
}

class _DriftingEmojiState extends State<_DriftingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  // CSS puffout: 0%透明 → 18%で最大不透明 → 100%で透明
  double _opacity(double t) {
    if (t == 0) return 0;
    if (t < 0.18) return 0.95 * t / 0.18;
    return 0.95 * (1 - (t - 0.18) / 0.82);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return Positioned(
          left: widget.position.dx - 15 + widget.driftX * t,
          top: widget.position.dy - 15 - 46 * t,
          child: Opacity(
            opacity: _opacity(_c.value).clamp(0, 1),
            child: Transform.scale(
              scale: 0.4 + 1.3 * t,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
    );
  }
}

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
            _RisingEmoji(
              key: ValueKey(p.id),
              emoji: p.emoji,
              position: p.position,
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
  _Particle(this.id, this.emoji, this.position);
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )
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

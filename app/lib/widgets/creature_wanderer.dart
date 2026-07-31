import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/creature_motion.dart';

/// ホームのステージ内でいきものを回遊させるラッパー(docs/game-design.md §3)。
/// 位置は [CreatureMotion](時間の純関数)で決まり、種族ごとに軌道が違う。
/// [enabled] が false(たまご)のときは従来のホームポジション
/// (Alignment(0, 0.85))に固定する。
class CreatureWanderer extends StatefulWidget {
  final int species;
  final bool enabled;
  final Widget child;

  const CreatureWanderer({
    super.key,
    required this.species,
    required this.enabled,
    required this.child,
  });

  @override
  State<CreatureWanderer> createState() => _CreatureWandererState();
}

class _CreatureWandererState extends State<CreatureWanderer>
    with SingleTickerProviderStateMixin {
  static const _homeAlignment = Alignment(0, 0.85);

  late CreatureMotion _motion = CreatureMotion(widget.species);
  late final Ticker _ticker;
  var _t = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(CreatureWanderer old) {
    super.didUpdateWidget(old);
    if (old.species != widget.species) {
      _motion = CreatureMotion(widget.species);
    }
    if (old.enabled != widget.enabled) {
      widget.enabled ? _ticker.start() : _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) =>
      setState(() => _t = elapsed.inMicroseconds / 1e6);

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Align(alignment: _homeAlignment, child: widget.child);
    }
    final p = _motion.at(_t);
    return Align(
      alignment: Alignment(p.dx, p.dy),
      child: Transform.rotate(angle: _motion.tiltAt(_t), child: widget.child),
    );
  }
}

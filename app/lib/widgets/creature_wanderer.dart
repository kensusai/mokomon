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
  static const _homeOffset = Offset(0, 0.85);

  /// 軌道へ乗るまでのブレンド秒数(docs/review-findings.md #68:
  /// 孵化・交代の瞬間移動を防ぎ、直前の位置からなめらかに合流する)。
  static const _blendSecs = 2.0;

  late CreatureMotion _motion = CreatureMotion(widget.species);
  late final Ticker _ticker;
  var _t = 0.0;

  /// ブレンドの出発点と開始時刻。孵化はホームポジションから、
  /// 種族交代は直前に表示していた位置から合流する。
  var _blendFrom = _homeOffset;
  var _blendStart = 0.0;
  var _lastPos = _homeOffset;

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
      _blendFrom = _lastPos;
      _blendStart = _t;
    }
    if (old.enabled != widget.enabled) {
      if (widget.enabled) {
        // Ticker再開でelapsedは0からやり直すため、時計も揃える
        _t = 0.0;
        _blendFrom = _homeOffset;
        _blendStart = 0.0;
        _ticker.start();
      } else {
        _ticker.stop();
      }
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
      _lastPos = _homeOffset;
      return Align(alignment: _homeAlignment, child: widget.child);
    }
    final u = Curves.easeInOut.transform(
      ((_t - _blendStart) / _blendSecs).clamp(0.0, 1.0),
    );
    final p = Offset.lerp(_blendFrom, _motion.at(_t), u)!;
    _lastPos = p;
    return Align(
      alignment: Alignment(p.dx, p.dy),
      child: Transform.rotate(
        angle: _motion.tiltAt(_t) * u,
        child: widget.child,
      ),
    );
  }
}

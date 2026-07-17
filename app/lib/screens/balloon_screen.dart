import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/particles.dart';
import '../widgets/ui_kit.dart';

enum _Phase { intro, countdown, running, ended }

/// ふうせんわり(docs/game-design.md §5)。上がってくる風船をタップ、💣は-2。
class BalloonScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final BalloonGame Function()? gameFactory;

  const BalloonScreen({super.key, required this.controller, this.gameFactory});

  @override
  State<BalloonScreen> createState() => _BalloonScreenState();
}

class _BalloonScreenState extends State<BalloonScreen>
    with SingleTickerProviderStateMixin {
  var _phase = _Phase.intro;
  var _game = BalloonGame();
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  final _areaKey = GlobalKey();
  final _particleKey = GlobalKey<ParticleFieldState>();

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _start() {
    _game = widget.gameFactory?.call() ?? BalloonGame();
    _lastTick = Duration.zero;
    setState(() => _phase = _Phase.running);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : min(0.05, (elapsed - _lastTick).inMicroseconds / 1e6);
    _lastTick = elapsed;
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _game.update(dt, box.size.width, box.size.height);
    if (_game.finished) {
      _ticker?.stop();
      widget.controller.finishMinigame(_game.score);
      setState(() => _phase = _Phase.ended);
      return;
    }
    setState(() {});
  }

  void _onTapDown(TapDownDetails d) {
    if (_phase != _Phase.running) return;
    final hit = _game.tapAt(d.localPosition.dx, d.localPosition.dy);
    if (hit == null) return;
    if (hit.bomb) {
      widget.controller.sfx.play(Sfx.wrong);
      _particleKey.currentState?.spawn('💥', d.localPosition);
    } else {
      widget.controller.sfx.play(Sfx.pop);
      _particleKey.currentState
          ?.spawn(hit.golden ? '✨' : '🎉', d.localPosition);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE3FF), Color(0xFFFFE9F2)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: _areaKey,
                behavior: HitTestBehavior.opaque,
                onTapDown: _onTapDown,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final it in _game.items)
                      Positioned(
                        left: it.renderX - 24,
                        top: it.y - 24,
                        child: Text(it.emoji,
                            style: TextStyle(fontSize: it.bomb ? 40 : 46)),
                      ),
                  ],
                ),
              ),
            ),
            Positioned.fill(child: ParticleField(key: _particleKey)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatPill('⏰ ${_game.timeLeft}'),
                    StatPill('🎈 ${_game.score}'),
                  ],
                ),
              ),
            ),
            if (_phase == _Phase.countdown)
              GameCountdown(
                  onDone: _start,
                  onTick: () => widget.controller.sfx.play(Sfx.tap)),
            if (_phase == _Phase.intro)
              GameStartOverlay(
                title: '🎈 ふうせんわり',
                desc: 'ふわふわ あがる ふうせんを われ!\n⭐は 3コイン、💣は さわっちゃダメ!',
                onStart: () => setState(() => _phase = _Phase.countdown),
                onBack: () => Navigator.of(context).pop(),
              ),
            if (_phase == _Phase.ended)
              GameEndOverlay(
                emoji: '🎉',
                result: '+${_game.score} コイン げっと!',
                onDone: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

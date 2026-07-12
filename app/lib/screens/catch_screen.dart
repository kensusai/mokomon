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

/// フルーツキャッチ(docs/game-design.md §5)。30秒、タップ判定半径44px。
class CatchScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final CatchGame Function()? gameFactory;

  const CatchScreen({super.key, required this.controller, this.gameFactory});

  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen>
    with SingleTickerProviderStateMixin {
  var _phase = _Phase.intro;
  var _game = CatchGame();
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
    _game = widget.gameFactory?.call() ?? CatchGame();
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
    if (hit != null) {
      widget.controller.sfx.play(Sfx.pop);
      _particleKey.currentState?.spawn(hit.star ? '✨' : '💥', d.localPosition);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9EDCFF), Color(0xFFE7F8FF)],
          ),
        ),
        child: Stack(
          // オーバーレイの有無で全体が収縮しないよう常に全画面に広げる
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
                        left: it.renderX - 23,
                        top: it.y - 23,
                        child: Text(it.emoji,
                            style: TextStyle(fontSize: it.star ? 46 : 42)),
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
                    StatPill('🍎 ${_game.score}'),
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
                title: '🍎 フルーツキャッチ',
                desc: 'おちてくる フルーツを\nタッチして あつめよう!\n⭐は 3コインだよ!',
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

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/particles.dart';
import '../widgets/ui_kit.dart';
import 'timed_arcade_game.dart';

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
    with SingleTickerProviderStateMixin, TimedArcadeGameMixin<BalloonScreen> {
  var _game = BalloonGame();
  final _areaKey = GlobalKey();
  final _particleKey = GlobalKey<ParticleFieldState>();

  @override
  TickerProvider get vsync => this;
  @override
  GameController get controller => widget.controller;
  @override
  bool get gameFinished => _game.finished;
  @override
  int get gameScore => _game.score;

  @override
  void startGameInstance() =>
      _game = widget.gameFactory?.call() ?? BalloonGame();

  @override
  void tickGame(double dt) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _game.update(dt, box.size.width, box.size.height);
  }

  void _onTapDown(TapDownDetails d) {
    if (phase != ArcadePhase.running) return;
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
            if (phase == ArcadePhase.countdown)
              GameCountdown(
                  onDone: startGame,
                  onTick: () => widget.controller.sfx.play(Sfx.tap)),
            if (phase == ArcadePhase.intro)
              GameStartOverlay(
                title: '🎈 ふうせんわり',
                desc: 'ふわふわ あがる ふうせんを われ!\n⭐は 3コイン、💣は さわっちゃダメ!',
                onStart: () => setState(() => phase = ArcadePhase.countdown),
                onBack: () => Navigator.of(context).pop(),
              ),
            if (phase == ArcadePhase.ended)
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

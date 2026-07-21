import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/particles.dart';
import 'timed_arcade_game.dart';

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
    with SingleTickerProviderStateMixin, TimedArcadeGameMixin<CatchScreen> {
  var _game = CatchGame();
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
  int get gameTimeLeft => _game.timeLeft;

  @override
  void startGameInstance() => _game = widget.gameFactory?.call() ?? CatchGame();

  @override
  void tickGame(double dt) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _game.update(dt, box.size.width, box.size.height);
  }

  void _onTapDown(TapDownDetails d) {
    if (phase != ArcadePhase.running) return;
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
                        child: Text(
                          it.emoji,
                          style: TextStyle(fontSize: it.star ? 46 : 42),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned.fill(child: ParticleField(key: _particleKey)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: buildScoreHeader('🍎'),
              ),
            ),
            ...buildArcadeOverlays(
              title: '🍎 フルーツキャッチ',
              desc: 'おちてくる フルーツを\nタッチして あつめよう!\n⭐は 3コインだよ!',
            ),
          ],
        ),
      ),
    );
  }
}

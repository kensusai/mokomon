import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../data/species.dart';
import '../logic/minigames.dart';
import '../widgets/creature_painter.dart';
import '../widgets/particles.dart';
import 'timed_arcade_game.dart';

/// もぐらたたき(docs/game-design.md §5)。穴から出るいきものをタップ!
class WhackScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final WhackGame Function()? gameFactory;

  const WhackScreen({super.key, required this.controller, this.gameFactory});

  @override
  State<WhackScreen> createState() => _WhackScreenState();
}

class _WhackScreenState extends State<WhackScreen>
    with SingleTickerProviderStateMixin, TimedArcadeGameMixin<WhackScreen> {
  var _game = WhackGame();
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
  void startGameInstance() => _game = widget.gameFactory?.call() ?? WhackGame();

  @override
  void tickGame(double dt) => _game.update(dt);

  void _onHoleTap(int hole, Offset globalPos) {
    if (phase != ArcadePhase.running) return;
    final mole = _game.tapHole(hole);
    if (mole == null) return;
    final field = _particleKey.currentContext?.findRenderObject() as RenderBox?;
    final local = field?.globalToLocal(globalPos) ?? Offset.zero;
    if (mole.stinky) {
      widget.controller.sfx.play(Sfx.puff);
      _particleKey.currentState?.spawn('💨', local);
    } else {
      widget.controller.sfx.play(Sfx.pop);
      _particleKey.currentState?.spawn(mole.golden ? '🌟' : '💥', local);
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
            colors: [Color(0xFFD9F2C9), Color(0xFFF7EBC9)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    buildScoreHeader('🔨'),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              for (var i = 0; i < whackHoles; i++) _hole(i),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(child: ParticleField(key: _particleKey)),
            ...buildArcadeOverlays(
              title: '🔨 もぐらたたき',
              desc: 'あなから でてくる いきものを\nタッチしよう!\nきんいろは 3コイン!',
            ),
          ],
        ),
      ),
    );
  }

  Widget _hole(int index) {
    final mole = _game.moles.where((m) => m.hole == index).firstOrNull;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _onHoleTap(index, d.globalPosition),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // いきもの(穴の上にひょっこり)
          if (mole != null)
            Positioned(
              bottom: 10,
              child: SizedBox(
                width: 78,
                height: 78,
                child: CustomPaint(
                  painter: CreaturePainter(
                    speciesIndex:
                        mole.golden ? secretSpeciesIndex : mole.speciesIndex,
                    stage: 1,
                    sad: false,
                  ),
                ),
              ),
            ),
          // 穴
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4A2B),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

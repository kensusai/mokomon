import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'timer_bag.dart';

/// ラウンド内の状態。armed=次のティックで走り出す / running=マーカー往復中 /
/// result=結果表示中(少し待って次ラウンドへ)/ ended=全ラウンド終了。
enum _StopPhase { armed, running, result, ended }

/// ぴったりストップ(docs/game-design.md §5)。走るマーカーをまとの上で止める。
/// マーカー位置は [StopGame.positionAt](経過時間の純関数)で決まるため、
/// Ticker では dt 積分をせず経過時間をそのまま渡す(テストの仮想時間と一致する)。
class StopScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final StopGame? game;

  const StopScreen({super.key, required this.controller, this.game});

  @override
  State<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends State<StopScreen>
    with SingleTickerProviderStateMixin, TimerBagMixin<StopScreen> {
  late final _game = widget.game ?? StopGame();
  late final Ticker _ticker;
  var _phase = _StopPhase.armed;
  Duration _base = Duration.zero;
  var _pos = 0.0;
  String _message = 'まとの うえで ストップ!';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    switch (_phase) {
      case _StopPhase.armed:
        _base = elapsed;
        setState(() {
          _phase = _StopPhase.running;
          _pos = 0;
        });
      case _StopPhase.running:
        setState(
          () => _pos = _game.positionAt((elapsed - _base).inMicroseconds / 1e6),
        );
      case _StopPhase.result:
      case _StopPhase.ended:
        break;
    }
  }

  void _onStop() {
    if (_phase != _StopPhase.running) return;
    final c = _game.stopAt(_pos);
    widget.controller.sfx.play(
      c == 4 ? Sfx.happy : (c == 2 ? Sfx.tap : Sfx.wrong),
    );
    setState(() {
      _phase = _StopPhase.result;
      _message = switch (c) {
        4 => 'ぴったり! +4コイン!',
        2 => 'まとの なか! +2コイン!',
        _ => 'ざんねん! はずれ…',
      };
    });
    later(const Duration(milliseconds: 800), () {
      if (_game.finished) {
        _ticker.stop();
        widget.controller.finishMinigame(_game.reward);
        setState(() => _phase = _StopPhase.ended);
      } else {
        setState(() {
          _phase = _StopPhase.armed;
          _message = 'まとの うえで ストップ!';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '🎯 ぴったりストップ',
      topColor: const Color(0xFFFFEDE6),
      bottomColor: const Color(0xFFE8F1FF),
      overlays: [
        if (_phase == _StopPhase.ended)
          GameEndOverlay(
            emoji: _game.reward > 0 ? '🎯' : '🐢',
            result: _game.reward > 0
                ? '+${_game.reward} コイン げっと!'
                : 'ざんねん! また ちょうせんしてね',
            buttonLabel: _game.reward > 0 ? 'やったー!' : 'つぎは がんばる!',
            onDone: () => Navigator.of(context).pop(),
          ),
      ],
      children: [
        const SizedBox(height: 6),
        Text(
          _message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(child: Center(child: _bar())),
        _stopButton(),
        const SizedBox(height: 8),
        RoundProgressDots(total: stopRounds, current: _game.round),
      ],
    );
  }

  /// まと(色帯)とマーカー(丸)を載せた横バー。座標は 0〜1 を幅に写像する。
  Widget _bar() => SizedBox(
    height: 64,
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 21,
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFDFE3EF),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
            Positioned(
              left: (_game.zoneCenter - _game.zoneHalf) * w,
              width: _game.zoneHalf * 2 * w,
              top: 21,
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB65C), Color(0xFFE8632A)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
            Positioned(
              left: (_pos * w - 16).clamp(0.0, w - 32),
              top: 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF54B9FF),
                  boxShadow: [
                    BoxShadow(color: Color(0x5554B9FF), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _stopButton() => Material(
    key: const ValueKey('stop-tap'),
    color: const Color(0xFFE8637A),
    borderRadius: BorderRadius.circular(26),
    elevation: 4,
    shadowColor: const Color(0x55E8637A),
    child: InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: _onStop,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'ストップ!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

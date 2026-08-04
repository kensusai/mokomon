import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'timer_bag.dart';

enum _Phase { ready, playing, ended }

const _padColors = [
  Color(0xFFFF6EA6), // ピンク
  Color(0xFF54B9FF), // あお
  Color(0xFF34C98E), // みどり
  Color(0xFFFFC24B), // きいろ
];

/// リズムタッチ(docs/game-design.md §5)。ビートに合わせて光るパッドをタッチ。
/// ビート進行の Timer は画面が持ち、採点は [RhythmGame] が持つ。
/// あたり1回=1コイン(反射系: ミス制の対象外)。
class RhythmScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final RhythmGame? game;

  const RhythmScreen({super.key, required this.controller, this.game});

  @override
  State<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends State<RhythmScreen>
    with TimerBagMixin<RhythmScreen> {
  late final _game = widget.game ?? RhythmGame();
  final _watch = Stopwatch();
  var _phase = _Phase.ready;
  var _perfect = false; // 直前のあたりが「ぴったり」だったか(★演出)

  @override
  void initState() {
    super.initState();
    later(const Duration(milliseconds: 800), _startBeat);
  }

  /// いまのビートのパッドを光らせ、間隔が過ぎたら次のビートへ。
  void _startBeat() {
    widget.controller.sfx.play(Sfx.tap); // ビートのきざみ
    _watch
      ..reset()
      ..start();
    setState(() {
      _phase = _Phase.playing;
      _perfect = false;
    });
    later(Duration(milliseconds: RhythmGame.intervalMsAt(_game.beat)), () {
      _game.nextBeat();
      if (_game.finished) {
        _finish();
      } else {
        _startBeat();
      }
    });
  }

  void _finish() {
    setState(() => _phase = _Phase.ready);
    later(const Duration(milliseconds: 500), () {
      widget.controller.finishMinigame(_game.reward);
      setState(() => _phase = _Phase.ended);
    });
  }

  void _tapPad(int pad) {
    if (_phase != _Phase.playing) return;
    switch (_game.tap(pad, _watch.elapsedMilliseconds)) {
      case RhythmTap.perfect:
        widget.controller.sfx.play(Sfx.happy);
        setState(() => _perfect = true);
      case RhythmTap.hit:
        widget.controller.sfx.play(Sfx.coin);
        setState(() {});
      case RhythmTap.wrongPad:
        widget.controller.sfx.play(Sfx.wrong);
      case RhythmTap.ignored:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lit = _phase == _Phase.playing && !_game.finished
        ? _game.pads[_game.beat]
        : null;
    return MinigameScaffold(
      title: '🎵 リズムタッチ',
      topColor: const Color(0xFFFFE9F2),
      bottomColor: const Color(0xFFE3F6FF),
      overlays: [
        if (_phase == _Phase.ended)
          GameEndOverlay(
            emoji: _game.reward > 0 ? '🎵' : '🙈',
            result: _game.reward > 0
                ? '+${_game.reward} コイン げっと!'
                : 'ざんねん! また ちょうせんしてね',
            buttonLabel: _game.reward > 0 ? 'やったー!' : 'つぎは がんばる!',
            onDone: () => Navigator.of(context).pop(),
          ),
      ],
      children: [
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StatPill('🎵 ${_game.hits}'),
            StatPill(
              'ビート ${(_game.beat + 1).clamp(1, rhythmBeats)}/$rhythmBeats',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _phase == _Phase.ready
              ? 'じゅんび…'
              : (_perfect ? '★ ぴったり!' : 'ひかった パッドを タッチ!'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ink2Color,
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (var i = 0; i < rhythmPads; i++) _pad(i, lit == i),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pad(int i, bool lit) {
    return AnimatedScale(
      scale: lit ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        key: ValueKey('rhythm-$i'),
        color: lit ? Colors.white : _padColors[i],
        borderRadius: BorderRadius.circular(26),
        elevation: lit ? 8 : 3,
        shadowColor: _padColors[i].withValues(alpha: 0.6),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _tapPad(i),
          child: Center(
            child: Text(
              const ['🌸', '💧', '🍀', '⭐'][i],
              style: TextStyle(fontSize: lit ? 44 : 34),
            ),
          ),
        ),
      ),
    );
  }
}

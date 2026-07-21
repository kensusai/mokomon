import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/ui_kit.dart';
import 'timer_bag.dart';

enum _Phase { showing, input, waiting, ended }

const _padColors = [
  Color(0xFFFF6EA6), // ピンク
  Color(0xFF54B9FF), // あお
  Color(0xFF34C98E), // みどり
  Color(0xFFFFC24B), // きいろ
];

/// おぼえてタッチ(docs/game-design.md §5)。光ったじゅんばんを覚えてタッチ。
class SimonScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final SimonGame? game;

  const SimonScreen({super.key, required this.controller, this.game});

  @override
  State<SimonScreen> createState() => _SimonScreenState();
}

class _SimonScreenState extends State<SimonScreen>
    with TimerBagMixin<SimonScreen> {
  late final _game = widget.game ?? SimonGame();
  var _phase = _Phase.waiting;
  int? _lit; // お手本/タップで光っているパッド
  Timer? _stepper;

  @override
  void initState() {
    super.initState();
    _after(800, _startShow);
  }

  @override
  void dispose() {
    _stepper?.cancel();
    super.dispose();
  }

  void _after(int ms, void Function() fn) =>
      later(Duration(milliseconds: ms), fn);

  /// お手本再生: 650msごとに1つずつ光らせ、終わったら入力フェーズへ。
  void _startShow() {
    setState(() => _phase = _Phase.showing);
    var k = 0;
    _stepper = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted) return;
      if (k >= _game.sequence.length) {
        t.cancel();
        setState(() {
          _lit = null;
          _phase = _Phase.input;
        });
        return;
      }
      widget.controller.sfx.play(Sfx.tap);
      setState(() => _lit = _game.sequence[k]);
      _after(420, () => setState(() => _lit = null));
      k++;
    });
  }

  void _tapPad(int pad) {
    if (_phase != _Phase.input) return;
    setState(() => _lit = pad);
    _after(220, () => setState(() => _lit = null));
    switch (_game.input(pad)) {
      case SimonInput.progress:
        widget.controller.sfx.play(Sfx.tap);
      case SimonInput.roundComplete:
        widget.controller.sfx.play(Sfx.happy);
        setState(() => _phase = _Phase.waiting);
        _after(800, _startShow);
      case SimonInput.gameComplete:
        widget.controller.sfx.play(Sfx.fanfare);
        _finish();
      case SimonInput.wrong:
        widget.controller.sfx.play(Sfx.wrong);
        _finish();
    }
  }

  void _finish() {
    setState(() => _phase = _Phase.waiting);
    _after(500, () {
      widget.controller.finishMinigame(_game.reward);
      setState(() => _phase = _Phase.ended);
    });
  }

  String get _hint => switch (_phase) {
        _Phase.showing => 'よーく みてて!',
        _Phase.input => 'おなじ じゅんばんで タッチ!',
        _ => 'じゅんび…',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFE9FF), Color(0xFFE3F6FF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    GameHeaderBar(
                      title: '💡 おぼえてタッチ',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 6),
                    Text('${_game.sequence.length}れんぞく! $_hint',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ink2Color)),
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
                              for (var i = 0; i < simonPads; i++) _pad(i),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_phase == _Phase.ended)
                GameEndOverlay(
                  emoji: _game.reward > 0 ? '💡' : '🙈',
                  result: _game.reward > 0
                      ? '+${_game.reward} コイン げっと!'
                      : 'ざんねん! また ちょうせんしてね',
                  onDone: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pad(int i) {
    final lit = _lit == i;
    return AnimatedScale(
      scale: lit ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Material(
        key: ValueKey('simon-$i'),
        color: lit ? Colors.white : _padColors[i],
        borderRadius: BorderRadius.circular(26),
        elevation: lit ? 8 : 3,
        shadowColor: _padColors[i].withValues(alpha: 0.6),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _tapPad(i),
          child: Center(
            child: Text(const ['🌸', '💧', '🍀', '⭐'][i],
                style: TextStyle(fontSize: lit ? 44 : 34)),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../logic/game_controller.dart';
import '../logic/minigames.dart';
import '../widgets/game_overlays.dart';
import '../widgets/minigame_scaffold.dart';
import '../widgets/ui_kit.dart';
import 'timer_bag.dart';

/// ラウンド内の状態。waiting=まだ光っていない / lit=光った(タッチ待ち)/
/// result=結果表示中(少し待って次ラウンドへ)。
enum _PikaPhase { waiting, lit, result }

/// ぴかっとタッチ(docs/game-design.md §5)。光った瞬間にすばやくタッチ。
/// フライングは0コインでラウンドが進む(ミス制の対象外)。
class PikaScreen extends StatefulWidget {
  final GameController controller;

  /// テストで seeded ゲームを注入するためのフック。
  final PikaGame? game;

  const PikaScreen({super.key, required this.controller, this.game});

  @override
  State<PikaScreen> createState() => _PikaScreenState();
}

class _PikaScreenState extends State<PikaScreen>
    with TimerBagMixin<PikaScreen> {
  late final _game = widget.game ?? PikaGame();
  final _watch = Stopwatch();
  var _phase = _PikaPhase.waiting;
  var _ended = false;

  /// ラウンドの通し番号。フライングでラウンドを消化しても前のラウンドの
  /// 「光らせるタイマー」は生きているため、番号で無効化しないと次の
  /// ラウンドが不当に早く光ってしまう。
  var _roundSeq = 0;
  String _message = 'いろが かわったら タッチ!';

  @override
  void initState() {
    super.initState();
    _armRound();
  }

  /// 次のラウンドを仕込む(ランダムな待ちのあとに光る)。
  void _armRound() {
    _phase = _PikaPhase.waiting;
    _message = 'いろが かわったら タッチ!';
    final seq = ++_roundSeq;
    later(Duration(milliseconds: _game.nextWaitMs()), () {
      if (_roundSeq != seq || _phase != _PikaPhase.waiting) return;
      _watch
        ..reset()
        ..start();
      setState(() => _phase = _PikaPhase.lit);
    });
  }

  void _onTap() {
    if (_ended || _phase == _PikaPhase.result) return;
    switch (_phase) {
      case _PikaPhase.waiting:
        // フライング: 0コインでラウンド消化
        _game.tooEarly();
        widget.controller.sfx.play(Sfx.wrong);
        _finishRound('あっ、フライング! ひかるまで まってね');
      case _PikaPhase.lit:
        _watch.stop();
        final coins = _game.hit(_watch.elapsedMilliseconds);
        widget.controller.sfx.play(coins >= 3 ? Sfx.happy : Sfx.tap);
        _finishRound(switch (coins) {
          3 => 'はやーい! +3コイン!',
          2 => 'いいね! +2コイン!',
          _ => 'タッチ! +1コイン!',
        });
      case _PikaPhase.result:
        break;
    }
  }

  void _finishRound(String message) {
    setState(() {
      _phase = _PikaPhase.result;
      _message = message;
    });
    later(const Duration(milliseconds: 900), () {
      if (_game.finished) {
        widget.controller.finishMinigame(_game.reward);
        setState(() => _ended = true);
      } else {
        setState(_armRound);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lit = _phase == _PikaPhase.lit;
    return MinigameScaffold(
      title: '🔆 ぴかっとタッチ',
      topColor: const Color(0xFFFFF6DE),
      bottomColor: const Color(0xFFE8F1FF),
      overlays: [
        if (_ended)
          GameEndOverlay(
            emoji: _game.reward > 0 ? '🔆' : '🐢',
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
        Expanded(
          child: Center(
            child: GestureDetector(
              key: const ValueKey('pika-lamp'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _onTap(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lit
                      ? const Color(0xFFFFD23E)
                      : const Color(0xFFDFE3EF),
                  boxShadow: lit
                      ? const [
                          BoxShadow(
                            color: Color(0x66FFD23E),
                            blurRadius: 48,
                            spreadRadius: 12,
                          ),
                        ]
                      : const [],
                ),
                child: Center(
                  child: Text(
                    lit ? '⚡' : '💤',
                    style: const TextStyle(fontSize: 84),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        RoundProgressDots(total: pikaRounds, current: _game.round),
      ],
    );
  }
}

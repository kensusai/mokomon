import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../data/foods.dart';
import '../logic/game_controller.dart';
import '../models/game_state.dart';
import '../widgets/book_sheet.dart';
import '../widgets/celebrate_overlay.dart';
import '../widgets/cloud.dart';
import '../widgets/code_dialog.dart';
import '../widgets/creature_view.dart';
import '../widgets/evolution_overlay.dart';
import '../widgets/food_sheet.dart';
import '../widgets/game_chooser.dart';
import '../widgets/particles.dart';
import '../widgets/shop_sheet.dart';
import '../widgets/stat_meter.dart';
import '../widgets/toast.dart';
import '../widgets/ui_kit.dart';
import 'catch_screen.dart';
import 'memory_screen.dart';
import 'paint_screen.dart';
import 'puzzle_screen.dart';

/// 💨の吹き出し(docs/game-design.md §9)。UIに説明は一切出さない。
const _puffLines = [
  '……いまの なあに?',
  'あれ? へんな おとが した!',
  '……なにも してないよ?',
  'ぷぅ♪',
  'きこえなかった ことに しよう…',
  'だ、だれかな? いまのは…',
];

/// ホーム画面。プロトタイプの screen-home に対応。
class HomeScreen extends StatefulWidget {
  final GameController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameController get c => widget.controller;
  GameState get s => c.state;

  final _creatureKey = GlobalKey<CreatureViewState>();
  final _creatureBoxKey = GlobalKey();
  final _particleKey = GlobalKey<ParticleFieldState>();
  final _rng = Random();

  String _hintMsg = '';
  bool _hintVisible = false;
  Timer? _hintTimer;
  Timer? _sparkleTimer;
  final _oneShotTimers = <Timer>[];
  bool _glowHinted = false;
  bool _evoBusy = false;

  // 模様(base64 PNG)のデコード結果キャッシュ
  ui.Image? _patternImage;
  String? _patternSource;

  @override
  void initState() {
    super.initState();
    c.addListener(_onStateChanged);
    _syncPattern();
    // 進化予兆のキラキラ(数値は出さない)。プロトタイプは2.2秒間隔。
    _sparkleTimer = Timer.periodic(
        const Duration(milliseconds: 2200), (_) => _spawnSparkle());
    if (s.stage == 0) {
      _later(
          const Duration(milliseconds: 800), () => _hint('たまごを タッチしてみて! 👆'));
    }
    // 既にしきい値を超えていた場合の追いつき進化
    _later(const Duration(milliseconds: 1200), _checkEvolve);
  }

  @override
  void dispose() {
    c.removeListener(_onStateChanged);
    _hintTimer?.cancel();
    _sparkleTimer?.cancel();
    for (final t in _oneShotTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _later(Duration d, VoidCallback fn) {
    _oneShotTimers.add(Timer(d, fn));
  }

  /// 予兆に入った瞬間に一度だけ吹き出しを出す(プロトタイプ glowHinted)。
  void _onStateChanged() {
    final near = s.nearEvolve;
    if (near && !_glowHinted) {
      _glowHinted = true;
      _later(
          const Duration(milliseconds: 600), () => _hint('なんだか からだが ひかってる…!'));
    }
    if (!near) _glowHinted = false;
    _syncPattern();
  }

  /// state.pattern (base64 PNG) を ui.Image にデコードして表示に反映する。
  void _syncPattern() {
    final p = s.pattern;
    if (p == _patternSource) return;
    _patternSource = p;
    if (p == null) {
      setState(() => _patternImage = null);
      return;
    }
    decodeImageFromList(base64Decode(p)).then((img) {
      if (mounted && _patternSource == p) {
        setState(() => _patternImage = img);
      }
    });
  }

  void _hint(String msg) {
    if (!mounted) return;
    setState(() {
      _hintMsg = msg;
      _hintVisible = true;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  // ---------- interactions ----------

  void _onCreatureTap(TapDownDetails d) {
    final box =
        _creatureBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final lowerBody = box != null && d.localPosition.dy / box.size.height > 0.7;
    switch (c.tapCreature(lowerBody: lowerBody)) {
      case CreatureTapOutcome.crack:
        _creatureKey.currentState?.play(CreatureAnim.wiggle);
        _hint(s.eggTaps == 1 ? 'あれ? なにか きこえる…' : 'ヒビが はいった! もういっかい!');
      case CreatureTapOutcome.hatched:
        _creatureKey.currentState?.play(CreatureAnim.wiggle);
        showCelebrate(context,
            sfx: c.sfx,
            emoji: '🐣',
            title: 'うまれた!',
            desc: '「${s.currentSpecies.names[1]}」が うまれたよ! ごはんを あげて そだてよう!');
      case CreatureTapOutcome.puffed:
        _showPuffEffects(box);
      case CreatureTapOutcome.petted:
        _creatureKey.currentState?.play(CreatureAnim.bounce);
        _spawnParticleAtGlobal(
            const ['💖', '💛', '⭐'][_rng.nextInt(3)], d.globalPosition);
        _checkEvolve();
    }
  }

  /// 💨の演出(状態変更は controller.tapCreature 側で済んでいる)。
  void _showPuffEffects(RenderBox? creatureBox) {
    _creatureKey.currentState?.play(CreatureAnim.wiggle);
    _hint(_puffLines[_rng.nextInt(_puffLines.length)]);
    if (creatureBox == null) return;
    const emojis = ['💨', '💨', '🌫️'];
    final field = _particleKey.currentContext?.findRenderObject() as RenderBox?;
    if (field == null) return;
    for (var i = 0; i < 3; i++) {
      final local = Offset(
        creatureBox.size.width * (0.28 + _rng.nextDouble() * 0.44),
        creatureBox.size.height * 0.82,
      );
      _particleKey.currentState?.spawnPuff(
        emojis[i],
        field.globalToLocal(creatureBox.localToGlobal(local)),
        driftX: (_rng.nextBool() ? -1 : 1) * (24 + _rng.nextDouble() * 36),
        delay: Duration(milliseconds: i * 120),
      );
    }
  }

  void _onFeedPressed() {
    if (s.stage == 0) {
      _hint('まずは たまごを タッチしてみて!');
      return;
    }
    if (c.isFull) {
      _hint('おなか いっぱい みたい!');
      return;
    }
    showFoodModal(context, c, onFed: _onFed);
  }

  Future<void> _onPlayPressed() async {
    if (s.stage == 0) {
      _hint('まずは たまごを タッチしてみて!');
      return;
    }
    final key = await showGameChooser(context);
    if (key == null || !mounted) return;
    final screen = switch (key) {
      'catch' => CatchScreen(controller: c),
      'puzzle' => PuzzleScreen(controller: c),
      _ => MemoryScreen(controller: c),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _checkEvolve();
  }

  Future<void> _onPaintPressed() async {
    if (s.stage == 0) {
      _hint('うまれてから おえかき できるよ!');
      return;
    }
    final saved = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PaintScreen(controller: c)));
    if (saved == true && mounted) {
      showToast(context, 'もようが かわったよ! ✨');
      await _checkEvolve();
    }
  }

  Future<void> _onBookPressed() async {
    final newSpecies = await showBookModal(context, c);
    if (newSpecies == null || !mounted) return;
    if (newSpecies == 3) {
      await showCelebrate(context,
          sfx: c.sfx,
          emoji: '🌟',
          title: 'なにこれ!?',
          desc: 'きんいろに かがやく たまごが とどいた…!');
    } else {
      c.sfx.play(Sfx.happy);
      _hint('あたらしい たまごが きたよ! タッチしてみて! 👆');
    }
  }

  void _onFed(Food food) {
    _creatureKey.currentState?.play(CreatureAnim.munch);
    final box =
        _creatureBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      _spawnParticleAtGlobal(
          food.emoji, box.localToGlobal(box.size.center(Offset.zero)));
    }
    _later(const Duration(milliseconds: 900), _checkEvolve);
  }

  Future<void> _checkEvolve() async {
    if (_evoBusy || !mounted) return;
    final next = s.evolveCheck();
    if (next == null) return;
    _evoBusy = true;
    await showEvolution(context, c, next);
    _evoBusy = false;
    if (next == 3 && mounted) {
      showToast(context, 'ずかんに とうろくされたよ! 📖から あたらしい たまごを むかえられるよ!');
    }
  }

  // ---------- particles ----------

  void _spawnParticleAtGlobal(String emoji, Offset globalPos) {
    final field = _particleKey.currentContext?.findRenderObject() as RenderBox?;
    if (field == null) return;
    _particleKey.currentState?.spawn(emoji, field.globalToLocal(globalPos));
  }

  void _spawnSparkle() {
    if (!mounted || !s.nearEvolve) return;
    final box =
        _creatureBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = Offset(
      20 + _rng.nextDouble() * (box.size.width - 40),
      10 + _rng.nextDouble() * box.size.height * 0.7,
    );
    _spawnParticleAtGlobal('✨', box.localToGlobal(local));
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE9FF), Color(0xFFE8F9EF)],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => Column(
              children: [
                _topBar(),
                Expanded(child: _stage()),
                _bottomCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            StatPill('🪙 ${s.coins}'),
            const Spacer(),
            StatPill(s.displayName),
            const Spacer(),
            _iconButton('📖', _onBookPressed),
            const SizedBox(width: 8),
            _iconButton('💾', () => showCodeDialog(context, c)),
            const SizedBox(width: 8),
            _iconButton(s.sound ? '🔊' : '🔇', c.toggleSound),
          ],
        ),
      );

  Widget _iconButton(String emoji, VoidCallback onTap) => CircleIconButton(
        onTap: onTap,
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      );

  Widget _stage() {
    final creatureSize = min(MediaQuery.sizeOf(context).width * 0.64, 300.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(top: 40, left: 30, child: Cloud(width: 70)),
        const Positioned(top: 90, right: 36, child: Cloud(width: 56)),
        // 地面の影
        Align(
          alignment: const Alignment(0, 0.86),
          child: FractionallySizedBox(
            widthFactor: 0.7,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0x4034C98E),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onCreatureTap,
            child: SizedBox(
              key: _creatureBoxKey,
              width: creatureSize,
              height: creatureSize,
              child: CreatureView(
                  key: _creatureKey, state: s, pattern: _patternImage),
            ),
          ),
        ),
        Positioned.fill(child: ParticleField(key: _particleKey)),
        // ヒント吹き出し
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _hintVisible ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x1F3A3F52),
                          blurRadius: 24,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: Text(_hintMsg,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: inkColor)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomCard() => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            StatMeter(
                icon: '🍖',
                value: s.hunger,
                colors: const [Color(0xFFFFC46B), Color(0xFFFF9A3D)]),
            const SizedBox(height: 10),
            StatMeter(
                icon: '💖',
                value: s.happy,
                colors: const [Color(0xFFFF9CC2), Color(0xFFFF6EA6)]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BigActionButton(
                    icon: '🍎',
                    label: 'ごはん',
                    sub: '3しゅるい',
                    colors: orangeGradient,
                    onTap: _onFeedPressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BigActionButton(
                    icon: '🎮',
                    label: 'あそぶ',
                    sub: 'コインげっと',
                    colors: greenGradient,
                    onTap: _onPlayPressed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: BigActionButton(
                    icon: '🎨',
                    label: 'おえかき',
                    sub: 'もようがえ',
                    colors: purpleGradient,
                    onTap: _onPaintPressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BigActionButton(
                    icon: '🛍️',
                    label: 'おみせ',
                    sub: 'きせかえ',
                    colors: blueGradient,
                    onTap: () => showShopModal(context, c),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

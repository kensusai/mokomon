import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../data/backgrounds.dart';
import '../data/foods.dart';
import '../logic/game_controller.dart';
import '../models/game_state.dart';
import '../widgets/book_sheet.dart';
import '../widgets/celebrate_overlay.dart';
import '../widgets/cloud.dart';
import '../widgets/creature_faces.dart';
import '../widgets/code_dialog.dart';
import '../widgets/creature_view.dart';
import '../widgets/evolution_overlay.dart';
import '../widgets/food_sheet.dart';
import '../widgets/game_chooser.dart';
import '../widgets/particles.dart';
import '../widgets/rename_dialog.dart';
import '../widgets/shop_sheet.dart';
import '../widgets/stat_meter.dart';
import '../widgets/toast.dart';
import '../widgets/ui_kit.dart';
import 'balloon_screen.dart';
import 'catch_screen.dart';
import 'memory_screen.dart';
import 'odd_one_screen.dart';
import 'order_screen.dart';
import 'paint_screen.dart';
import 'puzzle_screen.dart';
import 'trace_screen.dart';
import 'whack_screen.dart';

/// 💨の吹き出し(docs/game-design.md §9)。UIに説明は一切出さない。
const _puffLines = [
  '……いまの なあに?',
  'あれ? へんな おとが した!',
  '……なにも してないよ?',
  'ぷぅ♪',
  'きこえなかった ことに しよう…',
  'だ、だれかな? いまのは…',
];

/// なでなでのタップ位置ゾーン(下部30%は💨なのでここには来ない)。
enum _PetZone { head, belly, side }

/// ゾーンごとの反応(セリフ・パーティクル・鳴き声・動き)。docs/game-design.md §3。
const _petLines = {
  _PetZone.head: ['えへへ〜', 'あたま なでなで すき!', 'もっと なでて〜', 'きもちいい〜'],
  _PetZone.belly: ['くすぐったい〜!', 'ぽんぽん だいすき', 'ぷにぷに でしょ?', 'ぽかぽか する〜'],
  _PetZone.side: ['ひゃっ!', 'そこ そこ〜!', 'わきわき くすぐったい!', 'なになに〜?'],
};

const _petParticles = {
  _PetZone.head: ['✨', '💛', '🌟'],
  _PetZone.belly: ['💖', '💗', '💕'],
  _PetZone.side: ['🎵', '⭐', '💫'],
};

const _petAnims = {
  _PetZone.head: CreatureAnim.wiggle,
  _PetZone.belly: CreatureAnim.bounce,
  _PetZone.side: CreatureAnim.wiggle,
};

/// BGMの曲名(🎵ボタンで切替。SfxPlayer.bgmTracks と対応)。
const _bgmNames = ['そよかぜ', 'わくわく', 'ぽかぽか'];

/// お絵かきを保存したときの褒めセリフ(docs/game-design.md §6)。
const _paintPraiseLines = [
  'わあ! すてきな もよう!',
  'かわいく なっちゃった!',
  'みてみて〜!',
  'あたらしい もよう だいすき!',
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
  int _hintSeq = 0; // 変わるたびに吹き出しのポップ演出をやり直す
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

  double _lastSparkle = 0;

  /// きらきらゲージの途中経過を吹き出しで知らせる(進捗の手ごたえ)。
  void _sparkleProgressHint() {
    final v = s.kingSparkle;
    if (s.stage == 3) {
      if (_lastSparkle < 50 && v >= 50) _hint('きらきらが たまってきた…!');
      if (_lastSparkle < 85 && v >= 85) _hint('もうすこしで なにか おこりそう…!');
    }
    _lastSparkle = v;
  }

  /// おみやげが発生していたら受け取ってお祝いする(docs §14)。
  void _maybeShowGift() {
    final gift = c.takePendingGift();
    if (gift == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _creatureKey.currentState?.play(CreatureAnim.spin);
      showCelebrate(
        context,
        sfx: c.sfx,
        emoji: '🎆',
        title: 'おうさまの おみやげ!',
        desc: gift.stamp != null
            ? 'あたらしい スタンプ「${gift.stamp}」が つかえるように なったよ!(+${gift.coins}コインも!)'
            : 'コインを ${gift.coins}まい もらったよ!',
      );
    });
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
    _sparkleProgressHint();
    _maybeShowGift();
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
      _hintSeq++;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  // ---------- interactions ----------

  /// タップ位置から反応ゾーンを決める(上34%=あたま/左右30%=よこ/残り=おなか)。
  _PetZone _zoneOf(Offset local, Size size) {
    if (local.dy / size.height < 0.34) return _PetZone.head;
    final x = local.dx / size.width;
    if (x < 0.30 || x > 0.70) return _PetZone.side;
    return _PetZone.belly;
  }

  void _onCreatureTap(TapDownDetails d) {
    final box =
        _creatureBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final lowerBody = box != null && d.localPosition.dy / box.size.height > 0.7;
    final zone =
        box == null ? _PetZone.belly : _zoneOf(d.localPosition, box.size);

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
        _creatureKey.currentState?.flashMood(CreatureMood.surprised);
        _showPuffEffects(box);
      case CreatureTapOutcome.petted:
        // ゾーンごとに動き・パーティクル・セリフを変える(反応バリエーション)
        _creatureKey.currentState?.flashMood(CreatureMood.happy);
        _creatureKey.currentState?.play(_petAnims[zone]!);
        final particles = _petParticles[zone]!;
        _spawnParticleAtGlobal(
            particles[_rng.nextInt(particles.length)], d.globalPosition);
        final lines = _petLines[zone]!;
        _hint(lines[_rng.nextInt(lines.length)]);
        _checkEvolve();
    }
  }

  /// 💨の演出(状態変更は controller.tapCreature 側で済んでいる)。
  void _showPuffEffects(RenderBox? creatureBox) {
    _creatureKey.currentState?.play(CreatureAnim.wiggle);
    _hint(_puffLines[_rng.nextInt(_puffLines.length)]);
    if (creatureBox == null) return;
    // おなら感アップ: もくもく5連・大きめ・遠くまで(こどもFB)
    const emojis = ['💨', '💨', '💨', '🌫️', '🌫️'];
    final field = _particleKey.currentContext?.findRenderObject() as RenderBox?;
    if (field == null) return;
    for (var i = 0; i < emojis.length; i++) {
      final local = Offset(
        creatureBox.size.width * (0.22 + _rng.nextDouble() * 0.56),
        creatureBox.size.height * (0.78 + _rng.nextDouble() * 0.1),
      );
      _particleKey.currentState?.spawnPuff(
        emojis[i],
        field.globalToLocal(creatureBox.localToGlobal(local)),
        driftX: (_rng.nextBool() ? -1 : 1) * (34 + _rng.nextDouble() * 56),
        delay: Duration(milliseconds: i * 100),
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
      'whack' => WhackScreen(controller: c),
      'balloon' => BalloonScreen(controller: c),
      'order' => OrderScreen(controller: c),
      'trace' => TraceScreen(controller: c),
      'odd' => OddOneScreen(controller: c),
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
      _celebratePaint();
      await _checkEvolve();
    }
  }

  /// お絵かき保存の褒め演出: くるっと回る+キラキラ+褒めセリフ。
  void _celebratePaint() {
    _creatureKey.currentState?.flashMood(CreatureMood.happy,
        duration: const Duration(milliseconds: 1600));
    _creatureKey.currentState?.play(CreatureAnim.spin);
    _hint(_paintPraiseLines[_rng.nextInt(_paintPraiseLines.length)]);
    final box =
        _creatureBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    const sparkles = ['✨', '🌸', '💖', '✨', '⭐', '🌸'];
    for (var i = 0; i < sparkles.length; i++) {
      final local = Offset(
        box.size.width * (0.15 + _rng.nextDouble() * 0.7),
        box.size.height * (0.1 + _rng.nextDouble() * 0.6),
      );
      _spawnParticleAtGlobal(sparkles[i], box.localToGlobal(local));
    }
  }

  Future<void> _onRenamePressed() async {
    if (s.stage == 0) {
      _hint('うまれたら なまえを つけられるよ!');
      return;
    }
    final name = await showRenameDialog(context, current: s.nickname);
    if (name == null || !mounted) return;
    c.rename(name);
    _creatureKey.currentState?.flashMood(CreatureMood.happy);
    _creatureKey.currentState?.play(CreatureAnim.bounce);
    _hint(s.nickname == null ? 'なまえを もとに もどしたよ!' : '「${s.nickname}」って よんでね!');
  }

  Future<void> _onBookPressed() async {
    final result = await showBookModal(context, c);
    if (result == null || !mounted) return;
    switch (result) {
      case BookNewEgg(species: final sp):
        if (sp == 3) {
          await showCelebrate(context,
              sfx: c.sfx,
              emoji: '🌟',
              title: 'なにこれ!?',
              desc: 'きんいろに かがやく たまごが とどいた…!');
        } else {
          c.sfx.play(Sfx.happy);
          _hint('あたらしい たまごが きたよ! タッチしてみて! 👆');
        }
      case BookSwitch(species: final sp):
        if (c.switchCreature(sp)) {
          _creatureKey.currentState?.flashMood(CreatureMood.happy);
          _creatureKey.currentState?.play(CreatureAnim.spin);
          _hint(
              '「${s.nickname ?? s.currentSpecies.names[s.stage]}」が あそびに きたよ!');
        }
    }
  }

  void _onFed(Food food) {
    _creatureKey.currentState?.flashMood(CreatureMood.yum,
        duration: const Duration(milliseconds: 1400));
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
    final bg = bgThemes[s.effectiveBg];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg.top, bg.bottom],
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
            _iconButton('📖', _onBookPressed),
            const SizedBox(width: 8),
            _iconButton('💾', () => showCodeDialog(context, c)),
            const SizedBox(width: 8),
            _iconButton('🎵', () {
              final track = c.cycleBgm();
              _hint('♪ ${_bgmNames[track]}');
            }),
            const SizedBox(width: 8),
            _iconButton(s.sound ? '🔊' : '🔇', c.toggleSound),
          ],
        ),
      );

  Widget _iconButton(String emoji, VoidCallback onTap) => CircleIconButton(
        onTap: onTap,
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      );

  /// 背景テーマごとの飾り(雲・月・あわ・木など)。docs/game-design.md §13。
  List<Widget> _bgDecor() {
    const deco = TextStyle(fontSize: 40);
    switch (bgThemes[s.effectiveBg].key) {
      case 'yuyake':
        return [
          Positioned(
            top: 30,
            right: 30,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0xFFFFE28A), Color(0xFFFFB25E)]),
              ),
            ),
          ),
          const Positioned(top: 90, left: 30, child: Cloud(width: 62)),
        ];
      case 'yozora':
        return const [
          Positioned(top: 24, right: 34, child: Text('🌙', style: deco)),
          Positioned(
              top: 80,
              left: 40,
              child: Text('✨', style: TextStyle(fontSize: 22))),
          Positioned(
              top: 40,
              left: 110,
              child: Text('✨', style: TextStyle(fontSize: 16))),
          Positioned(
              top: 120,
              right: 90,
              child: Text('✨', style: TextStyle(fontSize: 18))),
        ];
      case 'umi':
        return [
          for (final b in const [
            (30.0, 60.0, 18.0),
            (90.0, 120.0, 12.0),
            (300.0, 50.0, 14.0),
            (260.0, 130.0, 10.0)
          ])
            Positioned(
              left: b.$1,
              top: b.$2,
              child: Container(
                width: b.$3,
                height: b.$3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          const Positioned(
              top: 40,
              right: 40,
              child: Text('🐠', style: TextStyle(fontSize: 28))),
        ];
      case 'mori':
        return const [
          Positioned(bottom: 10, left: 8, child: Text('🌳', style: deco)),
          Positioned(bottom: 14, right: 8, child: Text('🌲', style: deco)),
          Positioned(top: 40, left: 40, child: Cloud(width: 56)),
        ];
      case 'yuki':
        return const [
          Positioned(top: 40, left: 30, child: Cloud(width: 70)),
          Positioned(
              top: 100,
              right: 50,
              child: Text('❄️', style: TextStyle(fontSize: 22))),
          Positioned(
              top: 50,
              right: 120,
              child: Text('❄️', style: TextStyle(fontSize: 16))),
          Positioned(bottom: 30, right: 20, child: Text('⛄', style: deco)),
        ];
      default: // sora
        return const [
          Positioned(top: 40, left: 30, child: Cloud(width: 70)),
          Positioned(top: 90, right: 36, child: Cloud(width: 56)),
        ];
    }
  }

  Widget _stage() {
    final creatureSize = min(MediaQuery.sizeOf(context).width * 0.64, 300.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._bgDecor(),
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

        // セリフ(枠なしカラフル文字・上/左/右に出る)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hintVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _SpeechText(message: _hintMsg, seed: _hintSeq),
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
            // なまえ(タップで改名)
            GestureDetector(
              onTap: _onRenamePressed,
              child: StatPill(s.displayName),
            ),
            const SizedBox(height: 10),
            if (s.stage == 3) ...[
              // キング専用: きらきらゲージ(満タンでおみやげ)
              StatMeter(
                  icon: '✨',
                  value: s.kingSparkle,
                  colors: const [Color(0xFFFFE28A), Color(0xFFF0A92D)]),
              const SizedBox(height: 10),
            ],
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

/// 枠なしのカラフルなセリフ表示。seed ごとに色(6色)と
/// 位置(上・左・右)が入れ替わり、ぽよんと弾んで登場する。
class _SpeechText extends StatelessWidget {
  final String message;
  final int seed;
  const _SpeechText({required this.message, required this.seed});

  static const _colors = [
    Color(0xFFFF4F96), // ピンク
    Color(0xFFFF8F1F), // オレンジ
    Color(0xFFFFB300), // きいろ
    Color(0xFF1FAE76), // みどり
    Color(0xFF3BA4EC), // そら
    Color(0xFF8A78F5), // むらさき
  ];

  /// 上・左・右(左右はいきものの顔の高さあたり)
  static const _aligns = [
    Alignment(0, -1),
    Alignment(-0.95, -0.5),
    Alignment(0.95, -0.5),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[(seed * 5) % _colors.length];
    final align = _aligns[seed % _aligns.length];
    final angle = ((seed * 37) % 9 - 4) * 3.14159 / 180; // -4°〜+4°

    const style = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

    return Align(
      alignment: align,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(seed),
        tween: Tween(begin: 0.3, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: t, child: child),
        ),
        // 長いセリフは自動で縮めてはみ出さない
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            children: [
              // 白フチ(空色背景でも読めるように)+うっすら影
              Text(message,
                  style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 8
                      ..strokeJoin = StrokeJoin.round
                      ..color = Colors.white,
                    shadows: const [
                      Shadow(
                          color: Color(0x553A3F52),
                          blurRadius: 10,
                          offset: Offset(0, 4)),
                    ],
                  )),
              Text(message, style: style.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

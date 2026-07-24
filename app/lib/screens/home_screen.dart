import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/sound_synth.dart';
import '../data/backgrounds.dart';
import '../data/foods.dart';
import '../data/species.dart';
import '../logic/game_controller.dart';
import '../models/game_state.dart';
import '../widgets/bg_decor.dart';
import '../widgets/book_sheet.dart';
import '../widgets/celebrate_overlay.dart';
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
import 'count_screen.dart';
import 'compare_screen.dart';
import 'pika_screen.dart';
import 'simon_screen.dart';
import 'memory_screen.dart';
import 'odd_one_screen.dart';
import 'order_screen.dart';
import 'paint_screen.dart';
import 'puzzle_screen.dart';
import 'timer_bag.dart';
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
enum _PetZone { head, belly, side, feet }

/// ゾーンごとの反応(セリフ・パーティクル・鳴き声・動き)。docs/game-design.md §3。
const _petLines = {
  _PetZone.head: ['えへへ〜', 'あたま なでなで すき!', 'もっと なでて〜', 'きもちいい〜'],
  _PetZone.belly: ['くすぐったい〜!', 'ぽんぽん だいすき', 'ぷにぷに でしょ?', 'ぽかぽか する〜'],
  _PetZone.side: ['ひゃっ!', 'そこ そこ〜!', 'わきわき くすぐったい!', 'なになに〜?'],
  _PetZone.feet: ['てちてち♪', 'あんよ こちょこちょ?', 'あしもと くすぐったい!', 'ぴょこぴょこ!'],
};

const _petParticles = {
  _PetZone.head: ['✨', '💛', '🌟'],
  _PetZone.belly: ['💖', '💗', '💕'],
  _PetZone.side: ['🎵', '⭐', '💫'],
  _PetZone.feet: ['🐾', '✨', '💫'],
};

const _petAnims = {
  _PetZone.head: CreatureAnim.wiggle,
  _PetZone.belly: CreatureAnim.bounce,
  _PetZone.side: CreatureAnim.wiggle,
  _PetZone.feet: CreatureAnim.bounce,
};

/// ゾーンごとのタッチ音(docs/game-design.md §3。こどもFBで追加)。
const _petSfx = {
  _PetZone.head: Sfx.petHead,
  _PetZone.belly: Sfx.petBelly,
  _PetZone.side: Sfx.petCheek,
  _PetZone.feet: Sfx.petFeet,
};

/// BGMの曲名(🎵ボタンで切替。SfxPlayer.bgmTracks と対応)。
const _bgmNames = ['そよかぜ', 'わくわく', 'ぽかぽか'];

/// ひとりごと(放置中に勝手にしゃべる。docs/game-design.md §3)。
const _idleLines = [
  'ねえねえ、あそぼ〜!',
  'なでなで して〜',
  'おなか すいたかも…',
  'ふんふんふ〜ん♪',
  'きょうも いい てんき!',
  'ひまだな〜',
  'こっち みて〜!',
  'だいすきだよ♪',
];

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

class _HomeScreenState extends State<HomeScreen>
    with TimerBagMixin<HomeScreen> {
  GameController get c => widget.controller;
  GameState get s => c.state;

  final _creatureKey = GlobalKey<CreatureViewState>();
  final _creatureBoxKey = GlobalKey();
  final _particleKey = GlobalKey<ParticleFieldState>();
  final _rng = Random();

  /// 「あそぶ」「おえかき」の連打で画面が二重に積まれないためのガード。
  /// docs/review-findings.md #15。
  bool _navigating = false;

  String _hintMsg = '';
  bool _hintVisible = false;
  int _hintSeq = 0; // 変わるたびに吹き出しのポップ演出をやり直す
  Timer? _hintTimer;
  Timer? _sparkleTimer;
  Timer? _idleTimer;
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
      const Duration(milliseconds: 2200),
      (_) => _spawnSparkle(),
    );
    if (s.stage == 0) {
      later(const Duration(milliseconds: 800), () => _hint('たまごを タッチしてみて! 👆'));
    }
    // 既にしきい値を超えていた場合の追いつき進化
    later(const Duration(milliseconds: 1200), _checkEvolve);
    _scheduleIdleChatter();
  }

  /// 放置中のひとりごと(20〜32秒ごと)。単調さ対策(こどもFB)。
  void _scheduleIdleChatter() {
    _idleTimer?.cancel();
    _idleTimer = Timer(Duration(milliseconds: 20000 + _rng.nextInt(12000)), () {
      if (!mounted) return;
      if (s.stage == 0) {
        // たまごがときどき ゆれる
        _creatureKey.currentState?.play(CreatureAnim.wiggle);
        _hint('たまごが ゆれた…!?');
      } else {
        c.sfx.playBabble(s.species);
        _creatureKey.currentState?.play(CreatureAnim.wiggle);
        _hint(_idleLines[_rng.nextInt(_idleLines.length)]);
      }
      _scheduleIdleChatter();
    });
  }

  @override
  void dispose() {
    c.removeListener(_onStateChanged);
    _hintTimer?.cancel();
    _sparkleTimer?.cancel();
    _idleTimer?.cancel();
    _patternImage?.dispose();
    super.dispose();
  }

  double _lastSparkle = 0;

  /// きらきらゲージの途中経過を吹き出しで知らせる(進捗の手ごたえ)。
  void _sparkleProgressHint() {
    final v = s.kingSparkle;
    if (s.stage == kingStage) {
      if (_lastSparkle < 50 && v >= 50) _hint('きらきらが たまってきた…!');
      if (_lastSparkle < 85 && v >= 85) _hint('もうすこしで なにか おこりそう…!');
    }
    _lastSparkle = v;
  }

  /// おみやげが発生していたら受け取ってお祝いする(docs §14)。
  /// ミニゲーム等がホームの上に積まれている間は消費せず、復帰後に受け取る
  /// (見えない画面の上にダイアログが被るのを防ぐ。docs/review-findings.md #51)。
  void _maybeShowGift() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
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
      later(
        const Duration(milliseconds: 600),
        () => _hint('なんだか からだが ひかってる…!'),
      );
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
      setState(() => _setPatternImage(null));
      return;
    }
    decodeImageFromList(base64Decode(p))
        .then((img) {
          if (mounted && _patternSource == p) {
            setState(() => _setPatternImage(img));
          } else {
            // 画面破棄後・デコード中に模様が変わった場合は表示されないまま捨てる
            img.dispose();
          }
        })
        .catchError((Object _) {
          // 画像として壊れたデータは模様なしとして無視(docs/review-findings.md #43)
        });
  }

  /// `_patternImage` の差し替え。`ui.Image` はネイティブ側メモリを持つため、
  /// 古い参照は明示的に dispose する(docs/review-findings.md #18)。
  void _setPatternImage(ui.Image? img) {
    _patternImage?.dispose();
    _patternImage = img;
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

  /// タップ位置から反応ゾーンを決める
  /// (上34%=あたま/下30%=あんよ/左右30%=ほっぺ/残り=おなか)。
  _PetZone _zoneOf(Offset local, Size size) {
    final y = local.dy / size.height;
    if (y < 0.34) return _PetZone.head;
    if (y > 0.70) return _PetZone.feet;
    final x = local.dx / size.width;
    if (x < 0.30 || x > 0.70) return _PetZone.side;
    return _PetZone.belly;
  }

  void _onCreatureTap(TapDownDetails d) {
    final box =
        _creatureBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final lowerBody = box != null && d.localPosition.dy / box.size.height > 0.7;
    final zone = box == null
        ? _PetZone.belly
        : _zoneOf(d.localPosition, box.size);

    switch (c.tapCreature(lowerBody: lowerBody)) {
      case CreatureTapOutcome.crack:
        _creatureKey.currentState?.play(CreatureAnim.wiggle);
        _hint(s.eggTaps == 1 ? 'あれ? なにか きこえる…' : 'ヒビが はいった! もういっかい!');
      case CreatureTapOutcome.hatched:
        _creatureKey.currentState?.play(CreatureAnim.wiggle);
        // 進化リビールと同じ路線の効果音(BGMを一時停止して主役にする)
        showCelebrate(
          context,
          sfx: c.sfx,
          sound: Sfx.megaFanfare,
          duckBgm: true,
          emoji: '🐣',
          title: 'うまれた!',
          desc: '「${s.currentSpecies.names[1]}」が うまれたよ! ごはんを あげて そだてよう!',
        );
      case CreatureTapOutcome.puffed:
        _creatureKey.currentState?.flashMood(CreatureMood.surprised);
        _showPuffEffects(box);
      case CreatureTapOutcome.petted:
        // ゾーンごとに音・動き・パーティクル・セリフを変える(反応バリエーション)
        c.sfx.play(_petSfx[zone]!);
        _creatureKey.currentState?.flashMood(CreatureMood.happy);
        _creatureKey.currentState?.play(_petAnims[zone]!);
        final particles = _petParticles[zone]!;
        _spawnParticleAtGlobal(
          particles[_rng.nextInt(particles.length)],
          d.globalPosition,
        );
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
    if (_navigating) return;
    _navigating = true;
    try {
      final key = await showGameChooser(context);
      if (key == null || !mounted) return;
      // ゲーム中は専用BGM(2曲からランダムでメリハリ)
      c.sfx.playOverrideBgm(_rng.nextBool() ? Sfx.bgmGame : Sfx.bgmGame2);
      final screen = switch (key) {
        'catch' => CatchScreen(controller: c),
        'puzzle' => PuzzleScreen(controller: c),
        'whack' => WhackScreen(controller: c),
        'balloon' => BalloonScreen(controller: c),
        'order' => OrderScreen(controller: c),
        'trace' => TraceScreen(controller: c),
        'odd' => OddOneScreen(controller: c),
        'count' => CountScreen(controller: c),
        'simon' => SimonScreen(controller: c),
        'compare' => CompareScreen(controller: c),
        'pika' => PikaScreen(controller: c),
        _ => MemoryScreen(controller: c),
      };
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
      c.sfx.clearOverrideBgm(); // ホームBGMへ戻す(勝利曲中なら曲側が戻す)
      if (!mounted) return;
      c.sfx.playBabble(s.species);
      _hint('たのしかった〜!');
      await _checkEvolve();
      _maybeShowGift(); // ゲーム中に発生したおみやげは戻ってから受け取る(#51)
    } finally {
      _navigating = false;
    }
  }

  Future<void> _onPaintPressed() async {
    if (s.stage == 0) {
      _hint('うまれてから おえかき できるよ!');
      return;
    }
    if (_navigating) return;
    _navigating = true;
    try {
      c.sfx.playOverrideBgm(Sfx.bgmPaint); // おえかき中はまったり曲
      final saved = await Navigator.of(context).push(
        MaterialPageRoute<bool>(builder: (_) => PaintScreen(controller: c)),
      );
      c.sfx.clearOverrideBgm();
      if (saved == true && mounted) {
        _celebratePaint();
        await _checkEvolve();
        _maybeShowGift(); // おえかき中に発生したおみやげも同様(#51)
      }
    } finally {
      _navigating = false;
    }
  }

  /// お絵かき保存の褒め演出: くるっと回る+キラキラ+褒めセリフ。
  void _celebratePaint() {
    _creatureKey.currentState?.flashMood(
      CreatureMood.happy,
      duration: const Duration(milliseconds: 1600),
    );
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
        if (sp == secretSpeciesIndex) {
          await showCelebrate(
            context,
            sfx: c.sfx,
            emoji: '🌟',
            title: 'なにこれ!?',
            desc: 'きんいろに かがやく たまごが とどいた…!',
          );
        } else {
          c.sfx.play(Sfx.happy);
          _hint('あたらしい たまごが きたよ! タッチしてみて! 👆');
        }
      case BookSwitch(species: final sp):
        if (c.switchCreature(sp)) {
          _creatureKey.currentState?.flashMood(CreatureMood.happy);
          _creatureKey.currentState?.play(CreatureAnim.spin);
          _hint(
            '「${s.nickname ?? s.currentSpecies.names[s.stage]}」が あそびに きたよ!',
          );
        }
    }
  }

  void _onFed(Food food) {
    _creatureKey.currentState?.flashMood(
      CreatureMood.yum,
      duration: const Duration(milliseconds: 1400),
    );
    _creatureKey.currentState?.play(CreatureAnim.munch);
    final box =
        _creatureBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      _spawnParticleAtGlobal(
        food.emoji,
        box.localToGlobal(box.size.center(Offset.zero)),
      );
    }
    later(const Duration(milliseconds: 900), _checkEvolve);
  }

  Future<void> _checkEvolve() async {
    if (_evoBusy || !mounted) return;
    final next = s.evolveCheck();
    if (next == null) return;
    _evoBusy = true;
    await showEvolution(context, c, next);
    _evoBusy = false;
    if (next == kingStage && mounted) {
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

  Widget _stage() {
    final creatureSize = min(MediaQuery.sizeOf(context).width * 0.64, 300.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...bgDecor(bgThemes[s.effectiveBg].key),
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
                key: _creatureKey,
                state: s,
                pattern: _patternImage,
              ),
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
        // きらきらゲージのメーターは出さない(こどもFB「増えないゲージが
        // 気になる」。進化と同じサプライズ重視で、進捗は50%/85%の吹き出し
        // だけで見せる。docs/game-design.md §14)
        StatMeter(
          icon: '🍖',
          value: s.hunger,
          colors: const [Color(0xFFFFC46B), Color(0xFFFF9A3D)],
        ),
        const SizedBox(height: 10),
        StatMeter(
          icon: '💖',
          value: s.happy,
          colors: const [Color(0xFFFF9CC2), Color(0xFFFF6EA6)],
        ),
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
    final angle = ((seed * 37) % 9 - 4) * pi / 180; // -4°〜+4°

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
              Text(
                message,
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
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
              Text(message, style: style.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/foods.dart';
import '../logic/game_controller.dart';
import '../models/game_state.dart';
import '../widgets/celebrate_overlay.dart';
import '../widgets/creature_view.dart';
import '../widgets/evolution_overlay.dart';
import '../widgets/food_sheet.dart';
import '../widgets/game_chooser.dart';
import '../widgets/particles.dart';
import '../widgets/toast.dart';
import 'catch_screen.dart';
import 'memory_screen.dart';
import 'puzzle_screen.dart';

/// ホーム画面。プロトタイプの screen-home に対応。
/// TODO(Phase 2-4): あそぶ/おえかき/おみせボタン、ずかん/セーブ/サウンド、💨。
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

  @override
  void initState() {
    super.initState();
    c.addListener(_onStateChanged);
    // 進化予兆のキラキラ(数値は出さない)。プロトタイプは2.2秒間隔。
    _sparkleTimer = Timer.periodic(
        const Duration(milliseconds: 2200), (_) => _spawnSparkle());
    if (s.stage == 0) {
      _later(const Duration(milliseconds: 800),
          () => _hint('たまごを タッチしてみて! 👆'));
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
      _later(const Duration(milliseconds: 600),
          () => _hint('なんだか からだが ひかってる…!'));
    }
    if (!near) _glowHinted = false;
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
    if (s.stage == 0) {
      final outcome = c.tapEgg();
      _creatureKey.currentState?.play(CreatureAnim.wiggle);
      switch (outcome) {
        case EggTapOutcome.crack:
          _hint(s.eggTaps == 1 ? 'あれ? なにか きこえる…' : 'ヒビが はいった! もういっかい!');
        case EggTapOutcome.hatched:
          showCelebrate(context,
              emoji: '🐣',
              title: 'うまれた!',
              desc: '「${s.currentSpecies.names[1]}」が うまれたよ! ごはんを あげて そだてよう!');
      }
      return;
    }
    // TODO(Phase 4): 下部30%タップ or 6% で💨
    c.pet();
    _creatureKey.currentState?.play(CreatureAnim.bounce);
    _spawnParticleAtGlobal(
        const ['💖', '💛', '⭐'][_rng.nextInt(3)], d.globalPosition);
    _checkEvolve();
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
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _checkEvolve();
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
            _pill('🪙 ${s.coins}'),
            const Spacer(),
            _pill(s.displayName),
            const Spacer(),
            // TODO(Phase 3-4): ずかん/セーブ/サウンドのアイコンボタン
          ],
        ),
      );

  Widget _stage() {
    final creatureSize = min(MediaQuery.sizeOf(context).width * 0.64, 300.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(top: 40, left: 30, child: _Cloud(width: 70)),
        const Positioned(top: 90, right: 36, child: _Cloud(width: 56)),
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
              child: CreatureView(key: _creatureKey, state: s),
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
                          color: Color(0xFF3A3F52))),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F3A3F52), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      );

  Widget _bottomCard() => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            _Meter(
                icon: '🍖',
                value: s.hunger,
                colors: const [Color(0xFFFFC46B), Color(0xFFFF9A3D)]),
            const SizedBox(height: 10),
            _Meter(
                icon: '💖',
                value: s.happy,
                colors: const [Color(0xFFFF9CC2), Color(0xFFFF6EA6)]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BigButton(
                    icon: '🍎',
                    label: 'ごはん',
                    sub: '3しゅるい',
                    colors: const [Color(0xFFFFAB49), Color(0xFFFF8F1F)],
                    onTap: _onFeedPressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BigButton(
                    icon: '🎮',
                    label: 'あそぶ',
                    sub: 'コインげっと',
                    colors: const [Color(0xFF34C98E), Color(0xFF1FAE76)],
                    onTap: _onPlayPressed,
                  ),
                ),
                // TODO(Phase 3): おえかき / おみせ ボタン
              ],
            ),
          ],
        ),
      );
}

class _Meter extends StatelessWidget {
  final String icon;
  final double value;
  final List<Color> colors;
  const _Meter({required this.icon, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 28,
            child: Text(icon,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22))),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0F7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: (value / 100).clamp(0.0, 1.0),
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 押し込み式の大ボタン(CSS .bigbtn 相当)。
class _BigButton extends StatelessWidget {
  final String icon;
  final String label;
  final String sub;
  final List<Color> colors;
  final VoidCallback onTap;
  const _BigButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 26)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ふわふわ雲(装飾)。
class _Cloud extends StatelessWidget {
  final double width;
  const _Cloud({required this.width});

  @override
  Widget build(BuildContext context) {
    final h = width * 0.34;
    return Opacity(
      opacity: 0.8,
      child: SizedBox(
        width: width,
        height: h * 2.2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: width,
                height: h,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Positioned(
              bottom: h * 0.5,
              left: width * 0.17,
              child: _bump(width * 0.43),
            ),
            Positioned(
              bottom: h * 0.55,
              left: width * 0.51,
              child: _bump(width * 0.31),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bump(double d) => Container(
        width: d,
        height: d,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
}

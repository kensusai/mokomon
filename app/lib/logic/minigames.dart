/// ミニゲームの純ロジック(描画・入力は screens/ 側)。
/// パラメータは docs/game-design.md §5 とプロトタイプに一致させる。
library;

import 'dart:math';

import '../data/species.dart';

/// 正誤のあるゲーム(パズル/ちがうのどっち/じゅんばん/かぞえて/
/// どっちがおおい/けいさん/いろタッチ)共通:
/// これだけ間違えるとゲームオーバー(報酬なし)。コインを払えば続けられる。
const minigameMaxMistakes = 3;

/// コインで続行するときのコスト。
const minigameContinueCost = 5;

/// 正誤のあるゲーム共通のミス数管理(docs/review-findings.md #8)。
mixin MistakeTracker {
  var mistakes = 0;

  /// ミス回数の上限に達した(コインを払わない限りゲームオーバー)。
  bool get failed => mistakes >= minigameMaxMistakes;

  /// コインを払ってゲームオーバーから復帰する(ミス数をリセット)。
  void continueAfterFail() => mistakes = 0;
}

/// 採点式ラウンドゲーム(パズル/ちがうのどっち/かぞえて等)共通のラウンド進行
/// (docs/review-findings.md #26)。正誤判定だけを各ゲームが持つ。
mixin RoundGuessGame on MistakeTracker {
  var round = 0;
  var reward = 0;

  /// 総ラウンド数。
  int get rounds;

  /// 1ラウンド正解の報酬コイン。
  int get rewardPerRound;

  /// 選択肢 [index] を答える(各ゲームが実装)。正解なら true を返し
  /// 次ラウンドへ、不正解はミスを1つ増やす(docs/review-findings.md #66:
  /// 画面側の共通配線 RoundGuessScreenMixin がこの面だけを見る)。
  bool guess(int index);

  /// 次のラウンドを生成する(各ゲームが実装)。
  void _newRound();

  bool get finished => round >= rounds || failed;

  /// 共通の採点: 正解なら報酬とラウンドを進めて true。不正解はミス+1。
  bool _applyGuess(bool correct) {
    if (finished) return false;
    if (!correct) {
      mistakes++;
      return false;
    }
    reward += rewardPerRound;
    round++;
    if (!finished) _newRound();
    return true;
  }
}

/// 時間制ゲーム(フルーツキャッチ/もぐらたたき/ふうせんわり)共通の
/// 1秒カウントダウンと終盤加速(docs/review-findings.md #27)。
mixin CountdownGame {
  /// 制限時間(秒)。
  int get durationSec;

  /// 終盤の速度増分([speedFactor] が 1.0 → 1.0+accel まで上がる)。
  double get accel;

  late int timeLeft = durationSec;
  var _timerAcc = 0.0;

  bool get finished => timeLeft <= 0;

  /// 残り時間が減るほど速くなる。こどもFB「もっとむずかしく」。
  double get speedFactor => 1.0 + accel * (1 - timeLeft / durationSec);

  /// [dt] 秒ぶん時計を進める。時間切れになったら true を返す。
  bool tickClock(double dt) {
    _timerAcc += dt;
    if (_timerAcc >= 1) {
      _timerAcc -= 1;
      timeLeft--;
    }
    return finished;
  }

  var _spawnT = 0.0;

  /// スポーン期限の判定(docs/review-findings.md #56)。[dt] だけ進め、期限が
  /// 来ていて [allowed] なら次の間隔(base + rng×jitter を [speedFactor] で
  /// 短縮)を予約して true を返す。乱数は期限が来たときだけ消費する
  /// (シード付きテストの再現性を保つため)。
  bool spawnDue(
    double dt,
    Random rng, {
    required double base,
    required double jitter,
    bool allowed = true,
  }) {
    _spawnT -= dt;
    if (_spawnT > 0 || !allowed) return false;
    _spawnT = (base + rng.nextDouble() * jitter) / speedFactor;
    return true;
  }
}

// ---------- フルーツキャッチ ----------

const catchDurationSec = 30;
const catchTapRadius = 44.0;
const catchStarChance = 0.14;
const catchFruits = ['🍎', '🍊', '🍇', '🍓', '🍌'];

class CatchItem {
  double x;
  double y;
  final double vy;
  final String emoji;
  final bool star;
  double wobble;

  CatchItem({
    required this.x,
    required this.y,
    required this.vy,
    required this.emoji,
    required this.star,
    required this.wobble,
  });

  /// 描画用X(横揺れ込み)
  double get renderX => x + sin(wobble) * 6;
}

/// フルーツキャッチの状態機械。widget 側の Ticker から [update] を呼ぶ。
class CatchGame with CountdownGame {
  CatchGame({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  final items = <CatchItem>[];
  var score = 0;

  @override
  int get durationSec => catchDurationSec;

  /// 1.0 → 1.9 まで加速。
  @override
  double get accel => 0.9;

  /// [dt] 秒進める。範囲は画面サイズ [width]x[height]。
  void update(double dt, double width, double height) {
    if (finished || tickClock(dt)) return;
    if (spawnDue(dt, _rng, base: 0.45, jitter: 0.4)) {
      final star = _rng.nextDouble() < catchStarChance;
      items.add(
        CatchItem(
          x: 30 + _rng.nextDouble() * (width - 60),
          y: -40,
          vy: (120 + _rng.nextDouble() * 100) * speedFactor,
          emoji: star ? '⭐' : catchFruits[_rng.nextInt(catchFruits.length)],
          star: star,
          wobble: _rng.nextDouble() * 2 * pi,
        ),
      );
    }
    for (final it in items) {
      it.y += it.vy * dt;
      it.wobble += dt * 3;
    }
    items.removeWhere((it) => it.y >= height + 50);
  }

  /// タップ判定。当たったら得点(⭐+3 / フルーツ+1)して item を返す。
  CatchItem? tapAt(double x, double y) {
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      if (sqrt(pow(it.renderX - x, 2) + pow(it.y - y, 2)) < catchTapRadius) {
        score += it.star ? 3 : 1;
        items.removeAt(i);
        return it;
      }
    }
    return null;
  }
}

// ---------- おなじのどれ? ----------

enum PuzzleShape { circle, star, triangle, square, heart }

const puzzleColors = [
  0xFFFF6EA6,
  0xFFFFAB49,
  0xFF34C98E,
  0xFF54B9FF,
  0xFF9B8CFF,
];
const puzzleRounds = 8;
const puzzleRewardPerRound = 2;

class PuzzlePiece {
  final PuzzleShape shape;
  final int color;
  const PuzzlePiece(this.shape, this.color);

  @override
  bool operator ==(Object other) =>
      other is PuzzlePiece && other.shape == shape && other.color == color;

  @override
  int get hashCode => Object.hash(shape, color);
}

/// 「おなじのどれ?」8ラウンド・4択(難化)。不正解はミス+1、
/// 3ミスでゲームオーバー(コインで続行可)。docs/game-design.md §5。
class PuzzleGame with MistakeTracker, RoundGuessGame {
  PuzzleGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  late PuzzlePiece target;
  late List<PuzzlePiece> choices;

  @override
  int get rounds => puzzleRounds;
  @override
  int get rewardPerRound => puzzleRewardPerRound;

  PuzzlePiece _randomPiece() => PuzzlePiece(
    PuzzleShape.values[_rng.nextInt(PuzzleShape.values.length)],
    puzzleColors[_rng.nextInt(puzzleColors.length)],
  );

  @override
  void _newRound() {
    target = _randomPiece();
    final opts = <PuzzlePiece>[target];
    while (opts.length < 4) {
      final o = _randomPiece();
      if (!opts.contains(o)) opts.add(o);
    }
    opts.shuffle(_rng);
    choices = opts;
  }

  /// 正解なら true を返し次ラウンドへ。不正解はミスを1つ増やす。
  @override
  bool guess(int choiceIndex) => _applyGuess(choices[choiceIndex] == target);
}

// ---------- ペアさがし ----------

const memoryEmoji = ['🍎', '🍌', '🍇', '⭐', '🐟', '🌸', '🍩', '🐸', '🚗', '🌙'];
const memoryReward = 20;

enum MemoryFlipResult { first, matched, mismatched, ignored }

/// ペアさがし(4×5=10ペア)。widget 側は結果に応じて演出する。
class MemoryGame {
  MemoryGame({Random? rng}) {
    cards = [...memoryEmoji, ...memoryEmoji]..shuffle(rng ?? Random());
  }

  late final List<String> cards;
  final faceUp = <int>{};
  final matched = <int>{};
  int? _first;

  bool get finished => matched.length == cards.length;

  /// 不一致で伏せる2枚(演出後に widget が [hideMismatch] を呼ぶ)。
  (int, int)? pendingMismatch;

  MemoryFlipResult flip(int index) {
    if (pendingMismatch != null ||
        faceUp.contains(index) ||
        matched.contains(index)) {
      return MemoryFlipResult.ignored;
    }
    faceUp.add(index);
    if (_first == null) {
      _first = index;
      return MemoryFlipResult.first;
    }
    final a = _first!;
    _first = null;
    if (cards[a] == cards[index]) {
      matched.addAll([a, index]);
      faceUp.removeAll([a, index]);
      return MemoryFlipResult.matched;
    }
    pendingMismatch = (a, index);
    return MemoryFlipResult.mismatched;
  }

  void hideMismatch() {
    final p = pendingMismatch;
    if (p == null) return;
    faceUp.removeAll([p.$1, p.$2]);
    pendingMismatch = null;
  }
}

// ---------- もぐらたたき ----------

const whackDurationSec = 30;
const whackHoles = 9; // 3x3

/// 穴から顔を出すいきもの。golden=ぴか(+3)、stinky=💨(0コイン・おふざけ)。
class WhackMole {
  final int hole;
  final int speciesIndex;
  final bool golden;
  final bool stinky;
  double ttl;
  WhackMole({
    required this.hole,
    required this.speciesIndex,
    required this.golden,
    required this.stinky,
    required this.ttl,
  });
}

/// もぐらたたきの状態機械。widget 側の Ticker から [update] を呼ぶ。
class WhackGame with CountdownGame {
  WhackGame({Random? rng, int? speciesCount})
    : _rng = rng ?? Random(),
      _speciesCount = speciesCount ?? speciesList.length;

  final Random _rng;

  /// 出現させる種族の範囲(既定は speciesList 全体)。
  /// docs/review-findings.md #6: ハードコードせず種族数から取る。
  final int _speciesCount;
  final moles = <WhackMole>[];
  var score = 0;

  @override
  int get durationSec => whackDurationSec;

  /// 1.0 → 1.8 まで加速。
  @override
  double get accel => 0.8;

  void update(double dt) {
    if (finished) return;
    if (tickClock(dt)) {
      moles.clear();
      return;
    }
    for (final m in moles) {
      m.ttl -= dt;
    }
    moles.removeWhere((m) => m.ttl <= 0);

    if (spawnDue(dt, _rng, base: 0.5, jitter: 0.4, allowed: moles.length < 3)) {
      final used = moles.map((m) => m.hole).toSet();
      final free = [
        for (var i = 0; i < whackHoles; i++)
          if (!used.contains(i)) i,
      ];
      if (free.isNotEmpty) {
        final roll = _rng.nextDouble();
        moles.add(
          WhackMole(
            hole: free[_rng.nextInt(free.length)],
            speciesIndex: _rng.nextInt(_speciesCount),
            golden: roll < 0.12,
            stinky: roll >= 0.12 && roll < 0.22,
            ttl: (0.75 + _rng.nextDouble() * 0.45) / speedFactor,
          ),
        );
      }
    }
  }

  /// 穴をタップ。いきものがいれば得点して返す(ぴか+3/💨0/ふつう+1)。
  WhackMole? tapHole(int hole) {
    final i = moles.indexWhere((m) => m.hole == hole);
    if (i < 0) return null;
    final mole = moles.removeAt(i);
    score += mole.golden ? 3 : (mole.stinky ? 0 : 1);
    return mole;
  }
}

// ---------- ちがうのどっち? ----------

/// にている絵文字ペア(左が多数派、右が1つだけまざる)
const oddPairs = [
  ('🍎', '🍅'),
  ('😀', '😃'),
  ('🐱', '🐯'),
  ('⭐', '🌟'),
  ('🍦', '🍨'),
  ('🐶', '🐺'),
  ('🌸', '🌺'),
  ('🙂', '🙃'),
  ('😺', '😸'),
  ('🌕', '🌝'),
  ('🐥', '🐤'),
  ('🧸', '🐻'),
  ('🍪', '🥯'),
];
const oddRounds = 8;
const oddRewardPerRound = 2;

/// 「ちがうのどっち?」1つだけ違う絵文字を探す。ラウンドが進むと枚数が増える。
class OddOneGame with MistakeTracker, RoundGuessGame {
  OddOneGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  late List<String> cells;
  late int oddIndex;

  @override
  int get rounds => oddRounds;
  @override
  int get rewardPerRound => oddRewardPerRound;

  // こどもFBでさらに難化: 12 → 16 → 20 → 25枚
  int get _gridSize => switch (round) {
    < 2 => 12,
    < 4 => 16,
    < 6 => 20,
    _ => 25,
  };

  @override
  void _newRound() {
    final pair = oddPairs[_rng.nextInt(oddPairs.length)];
    final flip = _rng.nextBool();
    final common = flip ? pair.$2 : pair.$1;
    final odd = flip ? pair.$1 : pair.$2;
    cells = List.filled(_gridSize, common);
    oddIndex = _rng.nextInt(_gridSize);
    cells[oddIndex] = odd;
  }

  /// 正解なら true を返し次ラウンドへ。不正解はミスを1つ増やす。
  @override
  bool guess(int index) => _applyGuess(index == oddIndex);
}

// ---------- ふうせんわり ----------

const balloonDurationSec = 30;
const balloonTapRadius = 46.0;

class BalloonItem {
  double x;
  double y;
  final double vy; // 上昇速度(px/s)
  final String emoji;
  final bool golden;
  final bool bomb;
  double wobble;
  BalloonItem({
    required this.x,
    required this.y,
    required this.vy,
    required this.emoji,
    required this.golden,
    required this.bomb,
    required this.wobble,
  });

  double get renderX => x + sin(wobble) * 8;
}

/// ふうせんわり: 下からふわふわ上がる風船をタップ。💣は-2(0未満なし)。
class BalloonGame with CountdownGame {
  BalloonGame({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  final items = <BalloonItem>[];
  var score = 0;

  @override
  int get durationSec => balloonDurationSec;

  /// 1.0 → 1.8 まで加速。
  @override
  double get accel => 0.8;

  void update(double dt, double width, double height) {
    if (finished || tickClock(dt)) return;
    if (spawnDue(dt, _rng, base: 0.5, jitter: 0.45)) {
      final roll = _rng.nextDouble();
      final bomb = roll < 0.14; // 難化: 💣ちょっと増量
      final golden = !bomb && roll < 0.28;
      items.add(
        BalloonItem(
          x: 34 + _rng.nextDouble() * (width - 68),
          y: height + 40,
          vy: (95 + _rng.nextDouble() * 85) * speedFactor,
          emoji: bomb ? '💣' : (golden ? '⭐' : '🎈'),
          golden: golden,
          bomb: bomb,
          wobble: _rng.nextDouble() * 2 * pi,
        ),
      );
    }
    for (final it in items) {
      it.y -= it.vy * dt;
      it.wobble += dt * 2.4;
    }
    items.removeWhere((it) => it.y < -60);
  }

  BalloonItem? tapAt(double x, double y) {
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      if (sqrt(pow(it.renderX - x, 2) + pow(it.y - y, 2)) < balloonTapRadius) {
        score = max(0, score + (it.bomb ? -2 : (it.golden ? 3 : 1)));
        items.removeAt(i);
        return it;
      }
    }
    return null;
  }
}

// ---------- じゅんばんタッチ ----------

/// 1〜9をじゅんばんにタッチ。はやいほどコインが多い。
class OrderGame with MistakeTracker {
  OrderGame({Random? rng}) {
    cells = List.generate(9, (i) => i + 1)..shuffle(rng ?? Random());
  }

  late final List<int> cells;
  var next = 1;

  bool get finished => next > 9 || failed;

  /// 何秒で終えたかでコイン(はやい=16 / ふつう=10 / ゆっくり=6)。難化で基準タイム短縮。
  static int coinsForSeconds(double seconds) =>
      seconds < 11 ? 16 : (seconds < 20 ? 10 : 6);

  bool tap(int cellIndex) {
    if (finished) return false;
    if (cells[cellIndex] != next) {
      mistakes++;
      return false;
    }
    next++;
    return true;
  }
}

// ---------- かぞえてタッチ ----------

const countRounds = 6;
const countRewardPerRound = 3;

/// (かぞえる対象, まぎれもの2種)。似すぎない絵文字で6〜7歳向けに。
const countSets = [
  ('🐟', ['🐙', '🦀']),
  ('🦋', ['🐝', '🐞']),
  ('🍓', ['🍒', '🍎']),
  ('⭐', ['🌙', '☁️']),
  ('🐤', ['🐸', '🐰']),
  ('🎈', ['🎁', '🎀']),
];

/// 「かぞえてタッチ」: ちらばった絵文字から対象をかぞえて3択で答える。
/// ラウンドが進むほど個数が増えて難しくなる。
class CountGame with MistakeTracker, RoundGuessGame {
  CountGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  late String target;
  late List<String> items;
  late int answer;
  late List<int> choices;

  @override
  int get rounds => countRounds;
  @override
  int get rewardPerRound => countRewardPerRound;

  int get _itemCount => 9 + round * 3; // 9 → 24枚

  @override
  void _newRound() {
    final set = countSets[_rng.nextInt(countSets.length)];
    target = set.$1;
    answer = 2 + _rng.nextInt(min(7, _itemCount - 2)); // 2〜8こ
    items = [
      for (var i = 0; i < answer; i++) target,
      for (var i = answer; i < _itemCount; i++) set.$2[_rng.nextInt(2)],
    ]..shuffle(_rng);
    final base = answer - 1; // answer は最小2なので base >= 1
    choices = [base, base + 1, base + 2]..shuffle(_rng);
  }

  /// 正解なら true を返し次ラウンドへ。不正解はミスを1つ増やす(数えなおし可)。
  @override
  bool guess(int choiceIndex) => _applyGuess(choices[choiceIndex] == answer);
}

// ---------- おぼえてタッチ ----------

const simonPads = 4;
const simonMaxLen = 7;
const simonRewardPerRound = 3;

/// さかさまタッチ(reversed)は逆順入力のぶん短く・高報酬。
const reverseMaxLen = 6;
const reverseRewardPerRound = 4;

enum SimonInput { progress, roundComplete, gameComplete, wrong }

/// 「おぼえてタッチ」: 光ったじゅんばんを覚えてタッチ(サイモン)。
/// 2連から始まり、クリアごとに1つ伸びて最大7連。間違えたらそこで終了
/// (それまでのごほうびは持ち帰り)。
///
/// [reversed] は「さかさまタッチ」ルール: 光った順を**逆から**タッチする。
/// 逆順の記憶ははるかに難しいため最大6連、1ラウンド+4コイン。
class SimonGame {
  SimonGame({Random? rng, this.reversed = false}) : _rng = rng ?? Random() {
    sequence = [_rng.nextInt(simonPads), _rng.nextInt(simonPads)];
  }

  final Random _rng;
  final bool reversed;
  late final List<int> sequence;
  var _pos = 0;
  var reward = 0;
  var finished = false;

  int get _maxLen => reversed ? reverseMaxLen : simonMaxLen;
  int get _rewardPerRound =>
      reversed ? reverseRewardPerRound : simonRewardPerRound;

  SimonInput input(int pad) {
    if (finished) return SimonInput.wrong;
    final expected = reversed
        ? sequence[sequence.length - 1 - _pos]
        : sequence[_pos];
    if (pad != expected) {
      finished = true;
      return SimonInput.wrong;
    }
    _pos++;
    if (_pos < sequence.length) return SimonInput.progress;
    reward += _rewardPerRound;
    _pos = 0;
    if (sequence.length >= _maxLen) {
      finished = true;
      return SimonInput.gameComplete;
    }
    sequence.add(_rng.nextInt(simonPads));
    return SimonInput.roundComplete;
  }
}

// ---------- どっちがおおい? ----------

const compareRounds = 6;
const compareRewardPerRound = 3;
const compareEmoji = ['🍎', '⭐', '🐟', '🌸', '🍩', '🎈'];

/// 「どっちが おおい?」左右のむれを見くらべて多いほうをタッチ
/// (docs/game-design.md §5)。差は 3 → 2 → 1 個と縮んで難化する。
class CompareGame with MistakeTracker, RoundGuessGame {
  CompareGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  late String emoji;
  late int leftCount;
  late int rightCount;

  /// 多いほうの側(0=ひだり / 1=みぎ)。
  int get moreSide => leftCount > rightCount ? 0 : 1;

  @override
  int get rounds => compareRounds;
  @override
  int get rewardPerRound => compareRewardPerRound;

  @override
  void _newRound() {
    emoji = compareEmoji[_rng.nextInt(compareEmoji.length)];
    final gap = switch (round) {
      < 2 => 3,
      < 4 => 2,
      _ => 1,
    };
    final small = 2 + _rng.nextInt(4); // 2〜5個
    final leftIsBig = _rng.nextBool();
    leftCount = leftIsBig ? small + gap : small;
    rightCount = leftIsBig ? small : small + gap;
  }

  /// [side] 0=ひだり / 1=みぎ。正解なら true を返し次ラウンドへ。
  @override
  bool guess(int side) => _applyGuess(side == moreSide);
}

// ---------- ぴかっとタッチ ----------

const pikaRounds = 5;

/// 「ぴかっとタッチ」光った瞬間にタッチする反射ゲーム
/// (docs/game-design.md §5)。タイミング制御(いつ光らせるか)は画面側、
/// 採点とラウンド進行をここで持つ。
class PikaGame {
  PikaGame({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  var round = 0;
  var reward = 0;

  /// ラウンドごとの反応時間(ms)。フライングは null。
  final reactions = <int?>[];

  bool get finished => round >= pikaRounds;

  /// 次のラウンドで光るまでの待ち時間(0.9〜2.6秒)。
  int nextWaitMs() => 900 + _rng.nextInt(1701);

  /// 反応速度→コイン(0.4秒未満+3 / 0.8秒未満+2 / それ以降+1)。
  static int coinsFor(int reactionMs) =>
      reactionMs < 400 ? 3 : (reactionMs < 800 ? 2 : 1);

  /// 光ってからタッチできた。獲得コインを返しラウンドを進める。
  int hit(int reactionMs) {
    final c = coinsFor(reactionMs);
    reward += c;
    reactions.add(reactionMs);
    round++;
    return c;
  }

  /// フライング(光る前にタッチ)。そのラウンドは0コインで進める。
  void tooEarly() {
    reactions.add(null);
    round++;
  }
}

// ---------- けいさんタッチ ----------

const mathRounds = 6;
const mathRewardPerRound = 3;

/// 「けいさんタッチ」: たしざん・ひきざんの答えを3択から選ぶ。
/// たしざん(答え10まで)→ ひきざん → 11〜15のミックスと難化する
/// (docs/game-design.md §5)。3ミスでゲームオーバー(コインで続行可)。
class MathGame with MistakeTracker, RoundGuessGame {
  MathGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  late int a;
  late int b;
  late bool isAdd;
  late int answer;
  late List<int> choices;

  @override
  int get rounds => mathRounds;
  @override
  int get rewardPerRound => mathRewardPerRound;

  @override
  void _newRound() {
    if (round < 2) {
      // たしざん: 合計10まで
      isAdd = true;
      a = 1 + _rng.nextInt(8); // 1〜8
      b = 1 + _rng.nextInt(10 - a); // 合計 ≤10
    } else if (round < 4) {
      // ひきざん: 10までから引く(答えは1以上)
      isAdd = false;
      a = 5 + _rng.nextInt(6); // 5〜10
      b = 1 + _rng.nextInt(a - 1); // 1〜a-1
    } else {
      // ミックス: 11〜15の大きな数(1年生の「くり上がり・くり下がり」相当)
      isAdd = _rng.nextBool();
      if (isAdd) {
        final sum = 11 + _rng.nextInt(5); // 11〜15
        a = 2 + _rng.nextInt(8); // 2〜9
        b = sum - a;
      } else {
        a = 11 + _rng.nextInt(5); // 11〜15
        b = 2 + _rng.nextInt(8); // 2〜9
      }
    }
    answer = isAdd ? a + b : a - b;
    final base = answer - 1; // answer は最小1なので base >= 0
    choices = [base, base + 1, base + 2]..shuffle(_rng);
  }

  /// 正解なら true を返し次ラウンドへ。不正解はミスを1つ増やす。
  @override
  bool guess(int choiceIndex) => _applyGuess(choices[choiceIndex] == answer);
}

// ---------- ぴったりストップ ----------

const stopRounds = 5;

/// 「ぴったりストップ」: バーを走るマーカーをまとの上でタッチして止める。
/// ラウンドごとに速くなり、まとは小さくなる(docs/game-design.md §5)。
/// ぴったり+4 / まと内+2 / はずれ0でラウンドは進む(ミス制の対象外)。
/// タイミング制御は画面側、位置計算と採点をここで持つ。
class StopGame {
  StopGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  var round = 0;
  var reward = 0;

  /// まとの中心(バー上の 0〜1 座標)。ラウンドごとにランダム。
  late double zoneCenter;

  bool get finished => round >= stopRounds;

  /// マーカーの速さ(片道/秒)。0.55 → 1.35 と加速。
  double get speed => 0.55 + 0.2 * round;

  /// まとの半幅(バー座標)。0.13 → 0.058 と縮小。
  double get zoneHalf => 0.13 - 0.018 * round;

  void _newRound() => zoneCenter = 0.15 + _rng.nextDouble() * 0.7;

  /// 経過 [seconds] でのマーカー位置。0〜1を三角波で往復する。
  double positionAt(double seconds) {
    final p = (seconds * speed) % 2.0;
    return p < 1 ? p : 2 - p;
  }

  /// [pos] で止めた採点。まとの中心付近ぴったり+4 / まと内+2 / はずれ0。
  /// いずれもラウンドを進め、獲得コインを返す。
  int stopAt(double pos) {
    if (finished) return 0;
    final diff = (pos - zoneCenter).abs();
    final c = diff <= zoneHalf * 0.35 ? 4 : (diff <= zoneHalf ? 2 : 0);
    reward += c;
    round++;
    if (!finished) _newRound();
    return c;
  }
}

// ---------- いろタッチ ----------

const stroopRounds = 6;
const stroopRewardPerRound = 3;

/// いろタッチの (ことば, 表示色)。
const stroopColors = [
  ('あか', 0xFFE85B5B),
  ('あお', 0xFF54B9FF),
  ('きいろ', 0xFFFFC24B),
  ('みどり', 0xFF34C98E),
];

/// 「いろタッチ」(ストループ課題): 大きく出たことばの**いろ**をタッチ。
/// 最初の2問はことばと色が一致するならし、3問目からは必ず食い違う
/// (docs/game-design.md §5)。3ミスでゲームオーバー(コインで続行可)。
class StroopGame with MistakeTracker, RoundGuessGame {
  StroopGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;

  /// 表示することば([stroopColors] の添字)。
  late int wordIndex;

  /// ことばを塗る色 = 正解([stroopColors] の添字)。
  late int inkIndex;

  @override
  int get rounds => stroopRounds;
  @override
  int get rewardPerRound => stroopRewardPerRound;

  @override
  void _newRound() {
    wordIndex = _rng.nextInt(stroopColors.length);
    inkIndex = round < 2
        ? wordIndex
        : (wordIndex + 1 + _rng.nextInt(stroopColors.length - 1)) %
              stroopColors.length;
  }

  /// [colorIndex] のいろパッドをタッチ。正解なら true を返し次ラウンドへ。
  @override
  bool guess(int colorIndex) => _applyGuess(colorIndex == inkIndex);
}

// ---------- もじさがし ----------

const kanaFindRounds = 8;
const kanaFindRewardPerRound = 2;

/// にた字グループ(まちがえやすいひらがな)。後半のまぎれものに使う。
const kanaGroups = [
  ['わ', 'ね', 'れ'],
  ['ぬ', 'め', 'あ'],
  ['る', 'ろ'],
  ['き', 'さ', 'ち'],
  ['は', 'ほ'],
  ['い', 'り'],
  ['う', 'つ'],
  ['こ', 'に'],
];

/// 「もじさがし」: おだいのひらがなをグリッドから探してタッチ。
/// 最初はぜんぜん違う字にまぎれ、3ラウンド目からは**にた字だけ**が並ぶ。
/// 枚数も 8→20 と増える(docs/game-design.md §5)。3ミスでゲームオーバー。
class KanaFindGame with MistakeTracker, RoundGuessGame {
  KanaFindGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;

  /// 探すおだいの字。
  late String target;
  late List<String> cells;
  late int targetIndex;

  @override
  int get rounds => kanaFindRounds;
  @override
  int get rewardPerRound => kanaFindRewardPerRound;

  int get _gridSize => switch (round) {
    < 2 => 8,
    < 4 => 12,
    < 6 => 16,
    _ => 20,
  };

  @override
  void _newRound() {
    final group = kanaGroups[_rng.nextInt(kanaGroups.length)];
    target = group[_rng.nextInt(group.length)];
    final List<String> pool;
    if (round < 2) {
      // ならし: にた字グループの外からまぎれものを出す
      pool = [
        for (final g in kanaGroups)
          if (!identical(g, group)) ...g,
      ];
    } else {
      // ここから同グループのにた字だけ
      pool = [...group]..remove(target);
    }
    cells = List.generate(_gridSize, (_) => pool[_rng.nextInt(pool.length)]);
    targetIndex = _rng.nextInt(_gridSize);
    cells[targetIndex] = target;
  }

  /// 正解なら true を返し次ラウンドへ。不正解はミスを1つ増やす。
  @override
  bool guess(int index) => _applyGuess(index == targetIndex);
}

// ---------- ペアもじ ----------

const kataRounds = 8;
const kataRewardPerRound = 2;

/// (ひらがな, カタカナ)。1プレイで8組を重複なく出題する。
const kataPairs = [
  ('あ', 'ア'),
  ('い', 'イ'),
  ('う', 'ウ'),
  ('か', 'カ'),
  ('き', 'キ'),
  ('さ', 'サ'),
  ('し', 'シ'),
  ('す', 'ス'),
  ('つ', 'ツ'),
  ('と', 'ト'),
  ('な', 'ナ'),
  ('ぬ', 'ヌ'),
  ('ね', 'ネ'),
  ('ふ', 'フ'),
  ('へ', 'ヘ'),
  ('も', 'モ'),
  ('や', 'ヤ'),
  ('ら', 'ラ'),
  ('わ', 'ワ'),
  ('ん', 'ン'),
];

/// 「ペアもじ」: ひらがな↔カタカナの対応を4択で答える。
/// 前半4問はひらがな→カタカナ、後半4問はカタカナ→ひらがなに反転して難化
/// (docs/game-design.md §5)。3ミスでゲームオーバー(コインで続行可)。
class KataMatchGame with MistakeTracker, RoundGuessGame {
  KataMatchGame({Random? rng}) : _rng = rng ?? Random() {
    _deck = [...kataPairs]..shuffle(_rng);
    _newRound();
  }

  final Random _rng;
  late final List<(String, String)> _deck;
  late (String, String) _pair;
  late List<String> choices;

  /// 後半はカタカナを出題してひらがなを選ぶ。
  bool get showKata => round >= 4;

  /// 大きく表示する出題の字。
  String get prompt => showKata ? _pair.$2 : _pair.$1;

  /// 正解の選択肢。
  String get answer => showKata ? _pair.$1 : _pair.$2;

  @override
  int get rounds => kataRounds;
  @override
  int get rewardPerRound => kataRewardPerRound;

  @override
  void _newRound() {
    _pair = _deck[round];
    final opts = <String>[answer];
    while (opts.length < 4) {
      final p = _deck[_rng.nextInt(_deck.length)];
      final o = showKata ? p.$1 : p.$2;
      if (!opts.contains(o)) opts.add(o);
    }
    opts.shuffle(_rng);
    choices = opts;
  }

  /// 正解なら true を返し次ラウンドへ。不正解はミスを1つ増やす。
  @override
  bool guess(int choiceIndex) => _applyGuess(choices[choiceIndex] == answer);
}

// ---------- ことばづくり ----------

const wordRounds = 6;
const wordRewardPerRound = 3;

/// (えもじ, ことば)。2文字 → 3文字 → 4文字の3段階。
const wordSets2 = [
  ('🐶', 'いぬ'),
  ('🐱', 'ねこ'),
  ('🌊', 'うみ'),
  ('⭐', 'ほし'),
  ('🌸', 'はな'),
  ('🐻', 'くま'),
];
const wordSets3 = [
  ('🍎', 'りんご'),
  ('🍌', 'ばなな'),
  ('🍉', 'すいか'),
  ('🐟', 'さかな'),
  ('🥚', 'たまご'),
  ('🚗', 'くるま'),
];
const wordSets4 = [
  ('🍙', 'おにぎり'),
  ('🧦', 'くつした'),
  ('🌻', 'ひまわり'),
  ('✏️', 'えんぴつ'),
  ('🎈', 'ふうせん'),
  ('⚡', 'かみなり'),
];

/// ダミー文字の母集団(基本のひらがな)。
const _kanaAll = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん';

enum WordTap { progress, wordComplete, gameComplete, wrong, ignored }

/// 「ことばづくり」: えもじを見て、ことばの文字を順番にタッチして作る。
/// 2文字→3文字→4文字と伸び、同数のダミー文字がまざる
/// (docs/game-design.md §5)。3ミスでゲームオーバー(コインで続行可)。
class WordBuildGame with MistakeTracker {
  WordBuildGame({Random? rng}) : _rng = rng ?? Random() {
    _deck2 = [...wordSets2]..shuffle(_rng);
    _deck3 = [...wordSets3]..shuffle(_rng);
    _deck4 = [...wordSets4]..shuffle(_rng);
    _newRound();
  }

  final Random _rng;
  late final List<(String, String)> _deck2;
  late final List<(String, String)> _deck3;
  late final List<(String, String)> _deck4;

  var round = 0;
  var reward = 0;
  late String emoji;
  late String word;
  late List<String> cells;

  /// タッチ済みのセル。
  final used = <int>{};

  /// 次に必要な文字位置(`word[nextIndex]` が正解の字)。
  var nextIndex = 0;

  bool get finished => round >= wordRounds || failed;

  void _newRound() {
    final (e, w) = switch (round) {
      < 2 => _deck2[round],
      < 4 => _deck3[round - 2],
      _ => _deck4[round - 4],
    };
    emoji = e;
    word = w;
    final wordChars = w.split('');
    // ダミーはことばの文字を除いた基本かなから同数(重複なし)
    final pool = _kanaAll.split('')..removeWhere(wordChars.contains);
    pool.shuffle(_rng);
    cells = [...wordChars, ...pool.take(wordChars.length)]..shuffle(_rng);
    used.clear();
    nextIndex = 0;
  }

  /// [cellIndex] をタッチ。正しい字なら進み、ことばが完成したら報酬。
  /// ちがう字はミス+1(3ミスでゲームオーバー)。使用済みセルは無視。
  WordTap tap(int cellIndex) {
    if (finished || used.contains(cellIndex)) return WordTap.ignored;
    if (cells[cellIndex] != word[nextIndex]) {
      mistakes++;
      return WordTap.wrong;
    }
    used.add(cellIndex);
    nextIndex++;
    if (nextIndex < word.length) return WordTap.progress;
    reward += wordRewardPerRound;
    round++;
    if (round >= wordRounds) return WordTap.gameComplete;
    _newRound();
    return WordTap.wordComplete;
  }
}

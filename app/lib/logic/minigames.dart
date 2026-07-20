/// ミニゲームの純ロジック(描画・入力は screens/ 側)。
/// パラメータは docs/game-design.md §5 とプロトタイプに一致させる。
library;

import 'dart:math';

import '../data/species.dart';

/// 正誤のある4ゲーム(パズル/ちがうのどっち/じゅんばん/かぞえて)共通:
/// これだけ間違えるとゲームオーバー(報酬なし)。コインを払えば続けられる。
const minigameMaxMistakes = 3;

/// コインで続行するときのコスト。
const minigameContinueCost = 5;

/// 正誤のある4ゲーム共通のミス数管理(docs/review-findings.md #8)。
mixin MistakeTracker {
  var mistakes = 0;

  /// ミス回数の上限に達した(コインを払わない限りゲームオーバー)。
  bool get failed => mistakes >= minigameMaxMistakes;

  /// コインを払ってゲームオーバーから復帰する(ミス数をリセット)。
  void continueAfterFail() => mistakes = 0;
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
class CatchGame {
  CatchGame({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  final items = <CatchItem>[];
  var score = 0;
  var timeLeft = catchDurationSec;
  var _spawnT = 0.0;
  var _timerAcc = 0.0;

  bool get finished => timeLeft <= 0;

  /// 残り時間が減るほど速くなる(1.0 → 1.9)。こどもFB「もっとむずかしく」。
  double get speedFactor => 1.0 + 0.9 * (1 - timeLeft / catchDurationSec);

  /// [dt] 秒進める。範囲は画面サイズ [width]x[height]。
  void update(double dt, double width, double height) {
    if (finished) return;
    _timerAcc += dt;
    if (_timerAcc >= 1) {
      _timerAcc -= 1;
      timeLeft--;
      if (finished) return;
    }
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnT = (0.45 + _rng.nextDouble() * 0.4) / speedFactor;
      final star = _rng.nextDouble() < catchStarChance;
      items.add(CatchItem(
        x: 30 + _rng.nextDouble() * (width - 60),
        y: -40,
        vy: (120 + _rng.nextDouble() * 100) * speedFactor,
        emoji: star ? '⭐' : catchFruits[_rng.nextInt(catchFruits.length)],
        star: star,
        wobble: _rng.nextDouble() * 2 * pi,
      ));
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
  0xFF9B8CFF
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

/// 「おなじのどれ?」8ラウンド・4択(難化)。不正解ペナルティなし(再挑戦可)。
class PuzzleGame with MistakeTracker {
  PuzzleGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  var round = 0;
  var reward = 0;
  late PuzzlePiece target;
  late List<PuzzlePiece> choices;

  bool get finished => round >= puzzleRounds || failed;

  PuzzlePiece _randomPiece() => PuzzlePiece(
        PuzzleShape.values[_rng.nextInt(PuzzleShape.values.length)],
        puzzleColors[_rng.nextInt(puzzleColors.length)],
      );

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
  bool guess(int choiceIndex) {
    if (finished) return false;
    if (choices[choiceIndex] != target) {
      mistakes++;
      return false;
    }
    reward += puzzleRewardPerRound;
    round++;
    if (!finished) _newRound();
    return true;
  }
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
class WhackGame {
  WhackGame({Random? rng, int? speciesCount})
      : _rng = rng ?? Random(),
        _speciesCount = speciesCount ?? speciesList.length;

  final Random _rng;

  /// 出現させる種族の範囲(既定は speciesList 全体)。
  /// docs/review-findings.md #6: ハードコードせず種族数から取る。
  final int _speciesCount;
  final moles = <WhackMole>[];
  var score = 0;
  var timeLeft = whackDurationSec;
  var _spawnT = 0.0;
  var _timerAcc = 0.0;

  bool get finished => timeLeft <= 0;

  /// 終盤ほど速く(1.0 → 1.8)。こどもFB「もっとむずかしく」。
  double get speedFactor => 1.0 + 0.8 * (1 - timeLeft / whackDurationSec);

  void update(double dt) {
    if (finished) return;
    _timerAcc += dt;
    if (_timerAcc >= 1) {
      _timerAcc -= 1;
      timeLeft--;
      if (finished) {
        moles.clear();
        return;
      }
    }
    for (final m in moles) {
      m.ttl -= dt;
    }
    moles.removeWhere((m) => m.ttl <= 0);

    _spawnT -= dt;
    if (_spawnT <= 0 && moles.length < 3) {
      _spawnT = (0.5 + _rng.nextDouble() * 0.4) / speedFactor;
      final used = moles.map((m) => m.hole).toSet();
      final free = [
        for (var i = 0; i < whackHoles; i++)
          if (!used.contains(i)) i
      ];
      if (free.isNotEmpty) {
        final roll = _rng.nextDouble();
        moles.add(WhackMole(
          hole: free[_rng.nextInt(free.length)],
          speciesIndex: _rng.nextInt(_speciesCount),
          golden: roll < 0.12,
          stinky: roll >= 0.12 && roll < 0.22,
          ttl: (0.75 + _rng.nextDouble() * 0.45) / speedFactor,
        ));
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
class OddOneGame with MistakeTracker {
  OddOneGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  var round = 0;
  var reward = 0;
  late List<String> cells;
  late int oddIndex;

  bool get finished => round >= oddRounds || failed;

  // こどもFBでさらに難化: 12 → 16 → 20 → 25枚
  int get _gridSize =>
      switch (round) { < 2 => 12, < 4 => 16, < 6 => 20, _ => 25 };

  void _newRound() {
    final pair = oddPairs[_rng.nextInt(oddPairs.length)];
    final flip = _rng.nextBool();
    final common = flip ? pair.$2 : pair.$1;
    final odd = flip ? pair.$1 : pair.$2;
    cells = List.filled(_gridSize, common);
    oddIndex = _rng.nextInt(_gridSize);
    cells[oddIndex] = odd;
  }

  bool guess(int index) {
    if (finished) return false;
    if (index != oddIndex) {
      mistakes++;
      return false;
    }
    reward += oddRewardPerRound;
    round++;
    if (!finished) _newRound();
    return true;
  }
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
class BalloonGame {
  BalloonGame({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  final items = <BalloonItem>[];
  var score = 0;
  var timeLeft = balloonDurationSec;
  var _spawnT = 0.0;
  var _timerAcc = 0.0;

  bool get finished => timeLeft <= 0;

  /// 終盤ほど速く(1.0 → 1.8)。こどもFB「もっとむずかしく」。
  double get speedFactor => 1.0 + 0.8 * (1 - timeLeft / balloonDurationSec);

  void update(double dt, double width, double height) {
    if (finished) return;
    _timerAcc += dt;
    if (_timerAcc >= 1) {
      _timerAcc -= 1;
      timeLeft--;
      if (finished) return;
    }
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnT = (0.5 + _rng.nextDouble() * 0.45) / speedFactor;
      final roll = _rng.nextDouble();
      final bomb = roll < 0.14; // 難化: 💣ちょっと増量
      final golden = !bomb && roll < 0.28;
      items.add(BalloonItem(
        x: 34 + _rng.nextDouble() * (width - 68),
        y: height + 40,
        vy: (95 + _rng.nextDouble() * 85) * speedFactor,
        emoji: bomb ? '💣' : (golden ? '⭐' : '🎈'),
        golden: golden,
        bomb: bomb,
        wobble: _rng.nextDouble() * 2 * pi,
      ));
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
class CountGame with MistakeTracker {
  CountGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  var round = 0;
  var reward = 0;
  late String target;
  late List<String> items;
  late int answer;
  late List<int> choices;

  bool get finished => round >= countRounds || failed;

  int get _itemCount => 9 + round * 3; // 9 → 24枚

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
  bool guess(int choiceIndex) {
    if (finished) return false;
    if (choices[choiceIndex] != answer) {
      mistakes++;
      return false;
    }
    reward += countRewardPerRound;
    round++;
    if (!finished) _newRound();
    return true;
  }
}

// ---------- おぼえてタッチ ----------

const simonPads = 4;
const simonMaxLen = 7;
const simonRewardPerRound = 3;

enum SimonInput { progress, roundComplete, gameComplete, wrong }

/// 「おぼえてタッチ」: 光ったじゅんばんを覚えてタッチ(サイモン)。
/// 2連から始まり、クリアごとに1つ伸びて最大7連。間違えたらそこで終了
/// (それまでのごほうびは持ち帰り)。
class SimonGame {
  SimonGame({Random? rng}) : _rng = rng ?? Random() {
    sequence = [_rng.nextInt(simonPads), _rng.nextInt(simonPads)];
  }

  final Random _rng;
  late final List<int> sequence;
  var _pos = 0;
  var reward = 0;
  var finished = false;

  SimonInput input(int pad) {
    if (finished) return SimonInput.wrong;
    if (pad != sequence[_pos]) {
      finished = true;
      return SimonInput.wrong;
    }
    _pos++;
    if (_pos < sequence.length) return SimonInput.progress;
    reward += simonRewardPerRound;
    _pos = 0;
    if (sequence.length >= simonMaxLen) {
      finished = true;
      return SimonInput.gameComplete;
    }
    sequence.add(_rng.nextInt(simonPads));
    return SimonInput.roundComplete;
  }
}

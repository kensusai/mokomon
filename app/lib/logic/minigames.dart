/// ミニゲームの純ロジック(描画・入力は screens/ 側)。
/// パラメータは docs/game-design.md §5 とプロトタイプに一致させる。
library;

import 'dart:math';

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
      _spawnT = 0.55 + _rng.nextDouble() * 0.5;
      final star = _rng.nextDouble() < catchStarChance;
      items.add(CatchItem(
        x: 30 + _rng.nextDouble() * (width - 60),
        y: -40,
        vy: 90 + _rng.nextDouble() * 70,
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

/// 「おなじのどれ?」8ラウンド。不正解ペナルティなし(再挑戦可)。
class PuzzleGame {
  PuzzleGame({Random? rng}) : _rng = rng ?? Random() {
    _newRound();
  }

  final Random _rng;
  var round = 0;
  var reward = 0;
  late PuzzlePiece target;
  late List<PuzzlePiece> choices;

  bool get finished => round >= puzzleRounds;

  PuzzlePiece _randomPiece() => PuzzlePiece(
        PuzzleShape.values[_rng.nextInt(PuzzleShape.values.length)],
        puzzleColors[_rng.nextInt(puzzleColors.length)],
      );

  void _newRound() {
    target = _randomPiece();
    final opts = <PuzzlePiece>[target];
    while (opts.length < 3) {
      final o = _randomPiece();
      if (!opts.contains(o)) opts.add(o);
    }
    opts.shuffle(_rng);
    choices = opts;
  }

  /// 正解なら true を返し次ラウンドへ。不正解は何も変えない。
  bool guess(int choiceIndex) {
    if (finished) return false;
    if (choices[choiceIndex] != target) return false;
    reward += puzzleRewardPerRound;
    round++;
    if (!finished) _newRound();
    return true;
  }
}

// ---------- ペアさがし ----------

const memoryEmoji = ['🍎', '🍌', '🍇', '⭐', '🐟', '🌸'];
const memoryReward = 12;

enum MemoryFlipResult { first, matched, mismatched, ignored }

/// ペアさがし(3×4=6ペア)。widget 側は結果に応じて演出する。
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

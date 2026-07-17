import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/logic/trace_game.dart';

void main() {
  group('WhackGame (もぐらたたき)', () {
    test('spawns up to 3 moles in distinct holes and expires them', () {
      final g = WhackGame(rng: Random(1));
      for (var i = 0; i < 60; i++) {
        g.update(0.05); // 3秒
        expect(g.moles.length, lessThanOrEqualTo(3));
        final holes = g.moles.map((m) => m.hole).toList();
        expect(holes.toSet().length, holes.length); // 穴はかぶらない
      }
      expect(g.timeLeft, 27);
    });

    test('tapping scores by mole type', () {
      final g = WhackGame(rng: Random(1));
      g.moles.addAll([
        WhackMole(
            hole: 0, speciesIndex: 0, golden: false, stinky: false, ttl: 5),
        WhackMole(
            hole: 1, speciesIndex: 3, golden: true, stinky: false, ttl: 5),
        WhackMole(
            hole: 2, speciesIndex: 5, golden: false, stinky: true, ttl: 5),
      ]);
      expect(g.tapHole(0)!.golden, isFalse);
      expect(g.score, 1);
      expect(g.tapHole(1)!.golden, isTrue);
      expect(g.score, 4); // +3
      expect(g.tapHole(2)!.stinky, isTrue);
      expect(g.score, 4); // 💨は0点
      expect(g.tapHole(5), isNull);
    });

    test('accelerates as time runs out', () {
      final g = WhackGame(rng: Random(1));
      expect(g.speedFactor, 1.0);
      g.timeLeft = 1;
      expect(g.speedFactor, closeTo(1.48, 0.03));
    });
  });

  group('OddOneGame (ちがうのどっち?)', () {
    test('each round has exactly one odd cell from a lookalike pair', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = OddOneGame(rng: Random(seed));
        final odd = g.cells[g.oddIndex];
        final others = [...g.cells]..removeAt(g.oddIndex);
        expect(others.toSet(), hasLength(1)); // 多数派は全部同じ
        expect(odd, isNot(others.first));
      }
    });

    test('grid grows 9 → 12 → 16 → 20 and pays +2 per correct', () {
      final g = OddOneGame(rng: Random(4));
      final sizes = <int>[];
      while (!g.finished) {
        sizes.add(g.cells.length);
        expect(g.guess(g.oddIndex), isTrue);
      }
      expect(sizes, [9, 9, 12, 12, 16, 16, 20, 20]);
      expect(g.reward, 16);
    });

    test('wrong guesses do not advance', () {
      final g = OddOneGame(rng: Random(4));
      final wrong = (g.oddIndex + 1) % g.cells.length;
      expect(g.guess(wrong), isFalse);
      expect(g.round, 0);
    });
  });

  group('TraceGame (なぞってかこう)', () {
    test('targets are sampled along every shape', () {
      for (final key in traceShapeKeys) {
        final t = traceTargets(key);
        expect(t.length, greaterThanOrEqualTo(26), reason: key);
      }
    });

    test('coverage: tracing the shape scores high, scribble scores low', () {
      final targets = traceTargets('circle');
      // 完璧になぞった(ターゲットそのもの)
      expect(traceCoverage(targets, targets), 1.0);
      // 中央にぐちゃぐちゃ描いただけ
      final scribble = [
        for (var i = 0; i < 50; i++) Offset(140 + i % 10.0, 145 + i % 7.0)
      ];
      expect(traceCoverage(targets, scribble), lessThan(0.3));
    });

    test('score thresholds', () {
      expect(traceScore(0.9), (3, 4));
      expect(traceScore(0.6), (2, 3));
      expect(traceScore(0.2), (1, 1));
    });
  });

  group('BalloonGame (ふうせんわり)', () {
    test('balloons rise, bombs subtract but never below zero', () {
      final g = BalloonGame(rng: Random(2));
      g.items.add(BalloonItem(
          x: 100,
          y: 300,
          vy: 0,
          emoji: '💣',
          golden: false,
          bomb: true,
          wobble: 0));
      expect(g.tapAt(100, 300)!.bomb, isTrue);
      expect(g.score, 0); // 0未満にならない
      g.items.add(BalloonItem(
          x: 100,
          y: 300,
          vy: 0,
          emoji: '⭐',
          golden: true,
          bomb: false,
          wobble: 0));
      g.tapAt(100, 300);
      expect(g.score, 3);
    });

    test('items rise and despawn above the top', () {
      final g = BalloonGame(rng: Random(2));
      for (var i = 0; i < 100; i++) {
        g.update(0.05, 400, 600); // 5秒
      }
      expect(g.timeLeft, 25);
      expect(g.items.every((it) => it.y > -60), isTrue);
    });
  });

  group('OrderGame (じゅんばんタッチ)', () {
    test('must tap 1..9 in order', () {
      final g = OrderGame(rng: Random(3));
      expect(g.cells.toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9});
      final wrong = g.cells.indexOf(5);
      expect(g.tap(wrong), isFalse); // まだ1
      for (var n = 1; n <= 9; n++) {
        expect(g.tap(g.cells.indexOf(n)), isTrue);
      }
      expect(g.finished, isTrue);
    });

    test('coins scale with speed', () {
      expect(OrderGame.coinsForSeconds(10), 16);
      expect(OrderGame.coinsForSeconds(18), 10);
      expect(OrderGame.coinsForSeconds(30), 6);
    });
  });
}

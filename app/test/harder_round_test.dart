import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/foods.dart';
import 'package:mokomon/logic/minigames.dart';

/// こどもFB「もう2個ずつ+全体的にむずかしく」ラウンド。
/// ごはん10種・あそぶ10種・各ゲームの難易度パラメータを固定する。
void main() {
  group('10 foods (docs/game-design.md §3)', () {
    test('two new foods appended after pizza', () {
      expect(foods, hasLength(12));
      expect(foods.map((f) => f.key).toList().sublist(8), [
        'burger',
        'ice',
        'sushi',
        'pudding',
      ]);
    });
  });

  group('harder difficulty (docs/game-design.md §5)', () {
    test('catch accelerates up to 1.9x', () {
      final g = CatchGame(rng: Random(1));
      expect(g.speedFactor, 1.0);
      g.timeLeft = 0;
      expect(g.speedFactor, closeTo(1.9, 0.001));
    });

    test('whack accelerates up to 1.8x', () {
      final g = WhackGame(rng: Random(1));
      expect(g.speedFactor, 1.0);
      g.timeLeft = 0;
      expect(g.speedFactor, closeTo(1.8, 0.001));
    });

    test('balloon accelerates up to 1.8x', () {
      final g = BalloonGame(rng: Random(1));
      expect(g.speedFactor, 1.0);
      g.timeLeft = 0;
      expect(g.speedFactor, closeTo(1.8, 0.001));
    });

    test('puzzle now offers 4 unique choices', () {
      for (var seed = 0; seed < 10; seed++) {
        final g = PuzzleGame(rng: Random(seed));
        expect(g.choices, hasLength(4));
        expect(g.choices.toSet(), hasLength(4));
        expect(g.choices, contains(g.target));
      }
    });

    test('odd-one grid grows 12 → 16 → 20 → 25', () {
      final g = OddOneGame(rng: Random(4));
      final sizes = <int>[];
      while (!g.finished) {
        sizes.add(g.cells.length);
        expect(g.guess(g.oddIndex), isTrue);
      }
      expect(sizes, [12, 12, 16, 16, 20, 20, 25, 25]);
    });

    test('order-touch demands more speed for the top coin tiers', () {
      expect(OrderGame.coinsForSeconds(10), 16);
      expect(OrderGame.coinsForSeconds(12), 10);
      expect(OrderGame.coinsForSeconds(21), 6);
    });
  });

  group('CountGame (かぞえてタッチ)', () {
    test('each round scatters the target among distractors', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = CountGame(rng: Random(seed));
        final actual = g.items.where((e) => e == g.target).length;
        expect(actual, g.answer);
        expect(actual, greaterThanOrEqualTo(2));
        expect(g.items.length, greaterThan(actual)); // まぎれものがいる
      }
    });

    test('choices contain the answer among 3 unique positive counts', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = CountGame(rng: Random(seed));
        expect(g.choices, hasLength(3));
        expect(g.choices.toSet(), hasLength(3));
        expect(g.choices, contains(g.answer));
        expect(g.choices.every((c) => c >= 1), isTrue);
      }
    });

    test('rounds grow in size and pay +3 each, 6 rounds total', () {
      final g = CountGame(rng: Random(2));
      final sizes = <int>[];
      while (!g.finished) {
        sizes.add(g.items.length);
        expect(g.guess(g.choices.indexOf(g.answer)), isTrue);
      }
      expect(sizes, hasLength(countRounds));
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThan(sizes[i - 1]));
      }
      expect(g.reward, countRounds * countRewardPerRound);
    });

    test('wrong choice does not advance', () {
      final g = CountGame(rng: Random(2));
      final wrong = g.choices.indexWhere((c) => c != g.answer);
      expect(g.guess(wrong), isFalse);
      expect(g.round, 0);
      expect(g.reward, 0);
    });
  });

  group('SimonGame (おぼえてタッチ)', () {
    test('starts with 2 flashes and grows by 1 per cleared round', () {
      final g = SimonGame(rng: Random(1));
      expect(g.sequence, hasLength(2));
      for (var i = 0; i < g.sequence.length - 1; i++) {
        expect(g.input(g.sequence[i]), SimonInput.progress);
      }
      expect(g.input(g.sequence.last), SimonInput.roundComplete);
      expect(g.sequence, hasLength(3));
      expect(g.reward, simonRewardPerRound);
    });

    test('a wrong pad ends the game but keeps earned reward', () {
      final g = SimonGame(rng: Random(1));
      for (var i = 0; i < g.sequence.length - 1; i++) {
        g.input(g.sequence[i]);
      }
      g.input(g.sequence.last); // round 1 clear
      final wrongPad = (g.sequence[0] + 1) % simonPads;
      expect(g.input(wrongPad), SimonInput.wrong);
      expect(g.finished, isTrue);
      expect(g.reward, simonRewardPerRound);
    });

    test('clearing the max-length sequence completes the game', () {
      final g = SimonGame(rng: Random(3));
      var guard = 0;
      while (!g.finished && guard++ < 100) {
        for (var i = 0; i < g.sequence.length - 1; i++) {
          expect(g.input(g.sequence[i]), SimonInput.progress);
        }
        final r = g.input(g.sequence.last);
        expect(r, anyOf(SimonInput.roundComplete, SimonInput.gameComplete));
        if (r == SimonInput.gameComplete) break;
      }
      expect(g.finished, isTrue);
      expect(g.sequence, hasLength(simonMaxLen));
      expect(g.reward, (simonMaxLen - 1) * simonRewardPerRound);
    });
  });
}

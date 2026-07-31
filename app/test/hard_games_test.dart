import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';

/// 高難度ミニゲーム4種のロジック(docs/game-design.md §5)。
void main() {
  group('MathGame', () {
    test('rounds follow the difficulty schedule for many seeds', () {
      for (var seed = 0; seed < 50; seed++) {
        final g = MathGame(rng: Random(seed));
        while (!g.finished) {
          final round = g.round;
          // 出題と答えの整合
          expect(g.answer, g.isAdd ? g.a + g.b : g.a - g.b);
          expect(g.choices, contains(g.answer));
          expect(g.choices.toSet().length, 3, reason: '3択は重複しない');
          expect(g.choices.every((n) => n >= 0), isTrue);
          // 難易度スケジュール: たしざん(〜10) → ひきざん → ミックス(11〜15)
          if (round < 2) {
            expect(g.isAdd, isTrue);
            expect(g.a + g.b, lessThanOrEqualTo(10));
          } else if (round < 4) {
            expect(g.isAdd, isFalse);
            expect(g.a, lessThanOrEqualTo(10));
          } else {
            expect(g.isAdd ? g.a + g.b : g.a, inInclusiveRange(11, 15));
          }
          expect(g.answer, greaterThanOrEqualTo(1));
          expect(g.guess(g.choices.indexOf(g.answer)), isTrue);
        }
        expect(g.reward, mathRounds * mathRewardPerRound);
      }
    });

    test('wrong answers count mistakes and 3 fail the game', () {
      final g = MathGame(rng: Random(1));
      final wrong = g.choices.indexWhere((n) => n != g.answer);
      expect(g.guess(wrong), isFalse);
      expect(g.mistakes, 1);
      expect(g.round, 0, reason: '不正解では進まない');
      g.guess(wrong);
      g.guess(wrong);
      expect(g.failed, isTrue);
      expect(g.finished, isTrue);
      g.continueAfterFail();
      expect(g.failed, isFalse);
    });
  });

  group('SimonGame(reversed)', () {
    test('reversed input clears the round and pays more', () {
      final g = SimonGame(rng: Random(3), reversed: true);
      final seq = [...g.sequence];
      expect(g.input(seq[1]), SimonInput.progress);
      expect(g.input(seq[0]), SimonInput.roundComplete);
      expect(g.reward, reverseRewardPerRound);
      expect(g.sequence.length, 3);
    });

    test('forward input is wrong when ends differ', () {
      // 先頭と末尾が同じだと順方向でも正解になるのでシードで固定する
      final g = SimonGame(rng: Random(0), reversed: true);
      expect(g.sequence.first == g.sequence.last, isFalse);
      expect(g.input(g.sequence.first), SimonInput.wrong);
      expect(g.finished, isTrue);
      expect(g.reward, 0, reason: 'ミスまでの獲得分だけ持ち帰る');
    });

    test('completes at length 6 with 20 coins', () {
      final g = SimonGame(rng: Random(3), reversed: true);
      var last = SimonInput.progress;
      while (!g.finished) {
        for (final pad in g.sequence.reversed.toList()) {
          last = g.input(pad);
        }
      }
      expect(last, SimonInput.gameComplete);
      expect(g.sequence.length, reverseMaxLen);
      // 2〜6連 = 5ラウンド × 4コイン
      expect(g.reward, 20);
    });
  });

  group('StopGame', () {
    test('gets faster and the target zone shrinks each round', () {
      final g = StopGame(rng: Random(5));
      final speeds = <double>[];
      final zones = <double>[];
      while (!g.finished) {
        speeds.add(g.speed);
        zones.add(g.zoneHalf);
        expect(g.zoneCenter, inInclusiveRange(0.15, 0.85));
        g.stopAt(g.zoneCenter); // ど真ん中 = ぴったり
      }
      for (var i = 1; i < speeds.length; i++) {
        expect(speeds[i], greaterThan(speeds[i - 1]));
        expect(zones[i], lessThan(zones[i - 1]));
      }
      expect(g.reward, stopRounds * 4, reason: '全ラウンドぴったりで最大20');
    });

    test('positionAt sweeps back and forth within 0..1', () {
      final g = StopGame(rng: Random(5));
      final half = 0.5 / g.speed; // 半周の秒数
      expect(g.positionAt(0), 0);
      expect(g.positionAt(half), closeTo(0.5, 1e-9));
      expect(g.positionAt(half * 2), closeTo(1.0, 1e-9));
      expect(g.positionAt(half * 3), closeTo(0.5, 1e-9), reason: '折り返す');
      for (var t = 0.0; t < 10; t += 0.13) {
        expect(g.positionAt(t), inInclusiveRange(0.0, 1.0));
      }
    });

    test('scores pitari > zone-in > miss, and a miss still advances', () {
      final g = StopGame(rng: Random(7));
      expect(g.stopAt(g.zoneCenter), 4);
      expect(g.stopAt(g.zoneCenter + g.zoneHalf * 0.9), 2);
      final before = g.round;
      expect(g.stopAt(g.zoneCenter + g.zoneHalf * 3), 0);
      expect(g.round, before + 1, reason: 'ミスでも0コインでラウンドが進む');
      expect(g.reward, 6);
    });
  });

  group('StroopGame', () {
    test('warm-up rounds match, later rounds mismatch', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = StroopGame(rng: Random(seed));
        while (!g.finished) {
          expect(g.wordIndex, inInclusiveRange(0, stroopColors.length - 1));
          expect(g.inkIndex, inInclusiveRange(0, stroopColors.length - 1));
          if (g.round < 2) {
            expect(g.wordIndex, g.inkIndex, reason: '最初の2問はならし');
          } else {
            expect(g.wordIndex, isNot(g.inkIndex), reason: 'ここからワナ');
          }
          expect(g.guess(g.inkIndex), isTrue);
        }
        expect(g.reward, stroopRounds * stroopRewardPerRound);
      }
    });

    test('tapping the word (not the ink) is the trap and a mistake', () {
      final g = StroopGame(rng: Random(2));
      // ならし2問を消化してワナのある問題まで進める
      g.guess(g.inkIndex);
      g.guess(g.inkIndex);
      expect(g.guess(g.wordIndex), isFalse);
      expect(g.mistakes, 1);
      g.guess(g.wordIndex);
      g.guess(g.wordIndex);
      expect(g.failed, isTrue);
      g.continueAfterFail();
      expect(g.failed, isFalse);
    });
  });
}

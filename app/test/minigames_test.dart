import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('shared minigame reward (docs/game-design.md §5)', () {
    test('adds coins, happy +12 (clamped), xp +10', () {
      final c = GameController(
        GameState()
          ..stage = 1
          ..happy = 95,
        SaveStore(),
      );
      c.finishMinigame(7);
      expect(c.state.coins, 17);
      expect(c.state.happy, 100);
      expect(c.state.xp, 10);
    });
  });

  group('CatchGame', () {
    test('spawns items over time and counts down from 30', () {
      final g = CatchGame(rng: Random(1));
      expect(g.timeLeft, 30);
      for (var i = 0; i < 100; i++) {
        g.update(0.05, 400, 600); // 5秒
      }
      expect(g.timeLeft, 25);
      expect(g.items, isNotEmpty);
      // 落下速度は 120〜220px/s × 加速係数(最大1.9)
      for (final it in g.items) {
        expect(it.vy, inInclusiveRange(120, 360));
      }
    });

    test('items spawn faster and fall faster as time runs out', () {
      final early = CatchGame(rng: Random(1));
      expect(early.speedFactor, 1.0);
      early.timeLeft = 1;
      expect(early.speedFactor, closeTo(1.87, 0.03));
    });

    test('tap within 44px scores 1 for fruit and 3 for star', () {
      final g = CatchGame(rng: Random(1));
      g.items.add(
        CatchItem(x: 100, y: 100, vy: 100, emoji: '🍎', star: false, wobble: 0),
      );
      g.items.add(
        CatchItem(x: 300, y: 300, vy: 100, emoji: '⭐', star: true, wobble: 0),
      );
      expect(g.tapAt(100 + 43, 100), isNotNull);
      expect(g.score, 1);
      expect(g.tapAt(300, 300), isNotNull);
      expect(g.score, 4);
      expect(g.tapAt(0, 0), isNull);
      expect(g.items, isEmpty);
    });

    test('items falling past the bottom are removed', () {
      final g = CatchGame(rng: Random(1));
      g.items.add(
        CatchItem(
          x: 100,
          y: 590,
          vy: 10000,
          emoji: '🍎',
          star: false,
          wobble: 0,
        ),
      );
      g.update(0.05, 400, 600);
      expect(g.items.where((i) => i.y > 650), isEmpty);
    });

    test('finishes when time runs out and stops updating', () {
      final g = CatchGame(rng: Random(1));
      for (var i = 0; i < 700; i++) {
        g.update(0.05, 400, 600); // 35秒
      }
      expect(g.finished, isTrue);
      expect(g.timeLeft, 0);
    });
  });

  group('PuzzleGame', () {
    test('always includes the target among 4 unique choices', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = PuzzleGame(rng: Random(seed));
        expect(g.choices, hasLength(4));
        expect(g.choices.toSet(), hasLength(4));
        expect(g.choices, contains(g.target));
      }
    });

    test('correct answers advance 8 rounds and pay +2 each', () {
      final g = PuzzleGame(rng: Random(5));
      var corrects = 0;
      while (!g.finished) {
        final idx = g.choices.indexOf(g.target);
        expect(g.guess(idx), isTrue);
        corrects++;
      }
      expect(corrects, puzzleRounds);
      expect(g.reward, 16);
    });

    test('wrong answers do not advance and cost nothing', () {
      final g = PuzzleGame(rng: Random(5));
      final wrongIdx = g.choices.indexWhere((piece) => piece != g.target);
      expect(g.guess(wrongIdx), isFalse);
      expect(g.round, 0);
      expect(g.reward, 0);
    });
  });

  group('MemoryGame', () {
    test('deck is 10 pairs shuffled (4x5)', () {
      final g = MemoryGame(rng: Random(3));
      expect(memoryEmoji, hasLength(10));
      expect(g.cards, hasLength(20));
      for (final e in memoryEmoji) {
        expect(g.cards.where((c) => c == e), hasLength(2));
      }
    });

    test('matching pair stays revealed; mismatch hides after callback', () {
      final g = MemoryGame(rng: Random(3));
      final first = g.cards[0];
      final matchIdx = g.cards.lastIndexOf(first);

      expect(g.flip(0), MemoryFlipResult.first);
      expect(g.flip(matchIdx), MemoryFlipResult.matched);
      expect(g.matched, containsAll([0, matchIdx]));

      // 不一致ペアを探す
      final remaining = [
        for (var i = 0; i < 12; i++)
          if (!g.matched.contains(i)) i,
      ];
      final a = remaining[0];
      final b = remaining.firstWhere((i) => g.cards[i] != g.cards[a]);
      expect(g.flip(a), MemoryFlipResult.first);
      expect(g.flip(b), MemoryFlipResult.mismatched);
      // 演出中は他のカードをめくれない
      expect(g.flip(remaining[1]), MemoryFlipResult.ignored);
      g.hideMismatch();
      expect(g.faceUp, isEmpty);
    });

    test('finishes when all 10 pairs are found', () {
      final g = MemoryGame(rng: Random(3));
      for (final e in memoryEmoji) {
        final i = g.cards.indexOf(e);
        final j = g.cards.lastIndexOf(e);
        g.flip(i);
        g.flip(j);
      }
      expect(g.finished, isTrue);
    });
  });

  group('CompareGame どっちがおおい? (docs/game-design.md §5)', () {
    test('6 rounds, correct side advances with +3, wrong adds a mistake', () {
      final g = CompareGame(rng: Random(1));
      expect(g.leftCount, isNot(g.rightCount));
      final wrong = g.moreSide == 0 ? 1 : 0;
      expect(g.guess(wrong), isFalse);
      expect(g.mistakes, 1);
      expect(g.round, 0);
      expect(g.guess(g.moreSide), isTrue);
      expect(g.round, 1);
      expect(g.reward, compareRewardPerRound);
    });

    test('difficulty: the count gap shrinks 3 -> 2 -> 1', () {
      final g = CompareGame(rng: Random(2));
      final gaps = <int>[];
      while (!g.finished) {
        gaps.add((g.leftCount - g.rightCount).abs());
        g.guess(g.moreSide);
      }
      expect(gaps.sublist(0, 2), everyElement(3));
      expect(gaps.sublist(2, 4), everyElement(2));
      expect(gaps.sublist(4), everyElement(1));
    });

    test('3 mistakes end the game via MistakeTracker', () {
      final g = CompareGame(rng: Random(3));
      final wrong = g.moreSide == 0 ? 1 : 0;
      for (var i = 0; i < minigameMaxMistakes; i++) {
        g.guess(wrong);
      }
      expect(g.failed, isTrue);
      expect(g.finished, isTrue);
    });
  });

  group('PikaGame ぴかっとタッチ (docs/game-design.md §5)', () {
    test('scores by reaction speed and finishes after 5 rounds', () {
      final g = PikaGame(rng: Random(1));
      expect(PikaGame.coinsFor(399), 3);
      expect(PikaGame.coinsFor(400), 2);
      expect(PikaGame.coinsFor(799), 2);
      expect(PikaGame.coinsFor(800), 1);

      expect(g.hit(200), 3);
      g.tooEarly(); // フライングは0点でラウンドが進む
      g.hit(600);
      g.hit(900);
      expect(g.finished, isFalse);
      g.hit(100);
      expect(g.finished, isTrue);
      expect(g.reward, 3 + 0 + 2 + 1 + 3);
      expect(g.reactions, [200, null, 600, 900, 100]);
    });

    test('wait times stay within 0.9-2.6s', () {
      final g = PikaGame(rng: Random(4));
      for (var i = 0; i < 50; i++) {
        final w = g.nextWaitMs();
        expect(w, inInclusiveRange(900, 2600));
      }
    });
  });
}

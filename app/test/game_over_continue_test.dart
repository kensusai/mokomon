import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// こどもFB「一定回数まちがえたらゲームオーバー(報酬なし)。
/// コインを払えば続行できる」(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PuzzleGame game-over', () {
    test('fails after 3 wrong guesses without paying out the round reward', () {
      final g = PuzzleGame(rng: Random(5));
      final wrong = g.choices.indexWhere((p) => p != g.target);
      for (var i = 0; i < minigameMaxMistakes; i++) {
        expect(g.finished, isFalse);
        expect(g.guess(wrong), isFalse);
      }
      expect(g.failed, isTrue);
      expect(g.finished, isTrue);
      expect(g.reward, 0);
      // 失敗後はタップしても何も変わらない
      expect(g.guess(wrong), isFalse);
      expect(g.mistakes, minigameMaxMistakes);
    });

    test('continueAfterFail resets mistakes so play can resume', () {
      final g = PuzzleGame(rng: Random(5));
      for (var i = 0; i < minigameMaxMistakes; i++) {
        g.guess(g.choices.indexWhere((p) => p != g.target));
      }
      expect(g.failed, isTrue);
      g.continueAfterFail();
      expect(g.failed, isFalse);
      expect(g.finished, isFalse);
      expect(g.mistakes, 0);
      final correct = g.choices.indexOf(g.target);
      expect(g.guess(correct), isTrue);
      expect(g.reward, puzzleRewardPerRound);
    });
  });

  group('OddOneGame game-over', () {
    test('fails after 3 wrong guesses', () {
      final g = OddOneGame(rng: Random(4));
      final wrong = (g.oddIndex + 1) % g.cells.length;
      for (var i = 0; i < minigameMaxMistakes; i++) {
        expect(g.guess(wrong), isFalse);
      }
      expect(g.failed, isTrue);
      expect(g.reward, 0);
      g.continueAfterFail();
      expect(g.failed, isFalse);
      expect(g.guess(g.oddIndex), isTrue);
    });
  });

  group('OrderGame game-over', () {
    test('fails after 3 wrong taps', () {
      final g = OrderGame(rng: Random(3));
      final wrong = g.cells.indexWhere((n) => n != g.next);
      for (var i = 0; i < minigameMaxMistakes; i++) {
        expect(g.tap(wrong), isFalse);
      }
      expect(g.failed, isTrue);
      expect(g.finished, isTrue);
      g.continueAfterFail();
      expect(g.finished, isFalse);
      expect(g.tap(g.cells.indexOf(g.next)), isTrue);
    });
  });

  group('CountGame game-over', () {
    test('fails after 3 wrong guesses', () {
      final g = CountGame(rng: Random(2));
      final wrong = g.choices.indexWhere((c) => c != g.answer);
      for (var i = 0; i < minigameMaxMistakes; i++) {
        expect(g.guess(wrong), isFalse);
      }
      expect(g.failed, isTrue);
      expect(g.reward, 0);
      g.continueAfterFail();
      expect(g.failed, isFalse);
      expect(g.guess(g.choices.indexOf(g.answer)), isTrue);
    });
  });

  group('GameController.payToContinue', () {
    GameController fresh(int coins) => GameController(
        GameState()
          ..stage = 1
          ..coins = coins,
        SaveStore());

    test('deducts coins when affordable', () {
      final c = fresh(10);
      expect(c.payToContinue(minigameContinueCost), isTrue);
      expect(c.state.coins, 10 - minigameContinueCost);
    });

    test('fails and leaves coins untouched when not affordable', () {
      final c = fresh(1);
      expect(c.payToContinue(minigameContinueCost), isFalse);
      expect(c.state.coins, 1);
    });
  });
}

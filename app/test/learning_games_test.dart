import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';

/// もじ系学習ゲーム3種のロジック(docs/game-design.md §5)。
void main() {
  group('KanaFindGame', () {
    test('grid grows and late rounds use look-alike distractors', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = KanaFindGame(rng: Random(seed));
        while (!g.finished) {
          final round = g.round;
          expect(g.cells.length, switch (round) {
            < 2 => 8,
            < 4 => 12,
            < 6 => 16,
            _ => 20,
          });
          // ターゲットはちょうど1枚
          expect(g.cells.where((c) => c == g.target).length, 1);
          expect(g.cells[g.targetIndex], g.target);
          final group = kanaGroups.firstWhere((gr) => gr.contains(g.target));
          final distractors = [
            for (var i = 0; i < g.cells.length; i++)
              if (i != g.targetIndex) g.cells[i],
          ];
          if (round < 2) {
            // ならし: にた字グループの外から出す
            expect(distractors.any(group.contains), isFalse);
          } else {
            // ここから同グループのにた字だけ
            expect(distractors.every(group.contains), isTrue);
          }
          expect(g.guess(g.targetIndex), isTrue);
        }
        expect(g.reward, kanaFindRounds * kanaFindRewardPerRound);
      }
    });

    test('wrong taps count mistakes and 3 fail the game', () {
      final g = KanaFindGame(rng: Random(1));
      final wrong = g.targetIndex == 0 ? 1 : 0;
      expect(g.guess(wrong), isFalse);
      expect(g.mistakes, 1);
      expect(g.round, 0);
      g.guess(wrong);
      g.guess(wrong);
      expect(g.failed, isTrue);
      g.continueAfterFail();
      expect(g.failed, isFalse);
    });
  });

  group('KataMatchGame', () {
    test('first half shows hiragana, second half flips to katakana', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = KataMatchGame(rng: Random(seed));
        final prompts = <String>{};
        while (!g.finished) {
          final pair = kataPairs.firstWhere(
            (p) => p.$1 == g.prompt || p.$2 == g.prompt,
          );
          if (g.round < 4) {
            expect(g.prompt, pair.$1, reason: '前半: ひらがな → カタカナ');
            expect(g.choices, contains(pair.$2));
          } else {
            expect(g.prompt, pair.$2, reason: '後半: カタカナ → ひらがな');
            expect(g.choices, contains(pair.$1));
          }
          expect(g.choices.length, 4);
          expect(g.choices.toSet().length, 4, reason: '4択は重複しない');
          prompts.add(g.prompt);
          expect(g.guess(g.choices.indexOf(g.answer)), isTrue);
        }
        expect(prompts.length, kataRounds, reason: '1プレイ内で同じ字を出さない');
        expect(g.reward, kataRounds * kataRewardPerRound);
      }
    });

    test('wrong choice counts a mistake and does not advance', () {
      final g = KataMatchGame(rng: Random(2));
      final wrong = g.choices.indexWhere((c) => c != g.answer);
      expect(g.guess(wrong), isFalse);
      expect(g.mistakes, 1);
      expect(g.round, 0);
    });
  });

  group('WordBuildGame', () {
    /// 未使用セルから [ch] のセル位置を探す。
    int cellOf(WordBuildGame g, String ch) => [
      for (var i = 0; i < g.cells.length; i++) i,
    ].firstWhere((i) => !g.used.contains(i) && g.cells[i] == ch);

    test('words grow 2 -> 3 -> 4 chars and full play pays 18', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = WordBuildGame(rng: Random(seed));
        while (!g.finished) {
          final round = g.round;
          // 完成タップの瞬間に g.word は次の単語へ切り替わるので先に控える
          final word = g.word;
          expect(word.length, switch (round) {
            < 2 => 2,
            < 4 => 3,
            _ => 4,
          });
          expect(g.cells.length, word.length * 2, reason: 'ダミーは同数');
          // 正しい文字を順にタッチすると completes
          for (var k = 0; k < word.length; k++) {
            final result = g.tap(cellOf(g, word[k]));
            if (k < word.length - 1) {
              expect(result, WordTap.progress);
            } else {
              expect(
                result,
                round == wordRounds - 1
                    ? WordTap.gameComplete
                    : WordTap.wordComplete,
              );
            }
          }
        }
        expect(g.reward, wordRounds * wordRewardPerRound);
      }
    });

    test('dummies never contain letters of the word', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = WordBuildGame(rng: Random(seed));
        final wordChars = g.word.split('');
        final counts = <String, int>{};
        for (final c in g.cells) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
        for (final c in wordChars) {
          expect(
            counts[c],
            wordChars.where((w) => w == c).length,
            reason: 'ことばの文字はことば内の出現数だけ(ダミーに混ざらない)',
          );
        }
      }
    });

    test('wrong letter is a mistake, used cell is ignored', () {
      final g = WordBuildGame(rng: Random(3));
      final wrongCell = [
        for (var i = 0; i < g.cells.length; i++) i,
      ].firstWhere((i) => g.cells[i] != g.word[0]);
      expect(g.tap(wrongCell), WordTap.wrong);
      expect(g.mistakes, 1);
      expect(g.nextIndex, 0, reason: 'まちがいでは進まない');

      final okCell = cellOf(g, g.word[0]);
      expect(g.tap(okCell), WordTap.progress);
      expect(g.tap(okCell), WordTap.ignored, reason: '使用済みセルは無視');
      expect(g.mistakes, 1, reason: '無視はミスに数えない');
    });

    test('three mistakes fail the game and coins can continue', () {
      final g = WordBuildGame(rng: Random(4));
      final wrongCell = [
        for (var i = 0; i < g.cells.length; i++) i,
      ].firstWhere((i) => g.cells[i] != g.word[0]);
      g.tap(wrongCell);
      g.tap(wrongCell);
      expect(g.tap(wrongCell), WordTap.wrong);
      expect(g.failed, isTrue);
      expect(g.finished, isTrue);
      g.continueAfterFail();
      expect(g.failed, isFalse);
      expect(g.finished, isFalse);
    });
  });
}

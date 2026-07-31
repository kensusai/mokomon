import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/screens/kana_find_screen.dart';
import 'package:mokomon/screens/kata_match_screen.dart';
import 'package:mokomon/screens/word_build_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// もじ系学習ゲーム3種の画面フロー(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('kana: finding the target all 8 rounds pays 16', (tester) async {
    final c = stage1Controller();
    final game = KanaFindGame(rng: Random(2));
    await pumpScreen(tester, KanaFindScreen(controller: c, game: game));

    for (var round = 0; round < kanaFindRounds; round++) {
      await tester.tap(find.byKey(ValueKey('kana-${game.targetIndex}')));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.textContaining('+16 コイン'), findsOneWidget);
    expect(c.state.coins, 26); // 10 + 16
  });

  testWidgets('kana: wrong tap does not advance', (tester) async {
    final c = stage1Controller();
    final game = KanaFindGame(rng: Random(2));
    await pumpScreen(tester, KanaFindScreen(controller: c, game: game));

    final wrong = game.targetIndex == 0 ? 1 : 0;
    await tester.tap(find.byKey(ValueKey('kana-$wrong')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.round, 0);
    expect(game.mistakes, 1);
    expect(c.state.coins, 10);
  });

  testWidgets('kata: matching all 8 rounds pays 16', (tester) async {
    final c = stage1Controller();
    final game = KataMatchGame(rng: Random(3));
    await pumpScreen(tester, KataMatchScreen(controller: c, game: game));

    for (var round = 0; round < kataRounds; round++) {
      final i = game.choices.indexOf(game.answer);
      await tester.tap(find.byKey(ValueKey('kata-$i')));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.textContaining('+16 コイン'), findsOneWidget);
    expect(c.state.coins, 26); // 10 + 16
  });

  testWidgets('word: building all 6 words pays 18', (tester) async {
    final c = stage1Controller();
    final game = WordBuildGame(rng: Random(4));
    await pumpScreen(tester, WordBuildScreen(controller: c, game: game));

    for (var round = 0; round < wordRounds; round++) {
      final word = game.word;
      for (var k = 0; k < word.length; k++) {
        final cell = [
          for (var i = 0; i < game.cells.length; i++) i,
        ].firstWhere((i) => !game.used.contains(i) && game.cells[i] == word[k]);
        await tester.tap(find.byKey(ValueKey('word-$cell')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // 完成演出のあと次のことばへ
      await tester.pump(const Duration(milliseconds: 700));
    }

    expect(find.textContaining('+18 コイン'), findsOneWidget);
    expect(c.state.coins, 28); // 10 + 18
  });

  testWidgets('word: wrong letter counts a mistake', (tester) async {
    final c = stage1Controller();
    final game = WordBuildGame(rng: Random(4));
    await pumpScreen(tester, WordBuildScreen(controller: c, game: game));

    final wrong = [
      for (var i = 0; i < game.cells.length; i++) i,
    ].firstWhere((i) => game.cells[i] != game.word[0]);
    await tester.tap(find.byKey(ValueKey('word-$wrong')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.nextIndex, 0);
    expect(game.mistakes, 1);
    expect(c.state.coins, 10);
  });
}

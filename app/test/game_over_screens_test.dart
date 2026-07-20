import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/screens/count_screen.dart';
import 'package:mokomon/screens/odd_one_screen.dart';
import 'package:mokomon/screens/order_screen.dart';
import 'package:mokomon/screens/puzzle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ミニゲームのミス回数上限→ゲームオーバー→コインで続行(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController controller([int coins = 10]) => GameController(
      GameState()
        ..stage = 1
        ..coins = coins,
      SaveStore());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) =>
      tester.pumpWidget(MaterialApp(home: screen));

  testWidgets(
      'puzzle: 3 wrong picks end the game with no reward, coins buy a continue',
      (tester) async {
    final c = controller();
    final game = PuzzleGame(rng: Random(5));
    await pumpScreen(tester, PuzzleScreen(controller: c, game: game));

    Finder wrongChoiceFinder() {
      final wrong = game.choices.firstWhere((p) => p != game.target);
      return find.byWidgetPredicate((w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == 'ShapePainter' &&
          w.size == const Size(64, 64) &&
          (w.painter as dynamic).shape == wrong.shape &&
          (w.painter as dynamic).color.toARGB32() == wrong.color);
    }

    for (var i = 0; i < minigameMaxMistakes; i++) {
      await tester.tap(wrongChoiceFinder());
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('まちがえすぎ! ゲームオーバー'), findsOneWidget);
    expect(c.state.coins, 10);

    await tester.tap(find.text('🪙$minigameContinueCost コインで つづける'));
    await tester.pump();
    expect(c.state.coins, 10 - minigameContinueCost);
    expect(find.text('まちがえすぎ! ゲームオーバー'), findsNothing);
    expect(game.mistakes, 0);
  });

  testWidgets('odd-one: game over with too few coins offers give-up only',
      (tester) async {
    final c = controller(2); // continueCost(5)未満
    final game = OddOneGame(rng: Random(4));
    await pumpScreen(tester, OddOneScreen(controller: c, game: game));

    final wrong = (game.oddIndex + 1) % game.cells.length;
    for (var i = 0; i < minigameMaxMistakes; i++) {
      await tester.tap(find.byKey(ValueKey('odd-$wrong')));
      await tester.pump();
    }

    expect(find.text('まちがえすぎ! ゲームオーバー'), findsOneWidget);
    expect(find.text('コインが たりないよ'), findsOneWidget);
    expect(c.state.coins, 2);

    await tester.tap(find.text('あきらめる'));
    await tester.pumpAndSettle();
    expect(find.byType(OddOneScreen), findsNothing);
    expect(c.state.coins, 2); // 消費されない
  });

  testWidgets('order: game over stops the clock and continuing resumes it',
      (tester) async {
    final c = controller();
    final game = OrderGame(rng: Random(3));
    await pumpScreen(tester, OrderScreen(controller: c, game: game));

    final wrong = game.cells.indexOf(game.cells.firstWhere((n) => n != 1));
    for (var i = 0; i < minigameMaxMistakes; i++) {
      await tester.tap(find.byKey(ValueKey('order-$wrong')));
      await tester.pump();
    }

    expect(find.text('まちがえすぎ! ゲームオーバー'), findsOneWidget);
    await tester.tap(find.text('🪙$minigameContinueCost コインで つづける'));
    await tester.pump();
    expect(c.state.coins, 10 - minigameContinueCost);

    for (var n = 1; n <= 9; n++) {
      await tester.tap(find.byKey(ValueKey('order-${game.cells.indexOf(n)}')));
      await tester.pump();
    }
    expect(find.text('ぜんぶ おせた! +16 コイン!'), findsOneWidget);
  });

  testWidgets('count: 3 wrong picks end the game with no reward',
      (tester) async {
    final c = controller();
    final game = CountGame(rng: Random(2));
    await pumpScreen(tester, CountScreen(controller: c, game: game));

    final wrong = game.choices.indexWhere((n) => n != game.answer);
    for (var i = 0; i < minigameMaxMistakes; i++) {
      await tester.tap(find.byKey(ValueKey('count-choice-$wrong')));
      await tester.pump();
    }

    expect(find.text('まちがえすぎ! ゲームオーバー'), findsOneWidget);
    expect(c.state.coins, 10);
  });
}

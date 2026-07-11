import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/screens/catch_screen.dart';
import 'package:mokomon/screens/memory_screen.dart';
import 'package:mokomon/screens/puzzle_screen.dart';
import 'package:mokomon/widgets/shape_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController controller() =>
      GameController(GameState()..stage = 1, SaveStore());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) =>
      tester.pumpWidget(MaterialApp(home: screen));

  testWidgets('puzzle: answering all 8 rounds pays 16 coins + shared reward',
      (tester) async {
    final c = controller();
    final game = PuzzleGame(rng: Random(5));
    await pumpScreen(tester, PuzzleScreen(controller: c, game: game));

    for (var round = 0; round < puzzleRounds; round++) {
      final target = game.target;
      // ターゲットと同じ図形の選択肢セルをタップする
      final choiceFinder = find.byWidgetPredicate((w) =>
          w is CustomPaint &&
          w.painter is ShapePainter &&
          (w.painter as ShapePainter).shape == target.shape &&
          (w.painter as ShapePainter).color.toARGB32() == target.color &&
          w.size == const Size(64, 64));
      expect(choiceFinder, findsOneWidget);
      await tester.tap(choiceFinder);
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.text('ぜんぶ せいかい! +16 コイン!'), findsOneWidget);
    expect(c.state.coins, 26); // 10 + 16
    expect(c.state.happy, 92); // 80 + 12
    expect(c.state.xp, 10);
  });

  testWidgets('puzzle: wrong answer shakes but does not advance',
      (tester) async {
    final c = controller();
    final game = PuzzleGame(rng: Random(5));
    await pumpScreen(tester, PuzzleScreen(controller: c, game: game));

    final wrong = game.choices.firstWhere((p) => p != game.target);
    await tester.tap(find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter is ShapePainter &&
        (w.painter as ShapePainter).shape == wrong.shape &&
        (w.painter as ShapePainter).color.toARGB32() == wrong.color &&
        w.size == const Size(64, 64)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.round, 0);
    expect(c.state.coins, 10);
  });

  testWidgets('memory: finding all pairs pays 12 coins', (tester) async {
    final c = controller();
    final game = MemoryGame(rng: Random(3));
    await pumpScreen(tester, MemoryScreen(controller: c, game: game));

    for (final e in memoryEmoji) {
      final i = game.cards.indexOf(e);
      final j = game.cards.lastIndexOf(e);
      await tester.tap(find.byKey(ValueKey('mem-$i')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(ValueKey('mem-$j')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('ぜんぶ みつけた! +12 コイン!'), findsOneWidget);
    expect(c.state.coins, 22);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('catch: countdown starts the game and time-up pays the score',
      (tester) async {
    final c = controller();
    late CatchGame game;
    await pumpScreen(
      tester,
      CatchScreen(
        controller: c,
        gameFactory: () {
          game = CatchGame(rng: Random(1))..timeLeft = 2;
          return game;
        },
      ),
    );

    expect(find.text('🍎 フルーツキャッチ'), findsOneWidget);
    await tester.tap(find.text('はじめる!'));
    await tester.pump();
    // カウントダウン 3→2→1
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    // カウントダウン終了でゲーム開始(注入したゲームの残り時間が表示される)
    expect(find.text('はじめる!'), findsNothing);
    expect(find.text('⏰ 2'), findsOneWidget);

    // 直接アイテムを置いてタップ→スコア加算
    game.items.add(CatchItem(
        x: 200, y: 300, vy: 0, emoji: '⭐', star: true, wobble: 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('⭐'), findsOneWidget);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.score, 3);

    // dt上限0.05sで残り2秒を消化(1ゲーム秒 = 20フレーム)
    for (var i = 0; i < 45 && !game.finished; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.text('+3 コイン げっと!'), findsOneWidget);
    expect(c.state.coins, 13);
    expect(c.state.xp, 10);
  });
}

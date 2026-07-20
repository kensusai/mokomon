import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/screens/balloon_screen.dart';
import 'package:mokomon/screens/whack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ふうせんわり/もぐらたたきの Ticker 駆動フロー
/// (docs/review-findings.md #7 で TimedArcadeGameMixin に共通化)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController controller() =>
      GameController(GameState()..stage = 1, SaveStore());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) =>
      tester.pumpWidget(MaterialApp(home: screen));

  testWidgets('balloon: countdown starts the game and time-up pays the score',
      (tester) async {
    final c = controller();
    late BalloonGame game;
    await pumpScreen(
      tester,
      BalloonScreen(
        controller: c,
        gameFactory: () {
          game = BalloonGame(rng: Random(1))..timeLeft = 2;
          return game;
        },
      ),
    );

    expect(find.text('🎈 ふうせんわり'), findsOneWidget);
    await tester.tap(find.text('はじめる!'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('はじめる!'), findsNothing);
    expect(find.text('⏰ 2'), findsOneWidget);

    game.items.add(BalloonItem(
        x: 200,
        y: 300,
        vy: 0,
        emoji: '⭐',
        golden: true,
        bomb: false,
        wobble: 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.score, 3);

    for (var i = 0; i < 45 && !game.finished; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.text('+3 コイン げっと!'), findsOneWidget);
    expect(c.state.coins, 13);
  });

  testWidgets('whack: countdown starts the game and time-up pays the score',
      (tester) async {
    final c = controller();
    late WhackGame game;
    await pumpScreen(
      tester,
      WhackScreen(
        controller: c,
        gameFactory: () {
          game = WhackGame(rng: Random(1))..timeLeft = 2;
          return game;
        },
      ),
    );

    expect(find.text('🔨 もぐらたたき'), findsOneWidget);
    await tester.tap(find.text('はじめる!'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('はじめる!'), findsNothing);
    expect(find.text('⏰ 2'), findsOneWidget);

    for (var i = 0; i < 45 && !game.finished; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.textContaining('コイン げっと!'), findsOneWidget);
  });
}

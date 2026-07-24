import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/screens/compare_screen.dart';
import 'package:mokomon/screens/pika_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// 新ゲーム2種(どっちがおおい?/ぴかっとタッチ)の画面フロー
/// (docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('compare: answering all 6 rounds pays 18 coins', (tester) async {
    final c = stage1Controller();
    final game = CompareGame(rng: Random(1));
    await pumpScreen(tester, CompareScreen(controller: c, game: game));

    for (var round = 0; round < compareRounds; round++) {
      await tester.tap(find.byKey(ValueKey('compare-${game.moreSide}')));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.textContaining('+18 コイン'), findsOneWidget);
    expect(c.state.coins, 28); // 10 + 18
  });

  testWidgets('compare: wrong side does not advance and 3 misses end it', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = CompareGame(rng: Random(2));
    await pumpScreen(tester, CompareScreen(controller: c, game: game));

    final wrong = game.moreSide == 0 ? 1 : 0;
    await tester.tap(find.byKey(ValueKey('compare-$wrong')));
    await tester.pump();
    expect(game.round, 0);
    expect(game.mistakes, 1);

    for (var i = 0; i < minigameMaxMistakes - 1; i++) {
      await tester.tap(find.byKey(ValueKey('compare-$wrong')));
      await tester.pump();
    }
    expect(find.text('まちがえすぎ! ゲームオーバー'), findsOneWidget);
    expect(c.state.coins, 10);
  });

  testWidgets('pika: fast taps through 5 rounds pay the max reward', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = PikaGame(rng: Random(1));
    await pumpScreen(tester, PikaScreen(controller: c, game: game));

    for (var round = 0; round < pikaRounds; round++) {
      // 最大待ち2.6秒を超えて必ず光らせてからタッチ
      await tester.pump(const Duration(milliseconds: 2700));
      expect(find.text('⚡'), findsOneWidget, reason: 'ランプが光っている');
      await tester.tap(find.byKey(const ValueKey('pika-lamp')));
      await tester.pump(const Duration(milliseconds: 1000)); // 結果表示→次へ
    }

    // widget test ではタップ反応が数msなので全ラウンド+3
    expect(find.textContaining('+15 コイン'), findsOneWidget);
    expect(c.state.coins, 25); // 10 + 15
    await drainTimers(tester);
  });

  testWidgets('pika: flying every round ends with the encouraging button', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = PikaGame(rng: Random(2));
    await pumpScreen(tester, PikaScreen(controller: c, game: game));

    for (var round = 0; round < pikaRounds; round++) {
      // 最短待ち0.9秒より前にタッチ → フライング
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('pika-lamp')));
      await tester.pump();
      expect(find.textContaining('フライング'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
    }

    expect(game.reward, 0);
    expect(find.text('ざんねん! また ちょうせんしてね'), findsOneWidget);
    expect(find.text('つぎは がんばる!'), findsOneWidget);
    expect(c.state.coins, 10); // 報酬なし(happy/xpの共通報酬は付く)
    await drainTimers(tester);
  });

  testWidgets('game chooser lists the two new games', (tester) async {
    await bootApp(tester, state: GameState()..stage = 1, rng: NoPuffRandom());
    await tester.tap(find.text('あそぶ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('どっちが おおい?'), findsOneWidget);
    expect(find.text('ぴかっとタッチ'), findsOneWidget);
    await tester.tap(find.text('やめる'));
    await tester.pump(const Duration(milliseconds: 400));
    await drainTimers(tester);
  });
}

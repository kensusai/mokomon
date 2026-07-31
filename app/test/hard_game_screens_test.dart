import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/screens/math_screen.dart';
import 'package:mokomon/screens/simon_screen.dart';
import 'package:mokomon/screens/stop_screen.dart';
import 'package:mokomon/screens/stroop_screen.dart';
import 'package:mokomon/widgets/game_chooser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// 高難度ミニゲーム4種の画面フロー(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('math: answering all 6 rounds pays 18 coins', (tester) async {
    final c = stage1Controller();
    final game = MathGame(rng: Random(2));
    await pumpScreen(tester, MathScreen(controller: c, game: game));

    for (var round = 0; round < mathRounds; round++) {
      final i = game.choices.indexOf(game.answer);
      await tester.tap(find.byKey(ValueKey('math-choice-$i')));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.textContaining('+18 コイン'), findsOneWidget);
    expect(c.state.coins, 28); // 10 + 18
  });

  testWidgets('math: wrong choice does not advance', (tester) async {
    final c = stage1Controller();
    final game = MathGame(rng: Random(2));
    await pumpScreen(tester, MathScreen(controller: c, game: game));

    final wrong = game.choices.indexWhere((n) => n != game.answer);
    await tester.tap(find.byKey(ValueKey('math-choice-$wrong')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.round, 0);
    expect(game.mistakes, 1);
    expect(c.state.coins, 10);
  });

  testWidgets('reverse: clearing round 1 backwards then failing pays 4', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = SimonGame(rng: Random(0), reversed: true);
    await pumpScreen(tester, SimonScreen(controller: c, game: game));

    expect(find.textContaining('さかさまタッチ'), findsOneWidget);

    // お手本(2連)が終わるまで待つ → さかさまにタッチ
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 2200));
    for (final pad in game.sequence.reversed.toList()) {
      await tester.tap(find.byKey(ValueKey('simon-$pad')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.reward, reverseRewardPerRound);

    // 3連のお手本を待って、順方向(=まちがい)にタッチ → 終了(持ち帰り)
    await tester.pump(const Duration(milliseconds: 4000));
    expect(game.sequence.first == game.sequence.last, isFalse);
    await tester.tap(find.byKey(ValueKey('simon-${game.sequence.first}')));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.textContaining('+4 コイン'), findsOneWidget);
    expect(c.state.coins, 14); // 10 + 4
  });

  testWidgets('stop: stopping on the zone center every round pays 20', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = StopGame(rng: Random(5));
    await pumpScreen(tester, StopScreen(controller: c, game: game));
    // 最初のティック(elapsed=0)で基準時刻が決まりマーカーが走り出す
    await tester.pump(Duration.zero);

    for (var round = 0; round < stopRounds; round++) {
      // まとの中心にマーカーが乗る時刻まで進めてタッチ
      final t = game.zoneCenter / game.speed;
      await tester.pump(Duration(microseconds: (t * 1e6).round()));
      await tester.tap(find.byKey(const ValueKey('stop-tap')));
      await tester.pump(const Duration(milliseconds: 900));
    }

    expect(game.reward, 20, reason: '毎ラウンドぴったり(+4)');
    expect(find.textContaining('+20 コイン'), findsOneWidget);
    expect(c.state.coins, 30); // 10 + 20
  });

  testWidgets('stroop: tapping the ink color all 6 rounds pays 18', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = StroopGame(rng: Random(4));
    await pumpScreen(tester, StroopScreen(controller: c, game: game));

    for (var round = 0; round < stroopRounds; round++) {
      await tester.tap(find.byKey(ValueKey('stroop-${game.inkIndex}')));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.textContaining('+18 コイン'), findsOneWidget);
    expect(c.state.coins, 28); // 10 + 18
  });

  testWidgets('stroop: tapping the word color is a mistake', (tester) async {
    final c = stage1Controller();
    final game = StroopGame(rng: Random(4));
    await pumpScreen(tester, StroopScreen(controller: c, game: game));

    // ならし2問を消化してワナのある問題まで進める
    for (var round = 0; round < 2; round++) {
      await tester.tap(find.byKey(ValueKey('stroop-${game.inkIndex}')));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.tap(find.byKey(ValueKey('stroop-${game.wordIndex}')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.round, 2);
    expect(game.mistakes, 1);
    expect(c.state.coins, 10);
  });

  testWidgets('game chooser lists all 16 games', (tester) async {
    // 16種の2列グリッドが全部見えるよう縦長にする(モーダルのスクロール回避)
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showGameChooser(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    for (final title in ['けいさんタッチ', 'さかさまタッチ', 'ぴったりストップ', 'いろタッチ']) {
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('ぴったりストップ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(picked, 'stop');
  });
}

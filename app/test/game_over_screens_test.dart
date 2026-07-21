import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/audio/sound_synth.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/screens/count_screen.dart';
import 'package:mokomon/screens/odd_one_screen.dart';
import 'package:mokomon/screens/order_screen.dart';
import 'package:mokomon/screens/puzzle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// ミニゲームのミス回数上限→ゲームオーバー→コインで続行(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'puzzle: 3 wrong picks end the game with no reward, coins buy a continue',
    (tester) async {
      final c = stage1Controller();
      final game = PuzzleGame(rng: Random(5));
      await pumpScreen(tester, PuzzleScreen(controller: c, game: game));

      Finder wrongChoiceFinder() {
        final wrong = game.choices.firstWhere((p) => p != game.target);
        return find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == 'ShapePainter' &&
              w.size == const Size(64, 64) &&
              (w.painter as dynamic).shape == wrong.shape &&
              (w.painter as dynamic).color.toARGB32() == wrong.color,
        );
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
    },
  );

  testWidgets('odd-one: game over with too few coins offers give-up only', (
    tester,
  ) async {
    final c = stage1Controller(coins: 2); // continueCost(5)未満
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // pop 遷移
    await tester.pump(const Duration(milliseconds: 400)); // ルート除去の確定
    expect(find.byType(OddOneScreen), findsNothing);
    expect(c.state.coins, 2); // 消費されない
  });

  testWidgets(
    'odd-one: tapping つづける with too few coins neither quits nor continues',
    (tester) async {
      // docs/review-findings.md #20: コイン不足時の「つづける」タップが
      // onGiveUp(報酬なしで画面終了)に化けていた。何も起きないのが正しい。
      final c = stage1Controller(coins: 2); // continueCost(5)未満
      final game = OddOneGame(rng: Random(4));
      await pumpScreen(tester, OddOneScreen(controller: c, game: game));

      final wrong = (game.oddIndex + 1) % game.cells.length;
      for (var i = 0; i < minigameMaxMistakes; i++) {
        await tester.tap(find.byKey(ValueKey('odd-$wrong')));
        await tester.pump();
      }
      expect(find.text('まちがえすぎ! ゲームオーバー'), findsOneWidget);

      await tester.tap(
        find.text('🪙$minigameContinueCost コインで つづける'),
        warnIfMissed: false,
      ); // 修正後は IgnorePointer でヒットしない
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OddOneScreen), findsOneWidget); // 画面は閉じない
      expect(find.text('まちがえすぎ! ゲームオーバー'), findsOneWidget); // 続行もしない
      expect(c.state.coins, 2); // 消費されない
    },
  );

  testWidgets('order: game over stops the clock and continuing resumes it', (
    tester,
  ) async {
    final c = stage1Controller();
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

  testWidgets('odd-one: tapping during the victory delay plays no wrong sfx', (
    tester,
  ) async {
    // docs/review-findings.md #23(count 側と同じ勝利待ち400msの窓)。
    final rec = RecordingSfx();
    final c = stage1Controller(sfx: rec.sfx);
    final game = OddOneGame(rng: Random(4));
    await pumpScreen(tester, OddOneScreen(controller: c, game: game));

    for (var round = 0; round < oddRounds - 1; round++) {
      await tester.tap(find.byKey(ValueKey('odd-${game.oddIndex}')));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.tap(find.byKey(ValueKey('odd-${game.oddIndex}')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('odd-0')));
    await tester.pump(const Duration(milliseconds: 500));

    final wrongWav = SoundSynth().wavFor(Sfx.wrong);
    expect(
      rec.players
          .expand((p) => p.playedBytes)
          .where((b) => listEquals(b, wrongWav)),
      isEmpty,
      reason: '全問正解の直後に不正解音を鳴らさない',
    );
    // 注入した SfxPlayer は no-op でないため、曲長由来の仮想時間で
    // タイマーを流す(#64)
    await drainRewardJingle(tester);
  });

  testWidgets('count: 3 wrong picks end the game with no reward', (
    tester,
  ) async {
    final c = stage1Controller();
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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/screens/count_screen.dart';
import 'package:mokomon/screens/simon_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 新ゲーム2種の画面フロー(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController controller() =>
      GameController(GameState()..stage = 1, SaveStore());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) =>
      tester.pumpWidget(MaterialApp(home: screen));

  testWidgets('count: answering all 6 rounds pays 18 coins', (tester) async {
    final c = controller();
    final game = CountGame(rng: Random(2));
    await pumpScreen(tester, CountScreen(controller: c, game: game));

    for (var round = 0; round < countRounds; round++) {
      final i = game.choices.indexOf(game.answer);
      await tester.tap(find.byKey(ValueKey('count-choice-$i')));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.textContaining('+18 コイン'), findsOneWidget);
    expect(c.state.coins, 28); // 10 + 18
  });

  testWidgets('count: wrong choice does not advance', (tester) async {
    final c = controller();
    final game = CountGame(rng: Random(2));
    await pumpScreen(tester, CountScreen(controller: c, game: game));

    final wrong = game.choices.indexWhere((n) => n != game.answer);
    await tester.tap(find.byKey(ValueKey('count-choice-$wrong')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.round, 0);
    expect(c.state.coins, 10);
  });

  testWidgets('simon: clear round 1 then a wrong pad ends with +3 coins',
      (tester) async {
    final c = controller();
    final game = SimonGame(rng: Random(1));
    await pumpScreen(tester, SimonScreen(controller: c, game: game));

    // お手本再生中はタップしても進まない
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(find.byKey(const ValueKey('simon-0')),
        warnIfMissed: false);
    expect(game.reward, 0);

    // お手本(2連)が終わるまで待つ → じゅんばんにタッチ
    await tester.pump(const Duration(milliseconds: 2200));
    final first = [...game.sequence];
    for (final pad in first) {
      await tester.tap(find.byKey(ValueKey('simon-$pad')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.reward, simonRewardPerRound);

    // 3連のお手本を待って、わざと間違える → 終了(ごほうびは持ち帰り)
    await tester.pump(const Duration(milliseconds: 4000));
    final wrongPad = (game.sequence[0] + 1) % simonPads;
    await tester.tap(find.byKey(ValueKey('simon-$wrongPad')));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.textContaining('+3 コイン'), findsOneWidget);
    expect(c.state.coins, 13); // 10 + 3
  });
}

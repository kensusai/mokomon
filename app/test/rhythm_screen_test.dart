import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/screens/rhythm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// リズムタッチの画面フロー(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rhythm: hitting every beat pays 20 coins', (tester) async {
    final c = stage1Controller();
    final game = RhythmGame(rng: Random(2));
    await pumpScreen(tester, RhythmScreen(controller: c, game: game));

    // じゅんび(800ms)のあと1ビート目が光る
    await tester.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < rhythmBeats; i++) {
      await tester.tap(find.byKey(ValueKey('rhythm-${game.pads[i]}')));
      await tester.pump(Duration(milliseconds: RhythmGame.intervalMsAt(i)));
    }
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('+20 コイン'), findsOneWidget);
    expect(c.state.coins, 30); // 10 + 20
  });

  testWidgets('rhythm: wrong pads earn nothing and end with encouragement', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = RhythmGame(rng: Random(2));
    await pumpScreen(tester, RhythmScreen(controller: c, game: game));

    await tester.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < rhythmBeats; i++) {
      // わざと違うパッドをタッチ
      final wrong = (game.pads[i] + 1) % rhythmPads;
      await tester.tap(find.byKey(ValueKey('rhythm-$wrong')));
      await tester.pump(Duration(milliseconds: RhythmGame.intervalMsAt(i)));
    }
    await tester.pump(const Duration(milliseconds: 600));

    expect(game.hits, 0);
    expect(find.text('ざんねん! また ちょうせんしてね'), findsOneWidget);
    expect(find.text('つぎは がんばる!'), findsOneWidget);
    expect(c.state.coins, 10);
  });
}

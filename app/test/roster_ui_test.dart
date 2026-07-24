import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rename via the name pill', (tester) async {
    final c = await bootApp(
      tester,
      state: GameState()..stage = 1,
      rng: NoPuffRandom(),
    );

    await tester.tap(find.text('🐣 もこ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('✏️ なまえを つける'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'もこすけ');
    await tester.tap(find.text('けってい!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(c.state.nickname, 'もこすけ');
    expect(find.text('🐣 もこすけ'), findsWidgets);

    await drainTimers(tester);
  });

  testWidgets('rename dialog disposes its text controller', (tester) async {
    // docs/review-findings.md #25: 関数スコープの TextEditingController が
    // 誰にも dispose されず、開くたびに未破棄の ChangeNotifier が残っていた。
    final live = <Object>{};
    void onEvent(ObjectEvent e) {
      if (e.object is TextEditingController) {
        if (e is ObjectCreated) live.add(e.object);
        if (e is ObjectDisposed) live.remove(e.object);
      }
    }

    FlutterMemoryAllocations.instance.addListener(onEvent);
    addTearDown(
      () => FlutterMemoryAllocations.instance.removeListener(onEvent),
    );

    await bootApp(tester, state: GameState()..stage = 1, rng: NoPuffRandom());
    await tester.tap(find.text('🐣 もこ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('✏️ なまえを つける'), findsOneWidget);

    await tester.tap(find.text('とじる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(live, isEmpty, reason: 'ダイアログを閉じたらコントローラも破棄される');
    await drainTimers(tester);
  });

  testWidgets('rename is blocked on the egg stage', (tester) async {
    await bootApp(tester, state: GameState());
    await tester.tap(find.text('🥚 たまご'));
    await tester.pump();
    expect(find.text('✏️ なまえを つける'), findsNothing);
    expect(find.text('うまれたら なまえを つけられるよ!'), findsWidgets);
    await drainTimers(tester);
  });

  testWidgets('switch to a past king from the book keeps its dress-up', (
    tester,
  ) async {
    final state = GameState()
      ..stage = 1
      ..species = 1
      ..owned = {'ribbon'}
      ..collection = (List.filled(speciesList.length, false)..[0] = true)
      ..roster = [
        CreatureSnapshot(
          species: 0,
          stage: kingStage,
          xp: 0,
          eggTaps: 0,
          hunger: 80,
          happy: 80,
          color: speciesList[0].color.toARGB32(),
          equipHead: 'ribbon',
          nickname: 'モコタン',
        ),
      ];
    final c = await bootApp(tester, state: state, rng: NoPuffRandom());

    await tester.tap(find.text('📖'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('モコタン'), findsOneWidget); // 名簿のなまえが出る

    await tester.tap(find.byKey(const ValueKey('book-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(c.state.species, 0);
    expect(c.state.stage, kingStage);
    expect(c.state.equipHead, 'ribbon');
    expect(c.state.nickname, 'モコタン');
    expect(find.textContaining('「モコタン」が あそびに きたよ!'), findsWidgets);
    // 育てかけのぴょんは名簿へ
    expect(c.state.roster.singleWhere((r) => r.species == 1).stage, 1);

    await drainTimers(tester);
  });

  testWidgets('two individuals of one species open the picker dialog', (
    tester,
  ) async {
    CreatureSnapshot moko(int stage, String name) => CreatureSnapshot(
      species: 0,
      stage: stage,
      xp: 0,
      eggTaps: 0,
      hunger: 80,
      happy: 80,
      color: speciesList[0].color.toARGB32(),
      nickname: name,
    );
    final state = GameState()
      ..stage = 1
      ..species = 1
      ..collection = (List.filled(speciesList.length, false)..[0] = true)
      ..roster = [moko(kingStage, 'せんだい'), moko(1, 'にだいめ')];
    final c = await bootApp(tester, state: state, rng: NoPuffRandom());

    await tester.tap(find.text('📖'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('×2'), findsOneWidget); // 個体数バッジ

    await tester.tap(find.byKey(const ValueKey('book-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('どの子と こうたい?'), findsOneWidget);
    // せんだい はセルの代表(キング)としても出るので2箇所
    expect(find.text('せんだい'), findsWidgets);
    expect(find.text('にだいめ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pick-1'))); // にだいめ(ベビー)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(c.state.species, 0);
    expect(c.state.stage, 1);
    expect(c.state.nickname, 'にだいめ');
    // せんだいのキングと育てかけのぴょんが名簿に残っている
    expect(c.state.roster, hasLength(2));
    expect(c.state.roster.map((r) => r.nickname), containsAll(['せんだい', null]));

    await drainTimers(tester);
  });
}

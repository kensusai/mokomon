import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/screens/paint_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameController> boot(WidgetTester tester, [GameState? state]) =>
      bootApp(tester, state: state ?? (GameState()..stage = 1));

  testWidgets('shop: buying a ribbon deducts coins and equips it',
      (tester) async {
    final c = await boot(
        tester,
        GameState()
          ..stage = 1
          ..coins = 20);

    await tester.tap(find.text('おみせ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🛍️ きせかえショップ'), findsOneWidget);

    await tester.tap(find.text('リボン'));
    await tester.pump();
    expect(c.state.equipHead, 'ribbon');
    expect(c.state.coins, 5);
    expect(find.text('きてる✓'), findsOneWidget);
    expect(find.textContaining('リボンを かった!'), findsOneWidget);

    // 再タップで脱ぐ
    await tester.tap(find.text('リボン'));
    await tester.pump();
    expect(c.state.equipHead, isNull);

    await tester.tap(find.text('とじる'));
    await tester.pump(const Duration(seconds: 3));
    await drainTimers(tester);
  });

  testWidgets('book: king can welcome a new egg and state resets',
      (tester) async {
    final state = GameState()
      ..stage = 3
      ..xp = 99
      ..species = 0;
    state.collection[0] = true;
    final c = await boot(tester, state);

    await tester.tap(find.text('📖'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('📖 いきもの ずかん'), findsOneWidget);
    expect(find.text('キングもこ'), findsOneWidget); // 入手済み
    expect(find.text('???'), findsNWidgets(speciesList.length - 1));

    await tester.ensureVisible(find.text('あたらしい たまごを むかえる'));
    await tester.pump();
    await tester.tap(find.text('あたらしい たまごを むかえる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.state.stage, 0);
    expect(c.state.xp, 0);
    expect(c.state.species, isNot(3)); // キング1体では金のたまごは来ない
    expect(find.textContaining('あたらしい たまごが きたよ!'), findsOneWidget);

    await drainTimers(tester);
  });

  testWidgets('code dialog: issue a code, wipe, and restore it',
      (tester) async {
    final c = await boot(
        tester,
        GameState()
          ..stage = 2
          ..coins = 55);

    await tester.tap(find.text('💾'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('あいことばを つくる'));
    await tester.pump();
    final code = c.state.makeCode();
    expect(find.text(code), findsOneWidget);

    // 別の状態から復元する
    await tester.enterText(find.byType(TextField), code);
    c.state.coins = 0;
    c.state.stage = 1;
    await tester.tap(find.text('よみこむ'));
    await tester.pump();
    expect(c.state.coins, 55);
    expect(c.state.stage, 2);
    expect(find.textContaining('おかえり!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await drainTimers(tester);
  });

  testWidgets('code dialog: wrong code shows a gentle error toast',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('💾'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'MOKO-zzz');
    await tester.tap(find.text('よみこむ'));
    await tester.pump();
    expect(find.textContaining('あいことばが ちがうみたい'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await drainTimers(tester);
  });

  testWidgets('paint: drawing and saving stores a pattern and rewards',
      (tester) async {
    final c = GameController(GameState()..stage = 1, SaveStore());
    await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));

    // 体の中心あたりをなぞる
    final canvas = find.byType(CustomPaint).first;
    final center = tester.getCenter(canvas);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(40, 10));
    await gesture.moveBy(const Offset(-20, 30));
    await gesture.up();
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('できた!'));
      // toImage/PNGエンコードは実async処理
      for (var i = 0; i < 20 && c.state.pattern == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(c.state.pattern, isNotNull);
    expect(c.state.xp, 4);
    expect(c.state.happy, 88);
  });

  testWidgets('paint on egg stage is blocked with a hint', (tester) async {
    await boot(tester, GameState());
    await tester.tap(find.text('おえかき'));
    await tester.pump();
    expect(find.text('うまれてから おえかき できるよ!'), findsOneWidget);
    await drainTimers(tester);
  });
}

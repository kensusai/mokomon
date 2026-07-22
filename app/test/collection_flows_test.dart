import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

  // 20テーマ(+おまかせ)= 5行あるのに高さが固定320pxで、4行目以降が
  // 見切れて表示されていた。スクロールも無効なので手が届かない。
  testWidgets('shop: every background cell fits inside the grid viewport', (
    tester,
  ) async {
    await boot(tester, GameState()..stage = 1);

    await tester.tap(find.text('おみせ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('🖼️ はいけい'), warnIfMissed: true);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 最後のセル(おまかせ)が生成され、かつ枠内に収まっていること。
    // 高さが足りないと sliver がカリングして生成すらされない。
    expect(find.text('おまかせ'), findsOneWidget);
    final grid = tester.getRect(find.byType(GridView).first);
    expect(
      tester.getRect(find.text('おまかせ')).bottom,
      lessThanOrEqualTo(grid.bottom),
      reason: 'last background cell is clipped',
    );

    await tester.tap(find.text('とじる'));
    await tester.pump(const Duration(seconds: 3));
    await drainTimers(tester);
  });

  testWidgets('shop: buying a ribbon deducts coins and equips it', (
    tester,
  ) async {
    final c = await boot(
      tester,
      GameState()
        ..stage = 1
        ..coins = 20,
    );

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

  testWidgets('book: king can welcome a new egg and state resets', (
    tester,
  ) async {
    final state = GameState()
      ..stage = kingStage
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
    expect(find.textContaining('あたらしい たまごが きたよ!'), findsWidgets);

    await drainTimers(tester);
  });

  testWidgets('book: a baby can welcome a new egg and come back later', (
    tester,
  ) async {
    // こどもFB: キングにならなくても途中で新しいたまごを迎えられる。
    // いまの子は名簿に保存され、ずかんのセルから続きを再開できる。
    final c = await boot(
      tester,
      GameState()
        ..stage = 1
        ..xp = 10
        ..nickname = 'もこすけ',
    );

    await tester.tap(find.text('📖'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('あたらしい たまごを むかえる'), findsOneWidget);

    await tester.ensureVisible(find.text('あたらしい たまごを むかえる'));
    await tester.pump();
    await tester.tap(find.text('あたらしい たまごを むかえる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(c.state.stage, 0); // 新しいたまご
    expect(c.state.roster[0]?.stage, 1); // もとの子は名簿にベビーのまま保存
    expect(c.state.roster[0]?.nickname, 'もこすけ');
    expect(c.state.collection[0], isFalse); // 図鑑登録はキング到達のみ

    // ずかんを開き直すと、育成途中の子が「???」ではなく名前つきで見える
    await tester.pump(const Duration(seconds: 2)); // 孵化お祝いのあと
    await tester.tap(find.text('📖'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('もこすけ'), findsOneWidget);

    // タップで交代して続きから
    await tester.tap(find.text('もこすけ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.state.species, 0);
    expect(c.state.stage, 1);
    expect(c.state.xp, 10);

    await drainTimers(tester);
  });

  testWidgets('book: no new-egg button while still an egg', (tester) async {
    await boot(tester, GameState()); // たまご段階
    await tester.tap(find.text('📖'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('あたらしい たまごを むかえる'), findsNothing);
    await tester.tap(find.text('とじる'));
    await tester.pump(const Duration(milliseconds: 400));
    await drainTimers(tester);
  });

  testWidgets('code dialog: issue a code, wipe, and restore it', (
    tester,
  ) async {
    final c = await boot(
      tester,
      GameState()
        ..stage = 2
        ..coins = 55,
    );

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

  testWidgets('code dialog: wrong code shows a gentle error toast', (
    tester,
  ) async {
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

  testWidgets('paint: drawing and saving stores a pattern and rewards', (
    tester,
  ) async {
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

  testWidgets('paint: stamps can be placed and saved', (tester) async {
    final c = GameController(GameState()..stage = 1, SaveStore());
    await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));

    await tester.tap(find.text('スタンプ')); // ツールを切替
    await tester.pump();
    await tester.tap(find.text('💩')); // おもしろスタンプを選ぶ
    await tester.pump();
    final canvas = find.byType(CustomPaint).first;
    final gesture = await tester.startGesture(tester.getCenter(canvas));
    await gesture.up();
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('できた!'));
      for (var i = 0; i < 20 && c.state.pattern == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(c.state.pattern, isNotNull);
  });

  testWidgets('paint: bucket fill produces a savable pattern', (tester) async {
    final c = GameController(GameState()..stage = 1, SaveStore());
    await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));

    await tester.tap(find.text('ぬりつぶし'));
    await tester.pump();
    final canvas = find.byType(CustomPaint).first;
    await tester.runAsync(() async {
      await tester.tap(canvas); // 体の中をタップ → 全面ぬりつぶし
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('できた!'));
      for (var i = 0; i < 20 && c.state.pattern == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(c.state.pattern, isNotNull);
  });

  testWidgets('paint: bucket fill and save dispose all temporary images', (
    tester,
  ) async {
    // docs/review-findings.md #24: probe/layer/保存時 image などの一時
    // ui.Image が dispose されず GC 任せだった。生成/破棄イベントで数える。
    final live = <Object>{};
    void onEvent(ObjectEvent e) {
      if (e.object is ui.Image) {
        if (e is ObjectCreated) live.add(e.object);
        if (e is ObjectDisposed) live.remove(e.object);
      }
    }

    FlutterMemoryAllocations.instance.addListener(onEvent);
    addTearDown(
      () => FlutterMemoryAllocations.instance.removeListener(onEvent),
    );

    final c = GameController(GameState()..stage = 1, SaveStore());
    await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));

    await tester.tap(find.text('ぬりつぶし'));
    await tester.pump();
    final canvas = find.byType(CustomPaint).first;
    await tester.runAsync(() async {
      await tester.tap(canvas);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    expect(live.length, 1, reason: 'ぬりつぶし後は確定レイヤー(_baseImage)だけが生存する');

    await tester.runAsync(() async {
      await tester.tap(find.text('できた!'));
      for (var i = 0; i < 20 && c.state.pattern == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(c.state.pattern, isNotNull);
    expect(live.length, 1, reason: '保存用の一時イメージも解放される');

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(live, isEmpty, reason: '画面破棄で最後の1枚も解放される');
  });

  testWidgets('paint: leaving mid-bucket-fill disposes the pending layer', (
    tester,
  ) async {
    // docs/review-findings.md #46: fill の await 中に画面を閉じると、
    // 完成した newLayer が誰にも所有されず漏れていた。
    final live = <Object>{};
    void onEvent(ObjectEvent e) {
      if (e.object is ui.Image) {
        if (e is ObjectCreated) live.add(e.object);
        if (e is ObjectDisposed) live.remove(e.object);
      }
    }

    FlutterMemoryAllocations.instance.addListener(onEvent);
    addTearDown(
      () => FlutterMemoryAllocations.instance.removeListener(onEvent),
    );

    final c = GameController(GameState()..stage = 1, SaveStore());
    await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));
    await tester.tap(find.text('ぬりつぶし'));
    await tester.pump();

    // fill を開始した直後(最初の await で中断中)に画面を破棄する
    await tester.tap(find.byType(CustomPaint).first);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    // 中断していた fill の async 処理を完走させる
    await tester.runAsync(() async {
      for (var i = 0; i < 40 && live.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // 一度もイメージが生成されないまま抜けるのを防ぐ最低待ち
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(live, isEmpty, reason: '画面破棄後に完成したレイヤーも dispose される');
  });

  testWidgets('paint: ぜんぶけす is ignored while a bucket fill is in flight', (
    tester,
  ) async {
    // docs/review-findings.md #47: fill の await 中に「ぜんぶけす」を
    // 受け付けると、消したはずの絵が fill 結果ごと復活し、保存済み
    // pattern(clearPattern 済み)と画面が食い違う。fill 中は無視が正しい。
    late final String savedPattern;
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(
        const Rect.fromLTWH(0, 0, 4, 4),
        Paint()..color = const Color(0xFFFF0000),
      );
      final img = await rec.endRecording().toImage(4, 4);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      savedPattern = base64Encode(bytes!.buffer.asUint8List());
    });

    final c = GameController(
      GameState()
        ..stage = 1
        ..pattern = savedPattern,
      SaveStore(),
    );
    await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));
    await tester.tap(find.text('ぬりつぶし'));
    await tester.pump();

    // fill を開始し、最初の await で中断している間に「ぜんぶけす」をタップ
    await tester.tap(find.byType(CustomPaint).first);
    await tester.tap(find.text('ぜんぶけす'), warnIfMissed: false);

    // fill を完走させる
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    // fill 中の「ぜんぶけす」は無視され、保存済み pattern は消えない
    expect(c.state.pattern, isNotNull);
  });

  testWidgets(
    'paint: double-tapping できた! saves once and pops only this screen',
    (tester) async {
      // docs/review-findings.md #19: _save() の await 中に再タップされると
      // 保存が二重に走り、pop が2回呼ばれて下の画面まで閉じてしまう。
      final c = GameController(GameState()..stage = 1, SaveStore());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PaintScreen(controller: c),
                    ),
                  ),
                  child: const Text('ひらく'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ひらく'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.runAsync(() async {
        await tester.tap(find.text('できた!'));
        await tester.tap(find.text('できた!')); // 保存処理中の連打
        for (var i = 0; i < 20 && c.state.pattern == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 保存(happy+8/xp+4)は1回だけ。二重なら xp が 8 になる。
      expect(c.state.xp, 4);
      // PaintScreen だけが閉じ、下のベース画面は残っていること。
      expect(find.text('ひらく'), findsOneWidget);
    },
  );

  testWidgets(
    'paint: repeated bucket fills and leaving the screen do not double-dispose images',
    (tester) async {
      // docs/review-findings.md #5: _baseImage の差し替え・画面終了時に
      // 正しく dispose されること(二重 dispose なら debug モードで例外になる)。
      final c = GameController(GameState()..stage = 1, SaveStore());
      await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));

      await tester.tap(find.text('ぬりつぶし'));
      await tester.pump();
      final canvas = find.byType(CustomPaint).first;

      for (var i = 0; i < 2; i++) {
        await tester.runAsync(() async {
          await tester.tap(canvas);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pump();
      }

      // 画面を閉じる(dispose() が最後の _baseImage を解放する)。
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1)); // 保留タイマー・遷移を固定時間で流す
    },
  );

  testWidgets('paint on egg stage is blocked with a hint', (tester) async {
    await boot(tester, GameState());
    await tester.tap(find.text('おえかき'));
    await tester.pump();
    expect(find.text('うまれてから おえかき できるよ!'), findsWidgets);
    await drainTimers(tester);
  });
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/main.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// なでなでの6%💨判定を出さない決定的Random(テスト安定化)。
class NoPuffRandom implements Random {
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameController> boot(WidgetTester tester, [GameState? state]) async {
    final c =
        GameController(state ?? GameState(), SaveStore(), rng: NoPuffRandom());
    await tester.pumpWidget(MokomonApp(controller: c));
    return c;
  }

  /// ホームのタイマー(ヒント・キラキラ等)を流してから画面を破棄する。
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('egg hatches on the third tap with a birth celebration',
      (tester) async {
    final c = await boot(tester);
    final egg = find.byType(CreatureView);

    await tester.tap(egg);
    await tester.pump();
    expect(find.text('あれ? なにか きこえる…'), findsOneWidget);

    await tester.tap(egg);
    await tester.pump();
    expect(find.text('ヒビが はいった! もういっかい!'), findsOneWidget);

    await tester.tap(egg);
    await tester.pump();
    expect(find.text('うまれた!'), findsOneWidget);
    expect(c.state.stage, 1);
    expect(c.state.xp, 5);

    await tester.tap(find.text('わーい!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🐣 もこ'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('feeding an apple from the food modal costs 3 coins',
      (tester) async {
    final c = await boot(tester, GameState()..stage = 1);

    await tester.tap(find.text('ごはん'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('なにを たべる?'), findsOneWidget);

    await tester.tap(find.text('りんご'));
    await tester.pump();
    expect(c.state.coins, 7);
    expect(c.state.hunger, 95);

    // 900ms後の進化チェック(このxpでは進化しない)を流す
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('🪙 7'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('feeding is blocked with a hint when hunger >= 98',
      (tester) async {
    await boot(
        tester,
        GameState()
          ..stage = 1
          ..hunger = 98);

    await tester.tap(find.text('ごはん'));
    await tester.pump();
    expect(find.text('おなか いっぱい みたい!'), findsOneWidget);
    expect(find.text('なにを たべる?'), findsNothing);

    await drain(tester);
  });

  testWidgets('feed button on egg stage nudges to tap the egg first',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('ごはん'));
    await tester.pump();
    expect(find.text('まずは たまごを タッチしてみて!'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('petting past the threshold triggers the evolution cutscene',
      (tester) async {
    final c = await boot(
        tester,
        GameState()
          ..stage = 1
          ..xp = 29);

    await tester.tap(find.byType(CreatureView));
    await tester.pump();
    expect(c.state.xp, 30);

    // カットシーン: シルエット2.4s → フラッシュ → リビール
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('すごい!!'), findsOneWidget); // ボタンは非表示だが存在
    expect(c.state.stage, 1); // まだ確定していない

    await tester.pump(const Duration(milliseconds: 2600));
    expect(c.state.stage, 2); // リビールで確定
    expect(find.text('もこもん に しんかした!!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('すごい!!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🌱 もこもん'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('king evolution registers the collection and shows a toast',
      (tester) async {
    final c = await boot(
        tester,
        GameState()
          ..stage = 2
          ..xp = 79
          ..species = 1);

    await tester.tap(find.byType(CreatureView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));
    expect(c.state.stage, 3);
    expect(c.state.collection[1], isTrue);
    expect(find.text('キングぴょん たんじょう!!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('すごい!!'));
    await tester.pump();
    expect(find.textContaining('ずかんに とうろくされたよ!'), findsOneWidget);

    // トーストが消えるまで
    await tester.pump(const Duration(seconds: 3));
    await drain(tester);
  });
}

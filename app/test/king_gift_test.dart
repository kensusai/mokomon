import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/widgets/creature_view.dart';
import 'package:mokomon/data/foods.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController king({double sparkle = 0}) => GameController(
    GameState()
      ..stage = 3
      ..kingSparkle = sparkle,
    SaveStore(),
    rng: NoPuffRandom(),
  );

  group('きらきらゲージ (docs/game-design.md §14)', () {
    test('accrues only for kings', () {
      final baby = GameController(GameState()..stage = 1, SaveStore());
      baby.pet();
      expect(baby.state.kingSparkle, 0);

      final c = king();
      c.pet();
      expect(c.state.kingSparkle, 10);
      c.feed(foods.first);
      expect(c.state.kingSparkle, 26);
      c.finishMinigame(5);
      expect(c.state.kingSparkle, 56);
      c.savePaint('p');
      expect(c.state.kingSparkle, 81);
    });

    test('first three gifts unlock stamps in order, then coins', () {
      final c = king(sparkle: 95);
      c.pet(); // 100到達
      var gift = c.takePendingGift()!;
      expect(gift.stamp, '👑');
      expect(c.state.unlockedStamps, {'👑'});
      expect(c.state.kingSparkle, 0);
      expect(c.takePendingGift(), isNull); // 1回だけ受け取れる

      c.state.kingSparkle = 95;
      c.pet();
      expect(c.takePendingGift()!.stamp, '🎆');
      c.state.kingSparkle = 95;
      c.pet();
      expect(c.takePendingGift()!.stamp, '🦄');

      c.state.kingSparkle = 95;
      final before = c.state.coins;
      c.pet();
      gift = c.takePendingGift()!;
      expect(gift.stamp, isNull);
      expect(gift.coins, inInclusiveRange(20, 40));
      expect(c.state.coins, before + gift.coins);
    });

    test('persists via json; あいことば resets the gauge but keeps unlocks', () {
      final c = king(sparkle: 42);
      c.state.unlockedStamps.add('👑');
      final viaJson = GameState()..loadJson(c.state.toJson());
      expect(viaJson.kingSparkle, 42);
      expect(viaJson.unlockedStamps, {'👑'});

      final viaCode = GameState()
        ..unlockedStamps.add('🎆')
        ..kingSparkle = 88;
      expect(viaCode.loadCode(c.state.makeCode()), isTrue);
      expect(viaCode.kingSparkle, 0);
      expect(viaCode.unlockedStamps, {'🎆'}); // 端末ローカルの解放は維持
    });
  });

  group('king gift UI', () {
    testWidgets('sparkle meter shows only for kings and gift celebrates', (
      tester,
    ) async {
      await bootApp(
        tester,
        state: GameState()
          ..stage = 3
          ..kingSparkle = 95,
        rng: NoPuffRandom(),
      );
      expect(find.text('✨'), findsWidgets); // きらきらメーター

      // なでなで(+6)で満タン → おみやげ演出
      await tester.tap(find.byType(CreatureView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('おうさまの おみやげ!'), findsOneWidget);
      expect(find.textContaining('👑'), findsWidgets); // 最初の解放スタンプ

      await tester.tap(find.text('わーい!'));
      await tester.pump();
      await drainTimers(tester);
    });

    testWidgets('gift is deferred while another screen covers home', (
      tester,
    ) async {
      // docs/review-findings.md #51: ミニゲーム中に満タンになっても、
      // その画面の上にお祝いを被せず、ホーム復帰後に受け取る。
      final c = await bootApp(
        tester,
        state: GameState()
          ..stage = 3
          ..kingSparkle = 80,
        rng: NoPuffRandom(),
      );

      // ホームの上に別画面を積む(ミニゲーム相当)
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('game')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // ミニゲームクリア相当(+30 で満タン → gift 発生 → notify)
      c.finishMinigame(10);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('おうさまの おみやげ!'),
        findsNothing,
        reason: 'ゲーム画面の上にお祝いを被せない',
      );

      // ホームへ戻ると受け取れる(次の state 変化で消費)
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      c.toggleSound(); // 何らかの notify
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('おうさまの おみやげ!'), findsOneWidget);

      await tester.tap(find.text('わーい!'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5)); // ジングル分
      await drainTimers(tester);
    });

    testWidgets('no sparkle meter before king', (tester) async {
      await bootApp(tester, state: GameState()..stage = 2);
      expect(find.text('✨'), findsNothing);
      await drainTimers(tester);
    });
  });
}

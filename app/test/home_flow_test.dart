import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/audio/sound_synth.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameController> boot(WidgetTester tester, [GameState? state]) =>
      bootApp(tester, state: state, rng: NoPuffRandom());

  testWidgets('egg hatches on the third tap with a birth celebration', (
    tester,
  ) async {
    final c = await boot(tester);
    final egg = find.byType(CreatureView);

    await tester.tap(egg);
    await tester.pump();
    expect(find.text('あれ? なにか きこえる…'), findsWidgets);

    await tester.tap(egg);
    await tester.pump();
    expect(find.text('ヒビが はいった! もういっかい!'), findsWidgets);

    await tester.tap(egg);
    await tester.pump();
    expect(find.text('うまれた!'), findsOneWidget);
    expect(c.state.stage, 1);
    expect(c.state.xp, 5);

    await tester.tap(find.text('わーい!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🐣 もこ'), findsOneWidget);

    await drainTimers(tester);
  });

  testWidgets('hatching plays the mega fanfare and ducks the bgm', (
    tester,
  ) async {
    // 「うまれた!」の瞬間に megaFanfare が鳴り、BGMが一時停止すること
    // (配線の回帰テスト)。
    final rec = RecordingSfx();
    await bootApp(tester, rng: NoPuffRandom(), sfx: rec.sfx);
    await rec.sfx.startBgm(); // 実アプリでは main() が呼ぶ
    final bgm = rec.players.single;

    final egg = find.byType(CreatureView);
    for (var i = 0; i < 3; i++) {
      await tester.tap(egg);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('うまれた!'), findsOneWidget);

    expect(bgm.calls, contains('pause'), reason: 'ジングル中はBGMを止める');
    final fanfare = SoundSynth().wavFor(Sfx.megaFanfare);
    expect(
      rec.players.any((p) => p.playedBytes.any((b) => listEquals(b, fanfare))),
      isTrue,
      reason: 'megaFanfare が再生される',
    );

    await tester.tap(find.text('わーい!'));
    await tester.pump();
    await drainRewardJingle(tester); // ダックタイマーを流す
    await drainTimers(tester);
  });

  // 2匹目以降(図鑑から新しいたまごを迎えたあと)も、孵化の演出と
  // ファンファーレが1匹目と同じように出ること。
  testWidgets('a second egg hatches with the same birth celebration', (
    tester,
  ) async {
    final c = await boot(
      tester,
      GameState()
        ..stage = kingStage
        ..xp = 400,
    );
    c.newEgg();
    await tester.pump();
    expect(c.state.stage, 0);

    final egg = find.byType(CreatureView);
    await tester.tap(egg);
    await tester.pump();
    await tester.tap(egg);
    await tester.pump();
    await tester.tap(egg);
    await tester.pump();

    expect(find.text('うまれた!'), findsOneWidget);
    expect(c.state.stage, 1);

    await tester.tap(find.text('わーい!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await drainTimers(tester);
  });

  testWidgets('feeding an apple from the food modal costs 3 coins', (
    tester,
  ) async {
    final c = await boot(tester, GameState()..stage = 1);

    await tester.tap(find.text('ごはん'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('なにを たべる?'), findsOneWidget);

    await tester.tap(find.textContaining('りんご'));
    await tester.pump();
    expect(c.state.coins, 7);
    expect(c.state.hunger, 95);

    // 900ms後の進化チェック(このxpでは進化しない)を流す
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('🪙 7'), findsOneWidget);

    await drainTimers(tester);
  });

  testWidgets('feeding is blocked with a hint when hunger >= 98', (
    tester,
  ) async {
    await boot(
      tester,
      GameState()
        ..stage = 1
        ..hunger = 98,
    );

    await tester.tap(find.text('ごはん'));
    await tester.pump();
    expect(find.text('おなか いっぱい みたい!'), findsWidgets);
    expect(find.text('なにを たべる?'), findsNothing);

    await drainTimers(tester);
  });

  testWidgets('feed button on egg stage nudges to tap the egg first', (
    tester,
  ) async {
    await boot(tester);
    await tester.tap(find.text('ごはん'));
    await tester.pump();
    expect(find.text('まずは たまごを タッチしてみて!'), findsWidgets);
    await drainTimers(tester);
  });

  testWidgets('petting past the threshold triggers the evolution cutscene', (
    tester,
  ) async {
    final c = await boot(
      tester,
      GameState()
        ..stage = 1
        ..xp = 44,
    );

    await tester.tap(find.byType(CreatureView));
    await tester.pump();
    expect(c.state.xp, 45);

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

    await drainTimers(tester);
  });

  testWidgets('king evolution registers the collection and shows a toast', (
    tester,
  ) async {
    final c = await boot(
      tester,
      GameState()
        ..stage = 3
        ..xp = 239
        ..species = 1,
    );

    await tester.tap(find.byType(CreatureView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));
    expect(c.state.stage, kingStage);
    expect(c.state.collection[1], isTrue);
    expect(find.text('キングぴょん たんじょう!!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('すごい!!'));
    await tester.pump();
    expect(find.textContaining('ずかんに とうろくされたよ!'), findsOneWidget);

    // トーストが消えるまで
    await tester.pump(const Duration(seconds: 3));
    await drainTimers(tester);
  });
}

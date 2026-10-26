// ホームのレイアウト: 画面が低い端末(iPhone SE 等)でも、いきものが
// 下のパネルに隠れないこと(こどもFB: SE でたまごの下がパネルにかぶる)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 論理ピクセルで端末サイズを指定する(dpr=1)。
  void useScreen(WidgetTester tester, Size logical) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = logical;
    addTearDown(tester.view.reset);
  }

  const iphoneSe = Size(375, 667);
  const iphone16 = Size(393, 852);
  // Container の rect は margin 込みなので、白いパネル本体(DecoratedBox)を測る
  final card = find
      .descendant(
        of: find.byKey(const ValueKey('home-card')),
        matching: find.byType(DecoratedBox),
      )
      .first;

  Future<void> expectCreatureAboveCard(WidgetTester tester) async {
    // 回遊中でも位置が変わるだけで大きさは変わらないので、数フレーム見る
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 700));
      final creature = tester.getRect(find.byType(CreatureView));
      final panel = tester.getRect(card);
      expect(
        creature.bottom,
        lessThanOrEqualTo(panel.top),
        reason: 'creature $creature overlaps card $panel',
      );
    }
  }

  testWidgets('egg stays above the bottom card on iPhone SE', (tester) async {
    useScreen(tester, iphoneSe);
    await bootApp(tester, rng: NoPuffRandom());
    await expectCreatureAboveCard(tester);
    await drainTimers(tester);
  });

  testWidgets('hatched creature stays above the bottom card on iPhone SE', (
    tester,
  ) async {
    useScreen(tester, iphoneSe);
    await bootApp(tester, state: GameState()..stage = 1, rng: NoPuffRandom());
    await expectCreatureAboveCard(tester);
    await drainTimers(tester);
  });

  testWidgets('tall screens keep the full-size creature and roomy card', (
    tester,
  ) async {
    useScreen(tester, iphone16);
    await bootApp(tester, rng: NoPuffRandom());
    await expectCreatureAboveCard(tester);
    final creature = tester.getRect(find.byType(CreatureView));
    expect(creature.width, closeTo(iphone16.width * 0.64, 0.5));
    // 高い画面ではパネルの余白を詰めない(既存の見た目を維持)
    final panel = tester.getRect(card);
    expect(panel.left, 12);
    await drainTimers(tester);
  });

  testWidgets('short screens use the compact card so the creature stays big', (
    tester,
  ) async {
    useScreen(tester, iphoneSe);
    await bootApp(tester, rng: NoPuffRandom());
    await tester.pump(const Duration(milliseconds: 100));
    final panel = tester.getRect(card);
    expect(panel.left, 8, reason: 'compact margin');
    final creature = tester.getRect(find.byType(CreatureView));
    expect(creature.width, closeTo(iphoneSe.width * 0.64, 0.5));
    await drainTimers(tester);
  });
}

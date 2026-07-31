import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_view.dart';
import 'package:mokomon/widgets/creature_wanderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// ホームのいきもの回遊(docs/game-design.md §3)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hatched creature wanders around the stage', (tester) async {
    await bootApp(tester, state: GameState()..stage = 1, rng: NoPuffRandom());
    final before = tester.getRect(find.byType(CreatureView));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final after = tester.getRect(find.byType(CreatureView));

    // 傾き(Transform.rotate)で外接矩形の大きさは揺れるため、中心で比較する
    expect(after.center, isNot(before.center), reason: '2秒で移動している');
    await drainTimers(tester);
  });

  testWidgets('hatching eases out of the home position (no teleport)', (
    tester,
  ) async {
    // docs/review-findings.md #68: 孵化(enabled切替)直後に軌道の初期位置へ
    // 瞬間移動しない。ホーム統合だとテスト画面ではAlignの可動域が数pxしか
    // なく検出できないため、直接ホストで検証する。
    Widget host({required bool enabled}) => MaterialApp(
      home: Stack(
        children: [
          CreatureWanderer(
            species: 0,
            enabled: enabled,
            child: const SizedBox(
              key: ValueKey('wander-child'),
              width: 100,
              height: 100,
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(host(enabled: false)); // たまご: 固定表示
    final egg = tester.getRect(find.byKey(const ValueKey('wander-child')));
    await tester.pumpWidget(host(enabled: true)); // 孵化
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester.getRect(find.byKey(const ValueKey('wander-child')));

    expect(
      (after.center - egg.center).distance,
      lessThan(30),
      reason: '孵化100ms後はまだホームポジション付近から滑らかに動き出す',
    );
  });

  testWidgets('switching species blends from the current position', (
    tester,
  ) async {
    // docs/review-findings.md #68: 名簿交代(種族変更)でも軌道が跳ばない
    Widget host(int species) => MaterialApp(
      home: Stack(
        children: [
          CreatureWanderer(
            species: species,
            enabled: true,
            child: const SizedBox(
              key: ValueKey('wander-child'),
              width: 100,
              height: 100,
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(host(0));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // 3秒回遊
    }
    final before = tester.getRect(find.byKey(const ValueKey('wander-child')));
    await tester.pumpWidget(host(3)); // 種族交代
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester.getRect(find.byKey(const ValueKey('wander-child')));

    expect(
      (after.center - before.center).distance,
      lessThan(30),
      reason: '交代直後は直前の位置からなめらかに新しい軌道へ',
    );
  });

  testWidgets('egg stays put at the home position', (tester) async {
    await bootApp(tester, rng: NoPuffRandom()); // stage 0 = たまご
    final before = tester.getRect(find.byType(CreatureView));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final after = tester.getRect(find.byType(CreatureView));

    expect(after.topLeft, before.topLeft, reason: 'たまごは動かない');
    await drainTimers(tester);
  });
}

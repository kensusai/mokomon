import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_view.dart';
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

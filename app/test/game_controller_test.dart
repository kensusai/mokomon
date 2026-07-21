import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/foods.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController fresh([GameState? state]) =>
      GameController(state ?? GameState(), SaveStore());

  group('feed (ごはん)', () {
    test('refuses to feed when full (hunger >= 98)', () {
      // docs/review-findings.md #38: 満腹ルールを UI 層だけでなく
      // ユースケース層でも強制する。
      final c = fresh(
        GameState()
          ..stage = 1
          ..hunger = 99
          ..coins = 50,
      );
      // docs/review-findings.md #52: 失敗理由は enum で区別する
      expect(c.feed(foods.first), FeedOutcome.full);
      expect(c.state.coins, 50); // 消費されない
      expect(c.state.hunger, 99); // 変化しない
      expect(c.state.xp, 0);
    });
  });

  group('pet (なでなで)', () {
    test('adds happy +3 / xp +1 and notifies', () {
      final c = fresh(GameState()..stage = 1);
      var notified = 0;
      c.addListener(() => notified++);
      c.pet();
      expect(c.state.happy, 83);
      expect(c.state.xp, 1);
      expect(notified, 1);
    });

    test('happy is clamped at 100', () {
      final c = fresh(
        GameState()
          ..stage = 1
          ..happy = 99,
      );
      c.pet();
      expect(c.state.happy, 100);
    });
  });

  group('SaveStore', () {
    test('save/load roundtrip', () async {
      final store = SaveStore();
      final s = GameState()
        ..stage = 2
        ..coins = 42
        ..species = 1;
      await store.save(s);
      final loaded = await store.load();
      expect(loaded.stage, 2);
      expect(loaded.coins, 42);
      expect(loaded.species, 1);
    });

    test('load returns fresh state when storage is empty', () async {
      final loaded = await SaveStore().load();
      expect(loaded.stage, 0);
      expect(loaded.coins, 10);
    });

    test('load survives corrupted data', () async {
      SharedPreferences.setMockInitialValues({'mokomon-v1': '{broken json'});
      final loaded = await SaveStore().load();
      expect(loaded.stage, 0);
      expect(loaded.coins, 10);
    });
  });
}

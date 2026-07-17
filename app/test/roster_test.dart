import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController fresh(GameState s) => GameController(s, SaveStore());

  GameState kingMoko() => GameState()
    ..stage = 3
    ..species = 0
    ..xp = 99
    ..color = 0xFF112233
    ..pattern = 'moko-pattern'
    ..owned = {'ribbon', 'sunglass'}
    ..equipHead = 'ribbon'
    ..nickname = 'モコタン'
    ..collection = (List.filled(speciesList.length, false)..[0] = true);

  group('newEgg snapshots the departing king (docs/game-design.md §12)', () {
    test('roster keeps look, equipment, and nickname', () {
      final c = fresh(kingMoko());
      c.newEgg();
      final snap = c.state.roster[0]!;
      expect(snap.stage, 3);
      expect(snap.color, 0xFF112233);
      expect(snap.pattern, 'moko-pattern');
      expect(snap.equipHead, 'ribbon');
      expect(snap.nickname, 'モコタン');
      // 新しいたまごは無名で始まる
      expect(c.state.nickname, isNull);
    });
  });

  group('switchCreature', () {
    test('swaps to a raised king and back, preserving each look', () {
      final s = kingMoko();
      final c = fresh(s);
      c.newEgg(); // モコタンが roster へ、新しいたまごが来る
      final newSpecies = s.species;
      expect(newSpecies, isNot(0));

      expect(c.switchCreature(0), isTrue);
      expect(s.species, 0);
      expect(s.stage, 3);
      expect(s.equipHead, 'ribbon');
      expect(s.nickname, 'モコタン');
      expect(s.pattern, 'moko-pattern');
      // 育てかけのたまごも roster に退避されている
      expect(s.roster[newSpecies]!.stage, 0);

      // もう一度戻すと、たまごの続きから
      expect(c.switchCreature(newSpecies), isTrue);
      expect(s.species, newSpecies);
      expect(s.stage, 0);
      expect(s.nickname, isNull);
    });

    test('refuses unowned species and the current one', () {
      final s = kingMoko();
      final c = fresh(s);
      expect(c.switchCreature(0), isFalse); // 現在の種族
      expect(c.switchCreature(1), isFalse); // 未入手
    });
  });

  group('roster persistence', () {
    test('survives json roundtrip', () {
      final c = fresh(kingMoko());
      c.newEgg();
      final restored = GameState()..loadJson(c.state.toJson());
      expect(restored.roster[0]!.equipHead, 'ribbon');
      expect(restored.roster[0]!.nickname, 'モコタン');
      expect(restored.roster[0]!.pattern, 'moko-pattern');
    });

    test('あいことば does not carry roster or nickname', () {
      final c = fresh(kingMoko());
      final restored = GameState()..nickname = 'ステイル';
      expect(restored.loadCode(c.state.makeCode()), isTrue);
      expect(restored.nickname, isNull); // リセットされる
      expect(restored.roster, isEmpty); // rosterは対象外
    });
  });

  group('nickname / rename', () {
    test('sets displayName, trims, and caps at 10 chars', () {
      final c = fresh(GameState()..stage = 1);
      c.rename('  もこすけ  ');
      expect(c.state.nickname, 'もこすけ');
      expect(c.state.displayName, '🐣 もこすけ');
      c.rename('あいうえおかきくけこさし'); // 12文字 → 10文字に
      expect(c.state.nickname, 'あいうえおかきくけこ');
      c.rename('');
      expect(c.state.nickname, isNull);
      expect(c.state.displayName, '🐣 もこ');
    });
  });
}

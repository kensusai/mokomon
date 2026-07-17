import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/backgrounds.dart';
import 'package:mokomon/data/foods.dart';
import 'package:mokomon/data/items.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController fresh([GameState? state]) =>
      GameController(state ?? (GameState()..stage = 1), SaveStore());

  ShopItem item(String key) => shopItems.firstWhere((i) => i.key == key);

  group('shop (docs/game-design.md §7)', () {
    test('buying deducts coins and equips immediately', () {
      final c = fresh(GameState()..coins = 20);
      expect(c.tapShopItem(item('ribbon')), ShopTapOutcome.bought);
      expect(c.state.coins, 5);
      expect(c.state.owned, contains('ribbon'));
      expect(c.state.equipHead, 'ribbon');
    });

    test('cannot buy without enough coins', () {
      final c = fresh(GameState()..coins = 10);
      expect(c.tapShopItem(item('sunglass')), ShopTapOutcome.notEnoughCoins);
      expect(c.state.coins, 10);
      expect(c.state.owned, isEmpty);
    });

    test('owned items toggle on/off by slot', () {
      final c = fresh(GameState()..coins = 40);
      c.tapShopItem(item('ribbon'));
      expect(c.tapShopItem(item('ribbon')), ShopTapOutcome.unequipped);
      expect(c.state.equipHead, isNull);
      expect(c.tapShopItem(item('ribbon')), ShopTapOutcome.equipped);
      expect(c.state.equipHead, 'ribbon');
    });

    test('buying a face item does not replace the head slot', () {
      final c = fresh(GameState()..coins = 40);
      c.tapShopItem(item('ribbon'));
      c.tapShopItem(item('glasses'));
      expect(c.state.equipHead, 'ribbon');
      expect(c.state.equipFace, 'glasses');
    });
  });

  group('paint (docs/game-design.md §6)', () {
    test('savePaint stores the pattern and grants happy +8 / xp +4', () {
      final c = fresh(GameState()..happy = 95);
      c.savePaint('dummy-base64');
      expect(c.state.pattern, 'dummy-base64');
      expect(c.state.happy, 100);
      expect(c.state.xp, 4);
    });

    test('clearPattern removes it without rewards', () {
      final c = fresh(GameState()..pattern = 'x');
      c.clearPattern();
      expect(c.state.pattern, isNull);
      expect(c.state.xp, 0);
    });

    test('setBodyColor keeps color independent from species', () {
      final c = fresh();
      c.setBodyColor(0xFFFFD23E);
      expect(c.state.color, 0xFFFFD23E);
      expect(c.state.species, 0);
    });

    test('pattern survives json roundtrip but not あいことば', () {
      final s = GameState()..pattern = 'abc';
      final viaJson = GameState()..loadJson(s.toJson());
      expect(viaJson.pattern, 'abc');

      final viaCode = GameState()..pattern = 'stale';
      expect(viaCode.loadCode(s.makeCode()), isTrue);
      expect(viaCode.pattern, isNull);
    });

    test('newEgg clears the pattern', () {
      final c = fresh(GameState()
        ..stage = 3
        ..pattern = 'abc');
      c.newEgg();
      expect(c.state.pattern, isNull);
    });
  });

  group('expanded content (docs/game-design.md §3, §7, §13)', () {
    test('6 foods with the new entries', () {
      expect(foods, hasLength(6));
      expect(foods.map((f) => f.key).toList().sublist(3),
          ['onigiri', 'ramen', 'parfait']);
    });

    test('20 shop items, appended after the original 6', () {
      expect(shopItems, hasLength(20));
      expect(shopItems[5].key, 'sunglass'); // 既存の並びは不変
      expect(shopItems.last.key, 'cheekseal');
    });

    test('high-index item equips survive あいことば roundtrip', () {
      final s = GameState()
        ..owned = {'halo', 'cheekseal'}
        ..equipHead = 'halo'
        ..equipFace = 'cheekseal';
      final restored = GameState();
      expect(restored.loadCode(s.makeCode()), isTrue);
      expect(restored.equipHead, 'halo');
      expect(restored.equipFace, 'cheekseal');
    });

    test('background defaults per species and per-creature override', () {
      expect(speciesDefaultBg, hasLength(speciesList.length));
      final c = fresh(GameState()..species = 14); // obake
      expect(c.state.effectiveBg, 2); // よぞら
      c.setBackground(4);
      expect(c.state.effectiveBg, 4);
      final viaJson = GameState()..loadJson(c.state.toJson());
      expect(viaJson.bg, 4);
      c.setBackground(null);
      expect(c.state.effectiveBg, 2); // おまかせ=デフォルトへ

      // あいことばには含めない
      c.setBackground(5);
      final viaCode = GameState();
      expect(viaCode.loadCode(c.state.makeCode()), isTrue);
      expect(viaCode.bg, isNull);
    });
  });

  group('applyCode', () {
    test('applies a valid code and rejects a bad one', () {
      final donor = GameState()
        ..stage = 2
        ..coins = 77;
      final c = fresh(GameState());
      expect(c.applyCode(donor.makeCode()), isTrue);
      expect(c.state.stage, 2);
      expect(c.state.coins, 77);
      expect(c.applyCode('MOKO-garbage'), isFalse);
    });
  });

  group('equipment persists across newEgg', () {
    test('owned/equip kept, growth state reset', () {
      final s = GameState()
        ..stage = 3
        ..coins = 40;
      final c = fresh(s);
      c.tapShopItem(item('sunglass'));
      c.newEgg(); // ベビーがサングラス=かわいい(仕様§7)
      expect(c.state.owned, contains('sunglass'));
      expect(c.state.equipFace, 'sunglass');
      expect(c.state.stage, 0);
    });
  });

  group('nextEggSpecies still respects lottery from controller', () {
    test('golden egg after 3 kings via newEgg', () {
      final s = GameState()..stage = 3;
      s.collection[0] = true;
      s.collection[1] = true;
      s.collection[2] = true;
      final c = GameController(s, SaveStore(), rng: Random(7));
      expect(c.newEgg(), 3);
      expect(s.species, 3);
    });
  });
}

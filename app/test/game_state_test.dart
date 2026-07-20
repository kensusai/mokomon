import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/items.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/models/game_state.dart';

void main() {
  group('evolveCheck / nearEvolve (docs/game-design.md §3)', () {
    test('stage1 evolves to 2 at xp 30', () {
      final s = GameState()
        ..stage = 1
        ..xp = 29;
      expect(s.evolveCheck(), isNull);
      s.xp = 30;
      expect(s.evolveCheck(), 2);
    });

    test('stage2 evolves to 3 at xp 80', () {
      final s = GameState()
        ..stage = 2
        ..xp = 79;
      expect(s.evolveCheck(), isNull);
      s.xp = 80;
      expect(s.evolveCheck(), 3);
    });

    test('egg and king never evolve', () {
      expect((GameState()..xp = 999).evolveCheck(), isNull);
      expect(
          (GameState()
                ..stage = 3
                ..xp = 999)
              .evolveCheck(),
          isNull);
    });

    test('near-evolve glow starts 8 before stage2 and 12 before stage3', () {
      final s = GameState()..stage = 1;
      s.xp = 21;
      expect(s.nearEvolve, isFalse);
      s.xp = 22;
      expect(s.nearEvolve, isTrue);
      s
        ..stage = 2
        ..xp = 67;
      expect(s.nearEvolve, isFalse);
      s.xp = 68;
      expect(s.nearEvolve, isTrue);
    });
  });

  group('nextEggSpecies (docs/game-design.md §4)', () {
    test('golden egg is guaranteed once 3 normal kings are raised', () {
      final s = GameState();
      s.collection[0] = true;
      s.collection[1] = true;
      s.collection[2] = true;
      for (var i = 0; i < 20; i++) {
        expect(s.nextEggSpecies(Random(i)), secretSpeciesIndex);
      }
    });

    test('golden egg is not offered before 3 normal kings', () {
      final s = GameState();
      s.collection[0] = true;
      s.collection[1] = true;
      for (var i = 0; i < 50; i++) {
        expect(s.nextEggSpecies(Random(i)), isNot(secretSpeciesIndex));
      }
    });

    test('picks only unowned normal species otherwise', () {
      final s = GameState();
      s.collection[0] = true;
      for (var i = 0; i < 50; i++) {
        final next = s.nextEggSpecies(Random(i));
        expect(s.collection[next], isFalse);
        expect(next, isNot(secretSpeciesIndex));
      }
    });

    test('all owned: picks any species different from current', () {
      final s = GameState()..species = 2;
      for (var i = 0; i < s.collection.length; i++) {
        s.collection[i] = true;
      }
      for (var i = 0; i < 50; i++) {
        expect(s.nextEggSpecies(Random(i)), isNot(2));
      }
    });
  });

  group('applyOfflineDecay (docs/game-design.md §2)', () {
    test('no decay without a previous save timestamp', () {
      final s = GameState()..applyOfflineDecay();
      expect(s.hunger, 80);
      expect(s.happy, 80);
    });

    test('decays by elapsed minutes with caps and floors', () {
      final s = GameState()
        ..lastSavedMs = DateTime.now()
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch;
      s.applyOfflineDecay();
      expect(s.hunger, closeTo(70, 0.1)); // 80 - 30/3
      expect(s.happy, closeTo(72.5, 0.1)); // 80 - 30/4

      final long = GameState()
        ..lastSavedMs = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
      long.applyOfflineDecay();
      expect(long.hunger, 30); // 80 - cap 50
      expect(long.happy, 40); // 80 - cap 40

      final floor = GameState()
        ..hunger = 20
        ..happy = 25
        ..lastSavedMs = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
      floor.applyOfflineDecay();
      expect(floor.hunger, 15); // floor
      expect(floor.happy, 20); // floor
    });
  });

  group('あいことば codec (docs/game-design.md §8)', () {
    GameState sample() => GameState()
      ..stage = 2
      ..xp = 45
      ..coins = 123
      ..hunger = 66
      ..happy = 77
      ..species = 4
      ..collection = List.generate(speciesList.length, (i) => i == 0 || i == 2)
      ..owned = {'ribbon', 'glasses'}
      ..equipHead = 'ribbon'
      ..equipFace = 'glasses'
      ..eggTaps = 2;

    test('roundtrip restores all encoded fields and resets eggTaps', () {
      final code = sample().makeCode();
      expect(code, startsWith('MOKO-'));
      final restored = GameState();
      expect(restored.loadCode(code), isTrue);
      expect(restored.stage, 2);
      expect(restored.xp, 45);
      expect(restored.coins, 123);
      expect(restored.hunger, 66);
      expect(restored.happy, 77);
      expect(restored.species, 4);
      expect(restored.collection,
          List.generate(speciesList.length, (i) => i == 0 || i == 2));
      expect(restored.owned, {'ribbon', 'glasses'});
      expect(restored.equipHead, 'ribbon');
      expect(restored.equipFace, 'glasses');
      expect(restored.eggTaps, 0);
    });

    test('accepts lowercase prefix and embedded whitespace', () {
      final code = sample().makeCode();
      final munged = 'moko-${code.substring(5, 12)} ${code.substring(12)}\n';
      expect(GameState().loadCode(munged), isTrue);
    });

    test('rejects tampered checksum and garbage', () {
      final code = sample().makeCode();
      final body = code.substring(5);
      final tampered =
          'MOKO-${body.substring(0, body.length - 1)}${body.endsWith('A') ? 'B' : 'A'}';
      expect(GameState().loadCode(tampered), isFalse);
      expect(GameState().loadCode('MOKO-abcdef'), isFalse);
      expect(GameState().loadCode(''), isFalse);
    });

    test('unequips items that are not owned', () {
      // Craft a code where equip indexes point at unowned items: encode a
      // state owning nothing but with equip set (makeCode allows it).
      final s = GameState()
        ..equipHead = shopItems[0].key
        ..equipFace = shopItems[4].key;
      final restored = GameState();
      expect(restored.loadCode(s.makeCode()), isTrue);
      expect(restored.equipHead, isNull);
      expect(restored.equipFace, isNull);
    });

    test('clamps out-of-range values', () {
      final s = GameState()
        ..stage = 3
        ..hunger = 100
        ..happy = 0
        ..species = speciesList.length - 1;
      final restored = GameState();
      expect(restored.loadCode(s.makeCode()), isTrue);
      expect(restored.stage, 3);
      expect(restored.hunger, 100);
      expect(restored.happy, 0);
      expect(restored.species, speciesList.length - 1);
    });
  });

  group('json persistence roundtrip', () {
    test('toJson/loadJson preserves fields', () {
      final s = GameState()
        ..stage = 1
        ..xp = 12
        ..coins = 55
        ..hunger = 44
        ..happy = 33
        ..eggTaps = 1
        ..species = 5
        ..owned = {'tophat'}
        ..equipHead = 'tophat'
        ..sound = false;
      s.collection[5] = true;
      final restored = GameState()..loadJson(s.toJson());
      expect(restored.stage, 1);
      expect(restored.xp, 12);
      expect(restored.coins, 55);
      expect(restored.hunger, 44);
      expect(restored.happy, 33);
      expect(restored.eggTaps, 1);
      expect(restored.species, 5);
      expect(restored.collection[5], isTrue);
      expect(restored.owned, {'tophat'});
      expect(restored.equipHead, 'tophat');
      expect(restored.sound, isFalse);
    });

    test('a single malformed roster entry does not wipe the rest of the save',
        () {
      // docs/review-findings.md #1: 名簿の壊れたキー1つで全データを失わない
      final s = GameState()
        ..coins = 77
        ..collection[3] = true;
      final json = s.toJson();
      (json['roster'] as Map)['not-a-number'] = {'stage': 3};
      final restored = GameState()..loadJson(json);
      expect(restored.coins, 77);
      expect(restored.collection[3], isTrue);
      expect(restored.roster, isEmpty); // 壊れたエントリだけスキップされる
    });

    test('a valid roster entry survives alongside a malformed one', () {
      final s = GameState()..coins = 20;
      final json = s.toJson();
      (json['roster'] as Map)
        ..['not-a-number'] = {'stage': 3}
        ..['2'] = {'stage': 3, 'xp': 0, 'color': 0};
      final restored = GameState()..loadJson(json);
      expect(restored.roster.keys, [2]);
    });
  });

  group('offline decay / loadJson clamping (docs/review-findings.md #3, #4)',
      () {
    test('applyOfflineDecay never raises stats when the clock moves backward',
        () {
      final s = GameState()
        ..hunger = 50
        ..happy = 50
        ..lastSavedMs = DateTime.now().millisecondsSinceEpoch + 60000; // 未来
      s.applyOfflineDecay();
      expect(s.hunger, 50); // 増えない
      expect(s.happy, 50);
    });

    test('applyOfflineDecay clamps to the documented upper bound', () {
      final s = GameState()
        ..hunger = 200 // 何らかの理由で範囲外になっていた場合
        ..happy = 200
        ..lastSavedMs = DateTime.now().millisecondsSinceEpoch;
      s.applyOfflineDecay();
      expect(s.hunger, lessThanOrEqualTo(100));
      expect(s.happy, lessThanOrEqualTo(100));
    });

    test('loadJson clamps out-of-range hunger/happy/xp/coins/stage', () {
      final restored = GameState()
        ..loadJson({
          'stage': 9,
          'xp': -5,
          'coins': -3,
          'hunger': 500,
          'happy': -20,
        });
      expect(restored.stage, inInclusiveRange(0, 3));
      expect(restored.xp, greaterThanOrEqualTo(0));
      expect(restored.coins, greaterThanOrEqualTo(0));
      expect(restored.hunger, inInclusiveRange(0, 100));
      expect(restored.happy, inInclusiveRange(0, 100));
    });
  });

  group('isSad', () {
    test('sad below 30 hunger or happy', () {
      expect((GameState()..hunger = 29).isSad, isTrue);
      expect((GameState()..happy = 29).isSad, isTrue);
      expect(
          (GameState()
                ..hunger = 30
                ..happy = 30)
              .isSad,
          isFalse);
    });
  });
}

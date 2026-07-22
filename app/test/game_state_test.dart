import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/backgrounds.dart';
import 'package:mokomon/data/items.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/models/game_state.dart';

void main() {
  group('evolveCheck / nearEvolve (docs/game-design.md §3)', () {
    test('stage1 evolves to 2 at xp 45', () {
      final s = GameState()
        ..stage = 1
        ..xp = 44;
      expect(s.evolveCheck(), isNull);
      s.xp = 45;
      expect(s.evolveCheck(), 2);
    });

    test('stage2 evolves to 3 at xp 120', () {
      final s = GameState()
        ..stage = 2
        ..xp = 119;
      expect(s.evolveCheck(), isNull);
      s.xp = 120;
      expect(s.evolveCheck(), 3);
    });

    test('stage3 evolves to king(4) at xp 240', () {
      final s = GameState()
        ..stage = 3
        ..xp = 239;
      expect(s.evolveCheck(), isNull);
      s.xp = 240;
      expect(s.evolveCheck(), kingStage);
    });

    test('egg and king never evolve', () {
      expect((GameState()..xp = 999).evolveCheck(), isNull);
      expect(
        (GameState()
              ..stage = kingStage
              ..xp = 999)
            .evolveCheck(),
        isNull,
      );
    });

    test('near-evolve glow starts 8 before stage2 and 12 before stage3', () {
      final s = GameState()..stage = 1;
      s.xp = 36;
      expect(s.nearEvolve, isFalse);
      s.xp = 37;
      expect(s.nearEvolve, isTrue);
      s
        ..stage = 2
        ..xp = 107;
      expect(s.nearEvolve, isFalse);
      s.xp = 108;
      expect(s.nearEvolve, isTrue);
      s
        ..stage = 3
        ..xp = 223;
      expect(s.nearEvolve, isFalse);
      s.xp = 224;
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

    test('lottery skips the current child and roster entries in progress', () {
      // キング前の「あたらしいたまご」解禁に伴い、いま育てている子と
      // 名簿で続きを待っている子の種族は抽選しない(上書き消失を防ぐ)。
      final s = GameState()..species = 1;
      s.roster[2] = CreatureSnapshot(
        stage: 1,
        xp: 10,
        eggTaps: 3,
        hunger: 80,
        happy: 80,
        color: 0,
      );
      for (var i = 0; i < 60; i++) {
        final next = s.nextEggSpecies(Random(i));
        expect(next, isNot(1), reason: 'いまの子は引かない');
        expect(next, isNot(2), reason: '名簿で待っている子は引かない');
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
      expect(
        restored.collection,
        List.generate(speciesList.length, (i) => i == 0 || i == 2),
      );
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

    test('roundtrips items beyond bit 31 (web-safe encoding)', () {
      // docs/review-findings.md #21: dart2js はビット演算を32bitに切り詰める
      // ため、int のシフトで組むと index 32 以降の所持品が Web で壊れる。
      // このテストは `flutter test --platform chrome` でも通ること。
      expect(
        shopItems.length,
        greaterThan(32),
        reason: 'the regression needs an item beyond bit 31',
      );
      final s = GameState()
        ..owned = {shopItems.first.key, shopItems[31].key, shopItems.last.key};
      final restored = GameState();
      expect(restored.loadCode(s.makeCode()), isTrue);
      expect(restored.owned, {
        shopItems.first.key,
        shopItems[31].key,
        shopItems.last.key,
      });
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

    test(
      'a single malformed roster entry does not wipe the rest of the save',
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
      },
    );

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

  group(
    'offline decay / loadJson clamping (docs/review-findings.md #3, #4)',
    () {
      test(
        'applyOfflineDecay never raises stats when the clock moves backward',
        () {
          final s = GameState()
            ..hunger = 50
            ..happy = 50
            ..lastSavedMs = DateTime.now().millisecondsSinceEpoch + 60000; // 未来
          s.applyOfflineDecay();
          expect(s.hunger, 50); // 増えない
          expect(s.happy, 50);
        },
      );

      test('applyOfflineDecay clamps to the documented upper bound', () {
        final s = GameState()
          ..hunger =
              200 // 何らかの理由で範囲外になっていた場合
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
        expect(restored.stage, inInclusiveRange(0, kingStage));
        expect(restored.xp, greaterThanOrEqualTo(0));
        expect(restored.coins, greaterThanOrEqualTo(0));
        expect(restored.hunger, inInclusiveRange(0, 100));
        expect(restored.happy, inInclusiveRange(0, 100));
      });
    },
  );

  group('5-stage migration (stage 3 was king before v2)', () {
    test('legacy save (no schema version) promotes king 3 -> 4', () {
      final restored = GameState()..loadJson({'stage': 3});
      expect(restored.stage, kingStage);
      // 名簿のキングも同様に引き上げる
      final withRoster = GameState()
        ..loadJson({
          'stage': 1,
          'v': null,
          'roster': {
            '2': {'stage': 3, 'color': 0},
          },
        });
      expect(withRoster.roster[2]?.stage, kingStage);
    });

    test('v2 save keeps stage 3 as the new pre-king stage', () {
      final s = GameState()..stage = 3;
      final restored = GameState()..loadJson(s.toJson());
      expect(restored.stage, 3);
    });

    test('v1 あいことば promotes king 3 -> 4, v2 keeps stages as-is', () {
      // v1 コードを手作り(現行 makeCode は v2 を出すため)
      String v1Code(int stage) {
        final body = [1, stage, 0, 10, 80, 80, 0, 0, 0, -1, -1].join(',');
        var sum = 0;
        for (final c in body.codeUnits) {
          sum = (sum + c) % 97;
        }
        final b64 = base64Encode(
          utf8.encode('$body;$sum'),
        ).replaceAll(RegExp(r'=+$'), '');
        return 'MOKO-$b64';
      }

      final legacyKing = GameState();
      expect(legacyKing.loadCode(v1Code(3)), isTrue);
      expect(legacyKing.stage, kingStage);

      final legacyMid = GameState();
      expect(legacyMid.loadCode(v1Code(2)), isTrue);
      expect(legacyMid.stage, 2);

      final v2 = GameState()..stage = 3;
      final restored = GameState();
      expect(restored.loadCode(v2.makeCode()), isTrue);
      expect(restored.stage, 3);
    });
  });

  group('corrupt save restore (docs/review-findings.md #17)', () {
    test('loadJson clamps out-of-range species even when color is missing', () {
      // species 範囲外 + color 欠落: 修正前は speciesList[species] が投げ、
      // SaveStore.load() の catch でセーブ全体が初期化される全損経路だった。
      final restored = GameState()..loadJson({'species': 99});
      expect(restored.species, inInclusiveRange(0, speciesList.length - 1));
      expect(restored.currentSpecies, isNotNull); // RangeError を投げない
      restored.loadJson({'species': -1});
      expect(restored.species, inInclusiveRange(0, speciesList.length - 1));
    });

    test('loadJson drops an out-of-range bg back to the species default', () {
      final restored = GameState()..loadJson({'bg': 99});
      expect(restored.bg, isNull);
      expect(restored.effectiveBg, inInclusiveRange(0, bgThemes.length - 1));
      restored.loadJson({'bg': -1});
      expect(restored.bg, isNull);
    });

    test('loadJson clamps kingSparkle and eggTaps', () {
      // docs/review-findings.md #48: クランプ方針から漏れていた2フィールド。
      final restored = GameState()
        ..loadJson({'kingSparkle': 999, 'eggTaps': -5});
      expect(restored.kingSparkle, inInclusiveRange(0, 100));
      expect(restored.eggTaps, greaterThanOrEqualTo(0));
      final low = GameState()..loadJson({'kingSparkle': -50});
      expect(low.kingSparkle, inInclusiveRange(0, 100));
    });

    test('CreatureSnapshot.fromJson clamps kingSparkle and eggTaps', () {
      final snap = CreatureSnapshot.fromJson({
        'color': 0,
        'kingSparkle': 999,
        'eggTaps': -3,
      });
      expect(snap.kingSparkle, inInclusiveRange(0, 100));
      expect(snap.eggTaps, greaterThanOrEqualTo(0));
    });

    test('loadJson drops a pattern that is not valid base64', () {
      // docs/review-findings.md #43: 不正な base64 はホーム/おえかきの
      // base64Decode で同期例外になり起動クラッシュループを起こす。
      final restored = GameState()..loadJson({'pattern': '!!!ではない!!!'});
      expect(restored.pattern, isNull);
      // 正しい base64 は保持される
      final ok = GameState()..loadJson({'pattern': 'aGVsbG8='});
      expect(ok.pattern, 'aGVsbG8=');
    });

    test(
      'CreatureSnapshot.fromJson drops a pattern that is not valid base64',
      () {
        final snap = CreatureSnapshot.fromJson({'pattern': '***', 'color': 0});
        expect(snap.pattern, isNull);
      },
    );

    test(
      'CreatureSnapshot.fromJson clamps stage/hunger/happy and drops bad bg',
      () {
        final snap = CreatureSnapshot.fromJson({
          'stage': 9,
          'hunger': 500,
          'happy': -20,
          'color': 0,
          'bg': 99,
        });
        // switchCreature が snap をそのまま state に流すため、ここで正規化する。
        expect(snap.stage, inInclusiveRange(0, kingStage));
        expect(snap.hunger, inInclusiveRange(0, 100));
        expect(snap.happy, inInclusiveRange(0, 100));
        expect(snap.bg, isNull);
      },
    );
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
        isFalse,
      );
    });
  });
}

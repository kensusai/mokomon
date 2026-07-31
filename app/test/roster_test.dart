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
    ..stage = kingStage
    ..species = 0
    ..xp = 99
    ..color = 0xFF112233
    ..pattern = 'moko-pattern'
    ..owned = {'ribbon', 'sunglass'}
    ..equipHead = 'ribbon'
    ..nickname = 'モコタン'
    ..collection = (List.filled(speciesList.length, false)..[0] = true);

  CreatureSnapshot snapOf(int species, {int stage = kingStage, String? name}) =>
      CreatureSnapshot(
        species: species,
        stage: stage,
        xp: 0,
        eggTaps: 0,
        hunger: 80,
        happy: 80,
        color: speciesList[species].color.toARGB32(),
        nickname: name,
      );

  group('newEgg snapshots the departing king (docs/game-design.md §12)', () {
    test('roster keeps species, look, equipment, and nickname', () {
      final c = fresh(kingMoko());
      c.newEgg();
      final snap = c.state.roster.single;
      expect(snap.species, 0);
      expect(snap.stage, kingStage);
      expect(snap.color, 0xFF112233);
      expect(snap.pattern, 'moko-pattern');
      expect(snap.equipHead, 'ribbon');
      expect(snap.nickname, 'モコタン');
      // 新しいたまごは無名で始まる
      expect(c.state.nickname, isNull);
    });

    test('a second individual of the same species does not overwrite', () {
      // こどもFB: 全種コンプ後のだぶり卵で古い子が消えていた回帰テスト。
      final s = kingMoko()..roster = [snapOf(0, name: '先代モコ')];
      final c = fresh(s);
      c.newEgg();
      final mokos = s.roster.where((r) => r.species == 0).toList();
      expect(mokos, hasLength(2));
      expect(mokos.map((r) => r.nickname), containsAll(['先代モコ', 'モコタン']));
    });
  });

  group('equipment is per-individual (docs/review-findings.md #67)', () {
    test('a new egg starts without the previous child\'s equipment', () {
      final s = kingMoko()..equipFace = 'sunglass';
      final c = fresh(s);
      c.newEgg();
      expect(s.equipHead, isNull);
      expect(s.equipFace, isNull);
      expect(s.roster.last.equipHead, 'ribbon', reason: '装備は個体の記憶として名簿へ');
      expect(s.roster.last.equipFace, 'sunglass');
    });

    test('an adopted king arrives without borrowed equipment', () {
      final s = kingMoko()
        ..collection = (List.filled(speciesList.length, false)
          ..[0] = true
          ..[1] = true);
      final c = fresh(s);
      expect(c.adoptKing(1), isTrue);
      expect(s.equipHead, isNull);
      expect(s.equipFace, isNull);
    });
  });

  group('switchToRoster', () {
    test('swaps to a raised king and back, preserving each look', () {
      final s = kingMoko();
      final c = fresh(s);
      c.newEgg(); // モコタンが roster へ、新しいたまごが来る
      final newSpecies = s.species;
      expect(newSpecies, isNot(0));

      expect(c.switchToRoster(0), isTrue);
      expect(s.species, 0);
      expect(s.stage, kingStage);
      expect(s.equipHead, 'ribbon');
      expect(s.nickname, 'モコタン');
      expect(s.pattern, 'moko-pattern');
      // 育てかけのたまごも roster に退避されている
      final egg = s.roster.singleWhere((r) => r.species == newSpecies);
      expect(egg.stage, 0);

      // もう一度戻すと、たまごの続きから
      expect(c.switchToRoster(s.roster.indexOf(egg)), isTrue);
      expect(s.species, newSpecies);
      expect(s.stage, 0);
      expect(s.nickname, isNull);
    });

    test('can swap between two individuals of the same species', () {
      final s = kingMoko()..roster = [snapOf(0, stage: 1, name: '2だいめ')];
      final c = fresh(s);
      expect(c.switchToRoster(0), isTrue);
      expect(s.species, 0);
      expect(s.stage, 1);
      expect(s.nickname, '2だいめ');
      // モコタンは名簿で待っている
      final waiting = s.roster.singleWhere((r) => r.nickname == 'モコタン');
      expect(waiting.stage, kingStage);
    });

    test('refuses an out-of-range index', () {
      final c = fresh(kingMoko());
      expect(c.switchToRoster(0), isFalse);
      expect(c.switchToRoster(-1), isFalse);
    });
  });

  group('adoptKing (ずかん登録ずみ・名簿に個体がいない種族)', () {
    test('brings a fresh king and stashes the current child', () {
      final s = kingMoko()
        ..species = 1
        ..stage = 1
        ..nickname = null
        ..pattern = null
        ..equipHead = null;
      final c = fresh(s);
      expect(c.adoptKing(0), isTrue);
      expect(s.species, 0);
      expect(s.stage, kingStage);
      final stashed = s.roster.single;
      expect(stashed.species, 1);
      expect(stashed.stage, 1);
    });

    test('refuses current species, unowned, and roster-covered species', () {
      final s = kingMoko()..roster = [snapOf(0)];
      s.collection[2] = true;
      final c = fresh(s);
      expect(c.adoptKing(0), isFalse); // 現在の種族
      expect(c.adoptKing(1), isFalse); // 未入手
      final s2 = kingMoko()
        ..species = 2
        ..roster = [snapOf(0)];
      final c2 = fresh(s2);
      expect(c2.adoptKing(0), isFalse); // 名簿に個体がいる(そちらを選ぶ)
    });
  });

  group('farewell replace (こどもFB: いっぱいなら選んでおわかれ)', () {
    test('needsFarewell only when no drawable species remain', () {
      // 未入手種族が残っていれば通常抽選
      expect(kingMoko().needsFarewell, isFalse);

      // 金のたまご(3体キング)が控えているあいだは不要
      final golden = GameState()..species = 0;
      golden.collection[0] = true;
      golden.collection[1] = true;
      golden.collection[2] = true;
      for (var i = 4; i < speciesList.length; i++) {
        golden.roster.add(snapOf(i));
      }
      expect(golden.needsFarewell, isFalse);

      // 全種族が手元(いまの子+名簿)にいる → おわかれが必要
      final full = kingMoko();
      full.collection = List.filled(speciesList.length, true);
      for (var i = 1; i < speciesList.length; i++) {
        full.roster.add(snapOf(i));
      }
      expect(full.needsFarewell, isTrue);
    });

    test('newEggReplacing releases the chosen one and brings its species', () {
      final s = kingMoko()
        ..roster = [snapOf(1, name: 'ぴょんた'), snapOf(2, name: 'とげすけ')];
      final c = fresh(s);
      final released = c.newEggReplacing(0); // ぴょんた と おわかれ
      expect(released, 1);
      expect(s.species, 1); // 同じ種族のたまごが来る
      expect(s.stage, 0);
      expect(s.nickname, isNull);
      // ぴょんた は消え、とげすけ と 退避したモコタン が残る
      expect(s.roster.map((r) => r.nickname), isNot(contains('ぴょんた')));
      expect(s.roster.map((r) => r.nickname), containsAll(['とげすけ', 'モコタン']));
    });

    test('newEggReplacing refuses an out-of-range index', () {
      final c = fresh(kingMoko());
      expect(c.newEggReplacing(0), isNull);
      expect(c.state.stage, kingStage); // 何も起きない
    });
  });

  group('roster persistence', () {
    test('survives json roundtrip with duplicate species', () {
      final s = kingMoko()..roster = [snapOf(0, name: '先代モコ')];
      final c = fresh(s);
      c.newEgg();
      final restored = GameState()..loadJson(c.state.toJson());
      final mokos = restored.roster.where((r) => r.species == 0).toList();
      expect(mokos, hasLength(2));
      expect(mokos.map((r) => r.nickname), containsAll(['先代モコ', 'モコタン']));
      final taro = mokos.singleWhere((r) => r.nickname == 'モコタン');
      expect(taro.equipHead, 'ribbon');
      expect(taro.pattern, 'moko-pattern');
    });

    test('migrates the legacy per-species map format', () {
      final json = kingMoko().toJson();
      json['roster'] = {
        '2': {
          'stage': kingStage,
          'xp': 1.0,
          'eggTaps': 0,
          'hunger': 80.0,
          'happy': 80.0,
          'color': 0xFF445566,
          'nickname': 'とげすけ',
        },
      };
      final restored = GameState()..loadJson(json);
      final snap = restored.roster.single;
      expect(snap.species, 2);
      expect(snap.stage, kingStage);
      expect(snap.nickname, 'とげすけ');
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

    test('caps at 10 chars without splitting an emoji surrogate pair', () {
      // docs/review-findings.md #14: 絵文字がちょうど10文字目に来ても壊れない。
      final c = fresh(GameState()..stage = 1);
      c.rename('あいうえおかきくけ😺こさし'); // 9文字+絵文字+3文字=13文字
      expect(c.state.nickname, 'あいうえおかきくけ😺');
      expect(c.state.nickname!.runes.length, 10);
    });
  });
}

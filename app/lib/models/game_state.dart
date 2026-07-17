import 'dart:convert';
import 'dart:math';

import '../data/items.dart';
import '../data/species.dart';

/// 進化しきい値(隠しパラメータ)。docs/game-design.md §3。
const evolveXp = [0, 30, 80];

/// ゲーム状態。プロトタイプの `S` オブジェクトに対応。
class GameState {
  int stage = 0; // 0=たまご 1=ベビー 2=中間 3=キング
  double xp = 0;
  int coins = 10;
  double hunger = 80;
  double happy = 80;
  int eggTaps = 0;
  int species = 0;
  List<bool> collection = List.filled(speciesList.length, false);
  Set<String> owned = {};
  String? equipHead;
  String? equipFace;
  bool sound = true;

  /// 選択中のBGMトラック(端末ローカル設定・あいことばに含めない)。
  int bgmTrack = 0;
  int lastSavedMs = 0;

  /// 体色(ARGB)。おえかき画面で変更でき、種族と独立に保持する。
  int color = speciesList[0].color.toARGB32();

  /// お絵かき模様(PNG の base64)。端末ローカルのみ・あいことばに含めない。
  String? pattern;

  Species get currentSpecies => speciesList[species];
  String get displayName =>
      '${currentSpecies.emojis[stage]} ${currentSpecies.names[stage]}';

  bool get isSad => hunger < 30 || happy < 30;

  /// 進化予兆(金色グロー)。数値は絶対にUIに出さないこと。
  bool get nearEvolve =>
      (stage == 1 && xp >= evolveXp[1] - 8) ||
      (stage == 2 && xp >= evolveXp[2] - 12);

  /// 進化可能なら次のstageを返す(演出はUI側で)。
  int? evolveCheck() {
    if (stage == 1 && xp >= evolveXp[1]) return 2;
    if (stage == 2 && xp >= evolveXp[2]) return 3;
    return null;
  }

  /// 新しいたまごの種族を決める。docs/game-design.md §4。
  int nextEggSpecies(Random rng) {
    final normals = [
      for (var i = 0; i < speciesList.length; i++)
        if (i != secretSpeciesIndex) i
    ];
    final kinged = normals.where((i) => collection[i]).length;
    if (!collection[secretSpeciesIndex] && kinged >= 3) {
      return secretSpeciesIndex; // 金のたまご(最優先)
    }
    final unowned = normals.where((i) => !collection[i]).toList();
    if (unowned.isNotEmpty) return unowned[rng.nextInt(unowned.length)];
    final pool = [
      for (var i = 0; i < speciesList.length; i++)
        if (i != species) i
    ];
    return pool[rng.nextInt(pool.length)];
  }

  /// オフライン減衰。復帰時に一度だけ呼ぶ。
  void applyOfflineDecay() {
    if (lastSavedMs == 0) return;
    final mins =
        (DateTime.now().millisecondsSinceEpoch - lastSavedMs) / 60000.0;
    hunger = max(15, hunger - min(50, mins / 3));
    happy = max(20, happy - min(40, mins / 4));
  }

  // ---------- 直列化(保存自体は data/save_store.dart) ----------

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'xp': xp,
        'coins': coins,
        'hunger': hunger,
        'happy': happy,
        'eggTaps': eggTaps,
        'species': species,
        'collection': collection,
        'owned': owned.toList(),
        'equipHead': equipHead,
        'equipFace': equipFace,
        'sound': sound,
        'bgmTrack': bgmTrack,
        'color': color,
        'pattern': pattern,
        'last': DateTime.now().millisecondsSinceEpoch,
      };

  void loadJson(Map<String, dynamic> j) {
    stage = j['stage'] ?? 0;
    xp = (j['xp'] ?? 0).toDouble();
    coins = j['coins'] ?? 10;
    hunger = (j['hunger'] ?? 80).toDouble();
    happy = (j['happy'] ?? 80).toDouble();
    eggTaps = j['eggTaps'] ?? 0;
    species = j['species'] ?? 0;
    final col = (j['collection'] as List?)?.cast<bool>() ?? [];
    collection = List.generate(
        speciesList.length, (i) => i < col.length ? col[i] : false);
    owned = ((j['owned'] as List?)?.cast<String>() ?? []).toSet();
    equipHead = j['equipHead'];
    equipFace = j['equipFace'];
    sound = j['sound'] ?? true;
    bgmTrack = j['bgmTrack'] ?? 0;
    color = j['color'] ?? speciesList[species].color.toARGB32();
    pattern = j['pattern'];
    lastSavedMs = j['last'] ?? 0;
  }

  // ---------- あいことば(パスワード)。docs/game-design.md §8 ----------

  String makeCode() {
    var colBits = 0;
    for (var i = 0; i < collection.length; i++) {
      if (collection[i]) colBits |= 1 << i;
    }
    var ownBits = 0;
    for (var i = 0; i < shopItems.length; i++) {
      if (owned.contains(shopItems[i].key)) ownBits |= 1 << i;
    }
    final eqH = shopItems.indexWhere((it) => it.key == equipHead);
    final eqF = shopItems.indexWhere((it) => it.key == equipFace);
    final body = [
      1,
      stage,
      xp.round(),
      coins,
      hunger.round(),
      happy.round(),
      species,
      colBits,
      ownBits,
      eqH,
      eqF,
    ].join(',');
    var sum = 0;
    for (final c in body.codeUnits) {
      sum = (sum + c) % 97;
    }
    final b64 =
        base64Encode(utf8.encode('$body;$sum')).replaceAll(RegExp(r'=+$'), '');
    return 'MOKO-$b64';
  }

  bool loadCode(String input) {
    try {
      var s = input.trim().replaceAll(RegExp(r'\s'), '');
      if (s.toUpperCase().startsWith('MOKO-')) s = s.substring(5);
      while (s.length % 4 != 0) {
        s += '=';
      }
      final raw = utf8.decode(base64Decode(s));
      final parts = raw.split(';');
      if (parts.length != 2) return false;
      var sum = 0;
      for (final c in parts[0].codeUnits) {
        sum = (sum + c) % 97;
      }
      if ('$sum' != parts[1]) return false;
      final a = parts[0].split(',').map(int.parse).toList();
      if (a.length < 11 || a[0] != 1) return false;
      stage = a[1].clamp(0, 3);
      xp = max(0, a[2]).toDouble();
      coins = max(0, a[3]);
      hunger = a[4].clamp(0, 100).toDouble();
      happy = a[5].clamp(0, 100).toDouble();
      species = a[6].clamp(0, speciesList.length - 1);
      collection =
          List.generate(speciesList.length, (i) => (a[7] & (1 << i)) != 0);
      owned = {
        for (var i = 0; i < shopItems.length; i++)
          if ((a[8] & (1 << i)) != 0) shopItems[i].key
      };
      equipHead = (a[9] >= 0 &&
              a[9] < shopItems.length &&
              owned.contains(shopItems[a[9]].key))
          ? shopItems[a[9]].key
          : null;
      equipFace = (a[10] >= 0 &&
              a[10] < shopItems.length &&
              owned.contains(shopItems[a[10]].key))
          ? shopItems[a[10]].key
          : null;
      eggTaps = 0;
      // 模様はあいことばに含まれない(仕様§8)。体色も種族の初期色へ戻す
      pattern = null;
      color = speciesList[species].color.toARGB32();
      return true;
    } catch (_) {
      return false;
    }
  }
}

import 'dart:convert';
import 'dart:math';

import '../data/backgrounds.dart';
import '../data/items.dart';
import '../data/species.dart';

/// 進化しきい値(隠しパラメータ)。docs/game-design.md §3。
const evolveXp = [0, 30, 80];

/// 保存データ由来の背景 index。範囲外は null(=種族デフォルト)に落とす。
/// 素通しすると `bgThemes[effectiveBg]` が毎フレーム RangeError になる
/// (docs/review-findings.md #17)。
int? _validBg(Object? v) =>
    v is int && v >= 0 && v < bgThemes.length ? v : null;

/// 保存データ由来の模様(base64 PNG)。base64 として不正なら null(=模様なし)
/// に落とす。素通しするとホーム/おえかきの `base64Decode` が起動のたびに
/// 同期例外を投げる(docs/review-findings.md #43)。
String? _validPattern(Object? v) {
  if (v is! String) return null;
  try {
    base64Decode(v);
    return v;
  } catch (_) {
    return null;
  }
}

/// ずかんの「名簿」に保存する個体スナップショット(docs/game-design.md §12)。
/// 交代・新しいたまごの際に、見た目ときせかえ・なまえを保持する。
class CreatureSnapshot {
  int stage;
  double xp;
  int eggTaps;
  double hunger;
  double happy;
  int color;
  String? pattern;
  String? equipHead;
  String? equipFace;
  String? nickname;
  int? bg;
  double kingSparkle;

  CreatureSnapshot({
    required this.stage,
    required this.xp,
    required this.eggTaps,
    required this.hunger,
    required this.happy,
    required this.color,
    this.pattern,
    this.equipHead,
    this.equipFace,
    this.nickname,
    this.bg,
    this.kingSparkle = 0,
  });

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'xp': xp,
        'eggTaps': eggTaps,
        'hunger': hunger,
        'happy': happy,
        'color': color,
        'pattern': pattern,
        'equipHead': equipHead,
        'equipFace': equipFace,
        'nickname': nickname,
        'bg': bg,
        'kingSparkle': kingSparkle,
      };

  /// 壊れた値は範囲内へ正規化する。`switchCreature` がスナップショットを
  /// そのまま state に流すため、ここが最後の防波堤(docs/review-findings.md #17)。
  factory CreatureSnapshot.fromJson(Map<String, dynamic> j) => CreatureSnapshot(
        stage: ((j['stage'] ?? 3) as int).clamp(0, 3),
        xp: max(0, ((j['xp'] ?? 0) as num).toDouble()),
        eggTaps: max(0, (j['eggTaps'] ?? 0) as int),
        hunger:
            ((j['hunger'] ?? 80) as num).toDouble().clamp(0, 100).toDouble(),
        happy: ((j['happy'] ?? 80) as num).toDouble().clamp(0, 100).toDouble(),
        color: (j['color'] ?? 0) as int,
        pattern: _validPattern(j['pattern']),
        equipHead: j['equipHead'] as String?,
        equipFace: j['equipFace'] as String?,
        nickname: j['nickname'] as String?,
        bg: _validBg(j['bg']),
        kingSparkle: ((j['kingSparkle'] ?? 0) as num)
            .toDouble()
            .clamp(0, 100)
            .toDouble(),
      );
}

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

  /// いまの子のニックネーム(なければ種族名)。端末ローカルのみ。
  String? nickname;

  /// 背景テーマ(bgThemes index)。null は種族デフォルト。端末ローカルのみ。
  int? bg;

  /// 購入ずみの背景テーマ(bgThemes の key、無料テーマは含めない)。
  /// 端末ローカル・全個体共通(あいことばには含めない)。
  Set<String> ownedBg = {};

  /// キングのきらきらゲージ(0-100)。満タンでおみやげ。docs §14。
  double kingSparkle = 0;

  /// おみやげで解放された限定スタンプ(端末ローカル・全個体共通)。
  Set<String> unlockedStamps = {};

  /// 実際に表示する背景(選択がなければ種族デフォルト)。
  int get effectiveBg => bg ?? speciesDefaultBg[species];

  /// その背景テーマを選べる状態か(無料、または購入ずみ)。
  bool ownsBg(int index) =>
      bgThemes[index].free || ownedBg.contains(bgThemes[index].key);

  /// 過去に育てた子の名簿(species index → スナップショット)。端末ローカルのみ。
  Map<int, CreatureSnapshot> roster = {};

  /// お絵かき模様(PNG の base64)。端末ローカルのみ・あいことばに含めない。
  String? pattern;

  Species get currentSpecies => speciesList[species];
  String get displayName =>
      '${currentSpecies.emojis[stage]} ${nickname ?? currentSpecies.names[stage]}';

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
        if (i != secretSpeciesIndex) i,
    ];
    final kinged = normals.where((i) => collection[i]).length;
    if (!collection[secretSpeciesIndex] && kinged >= 3) {
      return secretSpeciesIndex; // 金のたまご(最優先)
    }
    final unowned = normals.where((i) => !collection[i]).toList();
    if (unowned.isNotEmpty) return unowned[rng.nextInt(unowned.length)];
    final pool = [
      for (var i = 0; i < speciesList.length; i++)
        if (i != species) i,
    ];
    return pool[rng.nextInt(pool.length)];
  }

  /// オフライン減衰。復帰時に一度だけ呼ぶ。
  void applyOfflineDecay() {
    if (lastSavedMs == 0) return;
    // 端末の時計が巻き戻っていても増加側には振れないようにする
    final mins = max(
      0.0,
      (DateTime.now().millisecondsSinceEpoch - lastSavedMs) / 60000.0,
    );
    hunger = max(15, hunger - min(50, mins / 3)).clamp(0, 100).toDouble();
    happy = max(20, happy - min(40, mins / 4)).clamp(0, 100).toDouble();
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
        'nickname': nickname,
        'bg': bg,
        'ownedBg': ownedBg.toList(),
        'kingSparkle': kingSparkle,
        'unlockedStamps': unlockedStamps.toList(),
        'roster': {
          for (final e in roster.entries) '${e.key}': e.value.toJson()
        },
        'last': DateTime.now().millisecondsSinceEpoch,
      };

  void loadJson(Map<String, dynamic> j) {
    stage = ((j['stage'] ?? 0) as int).clamp(0, 3);
    xp = max(0, ((j['xp'] ?? 0) as num).toDouble());
    coins = max(0, (j['coins'] ?? 10) as int);
    hunger = ((j['hunger'] ?? 80) as num).toDouble().clamp(0, 100).toDouble();
    happy = ((j['happy'] ?? 80) as num).toDouble().clamp(0, 100).toDouble();
    eggTaps = max(0, (j['eggTaps'] ?? 0) as int);
    // 範囲外の species は後続の speciesList[species] が投げ、SaveStore.load()
    // の catch でセーブ全体が初期化されてしまう(docs/review-findings.md #17)
    species = ((j['species'] ?? 0) as int).clamp(0, speciesList.length - 1);
    final col = (j['collection'] as List?)?.cast<bool>() ?? [];
    collection = List.generate(
      speciesList.length,
      (i) => i < col.length ? col[i] : false,
    );
    owned = ((j['owned'] as List?)?.cast<String>() ?? []).toSet();
    equipHead = j['equipHead'] as String?;
    equipFace = j['equipFace'] as String?;
    sound = (j['sound'] ?? true) as bool;
    bgmTrack = (j['bgmTrack'] ?? 0) as int;
    color = (j['color'] ?? speciesList[species].color.toARGB32()) as int;
    pattern = _validPattern(j['pattern']);
    nickname = j['nickname'] as String?;
    bg = _validBg(j['bg']);
    ownedBg = ((j['ownedBg'] as List?)?.cast<String>() ?? []).toSet();
    kingSparkle =
        ((j['kingSparkle'] ?? 0) as num).toDouble().clamp(0, 100).toDouble();
    unlockedStamps =
        ((j['unlockedStamps'] as List?)?.cast<String>() ?? []).toSet();
    // 壊れたエントリが1つあっても、他のセーブデータは失わない
    // (docs/review-findings.md #1)。
    roster = {};
    for (final e in ((j['roster'] as Map?) ?? {}).entries) {
      try {
        roster[int.parse(e.key as String)] = CreatureSnapshot.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        // このエントリだけスキップする
      }
    }
    lastSavedMs = (j['last'] ?? 0) as int;
  }

  // ---------- あいことば(パスワード)。docs/game-design.md §8 ----------

  String makeCode() {
    // ビット列は BigInt で組む。dart2js は int のビット演算を32bitに切り詰める
    // ため、int のままだと index 32 以降の図鑑/所持品が Web で壊れる
    // (docs/review-findings.md #21)。10進文字列になるので形式は従来と同一。
    var colBits = BigInt.zero;
    for (var i = 0; i < collection.length; i++) {
      if (collection[i]) colBits |= BigInt.one << i;
    }
    var ownBits = BigInt.zero;
    for (var i = 0; i < shopItems.length; i++) {
      if (owned.contains(shopItems[i].key)) ownBits |= BigInt.one << i;
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
    final b64 = base64Encode(
      utf8.encode('$body;$sum'),
    ).replaceAll(RegExp(r'=+$'), '');
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
      final f = parts[0].split(',');
      if (f.length < 11 || f[0] != '1') return false;
      final a = [for (final x in f.take(7)) int.parse(x)];
      stage = a[1].clamp(0, 3);
      xp = max(0, a[2]).toDouble();
      coins = max(0, a[3]);
      hunger = a[4].clamp(0, 100).toDouble();
      happy = a[5].clamp(0, 100).toDouble();
      species = a[6].clamp(0, speciesList.length - 1);
      // ビット列は makeCode と同じ理由で BigInt として読む。int.parse だと
      // Web では 2^53 超で精度が落ち、ビット演算は32bitに切り詰められる。
      final colBits = BigInt.parse(f[7]);
      final ownBits = BigInt.parse(f[8]);
      collection = List.generate(
        speciesList.length,
        (i) => (colBits >> i).isOdd,
      );
      owned = {
        for (var i = 0; i < shopItems.length; i++)
          if ((ownBits >> i).isOdd) shopItems[i].key,
      };
      final eqH = int.parse(f[9]);
      final eqF = int.parse(f[10]);
      equipHead = (eqH >= 0 &&
              eqH < shopItems.length &&
              owned.contains(shopItems[eqH].key))
          ? shopItems[eqH].key
          : null;
      equipFace = (eqF >= 0 &&
              eqF < shopItems.length &&
              owned.contains(shopItems[eqF].key))
          ? shopItems[eqF].key
          : null;
      eggTaps = 0;
      // 模様・なまえ・背景・ゲージはあいことばに含まれない(仕様§8)
      pattern = null;
      nickname = null;
      bg = null;
      kingSparkle = 0;
      color = speciesList[species].color.toARGB32();
      return true;
    } catch (_) {
      return false;
    }
  }
}

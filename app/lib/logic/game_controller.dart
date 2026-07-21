import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/sfx_player.dart';
import '../audio/sound_synth.dart';
import '../data/backgrounds.dart';
import '../data/foods.dart';
import '../data/items.dart';
import '../data/save_store.dart';
import '../data/species.dart';
import '../models/game_state.dart';

/// たまごタップの結果。3タップ目で孵化する(docs/game-design.md §4)。
enum EggTapOutcome { crack, hatched }

/// いきもの(またはたまご)をタップした結果。UIは演出だけを担当する。
enum CreatureTapOutcome { crack, hatched, petted, puffed }

/// ショップのセルをタップした結果(docs/game-design.md §7)。
enum ShopTapOutcome { bought, equipped, unequipped, notEnoughCoins }

/// ごはんの結果。失敗理由を UI 側で区別できるよう enum で返す
/// (docs/review-findings.md #52)。
enum FeedOutcome { fed, full, notEnoughCoins }

/// 背景セルをタップした結果(docs/game-design.md §13)。
enum BgTapOutcome { selected, bought, notEnoughCoins }

/// キングのおみやげ(docs/game-design.md §14)。
/// [stamp] があれば限定スタンプ解放、なければ [coins] をもらう。
class KingGift {
  final String? stamp;
  final int coins;
  const KingGift({this.stamp, this.coins = 0});
}

/// おみやげで順に解放される限定スタンプ。
const kingGiftStamps = ['👑', '🎆', '🦄'];

/// ミニゲームで「すごいスコア」とみなすコイン数(勝利曲が流れる)。
const bigScoreCoins = 20;

/// ユースケース層: ゲーム操作とその副作用(通知・保存)をまとめる。
/// UI は本クラス経由でのみ状態を変更する。
class GameController extends ChangeNotifier {
  /// [sfx] はテスト専用: 偽 AudioPlayer を仕込んだ [SfxPlayer] を注入して
  /// 再生内容を検証できる(docs/review-findings.md #22)。
  GameController(this.state, this._store, {Random? rng, SfxPlayer? sfx})
      : _rng = rng ?? Random(),
        _sfxOverride = sfx;

  final GameState state;
  final SaveStore _store;
  final Random _rng;
  final SfxPlayer? _sfxOverride;
  Timer? _decayTimer;

  /// 効果音(ミュート・BGM選択は state を参照)。
  late final SfxPlayer sfx = _sfxOverride ??
      SfxPlayer(enabled: () => state.sound, bgmTrack: () => state.bgmTrack);

  /// アプリ起動中の減衰(10秒ごと)。docs/game-design.md §3。
  void startDecayTimer() {
    _decayTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => decayTick(),
    );
  }

  void decayTick() {
    if (state.stage == 0) return; // たまご中は減衰なし
    state.hunger = max(0, state.hunger - 0.6);
    state.happy = max(0, state.happy - 0.35);
    _commit();
  }

  /// たまごをタップ。2回まではヒビ、3回目で孵化(xp=5で開始)。
  EggTapOutcome tapEgg() {
    state.eggTaps++;
    if (state.eggTaps >= 3) {
      state.stage = 1;
      state.xp = 5;
      _commit();
      return EggTapOutcome.hatched;
    }
    sfx.play(Sfx.tap);
    _commit();
    return EggTapOutcome.crack;
  }

  /// なでなで: happy +3 / xp +1。タップすると種族の声でしゃべる。
  void pet() {
    state.happy = min(100, state.happy + 3);
    state.xp += 1;
    _addSparkle(10);
    sfx.playBabble(state.species);
    _commit();
  }

  /// いきものタップの一次判定。たまごなら孵化進行、
  /// 下部30%タップ or 6% で💨、それ以外はなでなで(docs/game-design.md §3, §9)。
  CreatureTapOutcome tapCreature({required bool lowerBody}) {
    if (state.stage == 0) {
      return tapEgg() == EggTapOutcome.hatched
          ? CreatureTapOutcome.hatched
          : CreatureTapOutcome.crack;
    }
    if (lowerBody || _rng.nextDouble() < 0.06) {
      puff();
      return CreatureTapOutcome.puffed;
    }
    pet();
    return CreatureTapOutcome.petted;
  }

  /// 💨(隠し機能・名前を付けない)。happy +2。docs/game-design.md §9。
  void puff() {
    state.happy = min(100, state.happy + 2);
    _addSparkle(6);
    sfx.play(Sfx.puff);
    _commit();
  }

  /// BGMを次の曲へ切り替える(選択は保存)。現在のトラック番号を返す。
  int cycleBgm() {
    state.bgmTrack = (state.bgmTrack + 1) % SfxPlayer.bgmTracks.length;
    sfx.restartBgm();
    _commit();
    return state.bgmTrack;
  }

  /// サウンドのミュートトグル(設定は保存される)。BGMも連動する。
  void toggleSound() {
    state.sound = !state.sound;
    sfx.play(Sfx.tap);
    sfx.syncBgm();
    _commit();
  }

  /// hunger≧98 は給餌不可(「おなかいっぱい」)。
  bool get isFull => state.hunger >= 98;

  /// ごはん。コイン不足・満腹なら何も変更せず理由を返す。
  /// 満腹ルールは UI(home_screen のヒント表示)に頼らずここでも強制する
  /// (docs/review-findings.md #38, #52)。
  FeedOutcome feed(Food food) {
    if (isFull) return FeedOutcome.full;
    if (state.coins < food.cost) return FeedOutcome.notEnoughCoins;
    state.coins -= food.cost;
    state.hunger = min(100, state.hunger + food.hunger);
    state.happy = min(100, state.happy + food.happy);
    state.xp += food.xp;
    _addSparkle(16);
    sfx.play(Sfx.munch);
    _commit();
    return FeedOutcome.fed;
  }

  /// ミニゲームクリアの共通報酬: コイン+獲得分、happy+12、xp+10。
  /// docs/game-design.md §5。
  void finishMinigame(int coins) {
    state.coins += coins;
    state.happy = min(100, state.happy + 12);
    state.xp += 10;
    _addSparkle(30);
    if (coins >= bigScoreCoins) {
      // すごいスコア! 勝利曲でお祝い(終わると元のBGMへ)
      sfx.playOverrideBgm(Sfx.victoryTune, loop: false);
    } else {
      sfx.playJingle(Sfx.rewardJingle); // 派手に(BGMは一時停止)
    }
    _commit();
  }

  /// ミニゲームでミスしすぎてゲームオーバーになったとき、コインを払って続行する。
  /// 払えたら true(呼び出し側でゲームのミス数をリセットすること)。
  bool payToContinue(int cost) {
    if (state.coins < cost) return false;
    state.coins -= cost;
    sfx.play(Sfx.coin);
    _commit();
    return true;
  }

  /// 進化を確定する。カットシーンのリビール時点で呼ぶこと
  /// (判定は state.evolveCheck())。キング到達でずかん登録。
  void applyEvolution(int newStage) {
    state.stage = newStage;
    if (newStage == 3) state.collection[state.species] = true;
    _commit();
  }

  /// 新しいたまごを迎える(抽選は docs/game-design.md §4)。
  /// いまのキングは名簿(roster)に保存され、あとで図鑑から呼び戻せる。
  int newEgg() {
    state.roster[state.species] = _snapshotCurrent();
    final next = state.nextEggSpecies(_rng);
    state
      ..species = next
      ..stage = 0
      ..eggTaps = 0
      ..xp = 0
      ..hunger = 80
      ..happy = 80
      ..pattern = null
      ..nickname = null
      ..bg = null
      ..kingSparkle = 0
      ..color = speciesList[next].color.toARGB32();
    _commit();
    return next;
  }

  /// 背景セルをタップ: 未購入(有料)なら購入して選択、
  /// 所持ずみ(無料テーマ含む)なら選択のみ。null で種族デフォルトに戻す(常に無料)。
  BgTapOutcome tapBackground(int? index) {
    if (index == null) {
      state.bg = null;
      sfx.play(Sfx.happy);
      _commit();
      return BgTapOutcome.selected;
    }
    final theme = bgThemes[index];
    if (!state.ownsBg(index)) {
      if (state.coins < theme.cost) {
        sfx.play(Sfx.wrong);
        return BgTapOutcome.notEnoughCoins;
      }
      state.coins -= theme.cost;
      state.ownedBg.add(theme.key);
      state.bg = index;
      sfx.play(Sfx.coin);
      sfx.playJingle(Sfx.dressUp); // きせかえと同じく派手に
      _commit();
      return BgTapOutcome.bought;
    }
    state.bg = index;
    sfx.play(Sfx.happy);
    _commit();
    return BgTapOutcome.selected;
  }

  CreatureSnapshot _snapshotCurrent() => CreatureSnapshot(
        stage: state.stage,
        xp: state.xp,
        eggTaps: state.eggTaps,
        hunger: state.hunger,
        happy: state.happy,
        color: state.color,
        pattern: state.pattern,
        equipHead: state.equipHead,
        equipFace: state.equipFace,
        nickname: state.nickname,
        bg: state.bg,
        kingSparkle: state.kingSparkle,
      );

  /// 図鑑から過去に育てた子と交代する(docs/game-design.md §12)。
  /// いまの子は名簿へ退避。未入手種・現在の種族へは交代できない。
  bool switchCreature(int speciesIndex) {
    if (speciesIndex == state.species) return false;
    final hasRecord = state.roster.containsKey(speciesIndex);
    if (!state.collection[speciesIndex] && !hasRecord) return false;

    state.roster[state.species] = _snapshotCurrent();
    final snap = state.roster.remove(speciesIndex);
    state.species = speciesIndex;
    if (snap != null) {
      state
        ..stage = snap.stage
        ..xp = snap.xp
        ..eggTaps = snap.eggTaps
        ..hunger = snap.hunger
        ..happy = snap.happy
        ..color = snap.color
        ..pattern = snap.pattern
        ..equipHead = snap.equipHead
        ..equipFace = snap.equipFace
        ..nickname = snap.nickname
        ..bg = snap.bg
        ..kingSparkle = snap.kingSparkle;
    } else {
      // 記録がない(旧セーブ等)場合はキング姿の初期状態で迎える
      state
        ..stage = 3
        ..xp = 0
        ..eggTaps = 0
        ..hunger = 80
        ..happy = 80
        ..pattern = null
        ..nickname = null
        ..bg = null
        ..kingSparkle = 0
        ..color = speciesList[speciesIndex].color.toARGB32();
    }
    sfx.playBabble(speciesIndex); // ただいまのごあいさつ
    _commit();
    return true;
  }

  /// ニックネームを付ける(空なら種族名に戻す・最大10文字)。
  /// 絵文字(サロゲートペア)を途中で分割しないよう Unicode コードポイント単位で数える。
  void rename(String name) {
    final t = name.trim();
    state.nickname = t.isEmpty
        ? null
        : (t.runes.length > 10 ? String.fromCharCodes(t.runes.take(10)) : t);
    sfx.play(Sfx.happy);
    _commit();
  }

  /// ショップのセルをタップ: 未所持なら購入(即装備)、
  /// 所持済みなら着脱トグル。装備は種族をまたいで維持される。
  ShopTapOutcome tapShopItem(ShopItem item) {
    final outcome = _tapShopItem(item);
    switch (outcome) {
      case ShopTapOutcome.bought:
        sfx.play(Sfx.coin);
        sfx.playJingle(Sfx.dressUp); // きせかえは派手に
      case ShopTapOutcome.equipped:
        sfx.play(Sfx.dressUp);
      case ShopTapOutcome.unequipped:
        sfx.play(Sfx.tap);
      case ShopTapOutcome.notEnoughCoins:
        sfx.play(Sfx.wrong);
        return outcome; // 状態は変わっていないので保存しない
    }
    _commit();
    return outcome;
  }

  ShopTapOutcome _tapShopItem(ShopItem item) {
    if (!state.owned.contains(item.key)) {
      if (state.coins < item.cost) return ShopTapOutcome.notEnoughCoins;
      state.coins -= item.cost;
      state.owned.add(item.key);
      _setSlot(item.slot, item.key);
      return ShopTapOutcome.bought;
    }
    final current =
        item.slot == ItemSlot.head ? state.equipHead : state.equipFace;
    if (current == item.key) {
      _setSlot(item.slot, null);
      return ShopTapOutcome.unequipped;
    }
    _setSlot(item.slot, item.key);
    return ShopTapOutcome.equipped;
  }

  void _setSlot(ItemSlot slot, String? key) {
    if (slot == ItemSlot.head) {
      state.equipHead = key;
    } else {
      state.equipFace = key;
    }
  }

  /// おえかき: 体色の変更(即時反映・保存)。
  void setBodyColor(int argb) {
    state.color = argb;
    _commit();
  }

  /// おえかき: 模様を保存して happy+8 / xp+4(docs/game-design.md §6)。
  void savePaint(String patternBase64) {
    state.pattern = patternBase64;
    state.happy = min(100, state.happy + 8);
    state.xp += 4;
    _addSparkle(25);
    sfx.play(Sfx.happy);
    _commit();
  }

  /// おえかき: 模様を消す(報酬なし)。
  void clearPattern() {
    state.pattern = null;
    _commit();
  }

  /// あいことばを適用する。成功時のみ状態が置き換わる。
  bool applyCode(String input) {
    if (!state.loadCode(input)) {
      sfx.play(Sfx.wrong);
      return false;
    }
    sfx.play(Sfx.fanfare);
    _commit();
    return true;
  }

  KingGift? _pendingGift;

  /// たまっていたおみやげを受け取る(1回だけ返す)。UI側で演出する。
  KingGift? takePendingGift() {
    final g = _pendingGift;
    _pendingGift = null;
    return g;
  }

  /// きらきらゲージ(キングのみ)。満タンでおみやげ発生(docs §14)。
  void _addSparkle(double amount) {
    if (state.stage != 3) return;
    state.kingSparkle = min(100, state.kingSparkle + amount);
    if (state.kingSparkle < 100) return;
    state.kingSparkle = 0;
    final locked = kingGiftStamps.where(
      (e) => !state.unlockedStamps.contains(e),
    );
    if (locked.isNotEmpty) {
      final stamp = locked.first;
      state.unlockedStamps.add(stamp);
      _pendingGift = KingGift(stamp: stamp, coins: 10);
      state.coins += 10;
    } else {
      final coins = 20 + _rng.nextInt(21);
      state.coins += coins;
      _pendingGift = KingGift(coins: coins);
    }
  }

  /// 変更を通知し保存する。書き込みは操作のたび(仕様)。
  void _commit() {
    notifyListeners();
    // 保存失敗でアプリを止めない。未処理の Future エラーにもしない
    // (docs/review-findings.md #16)。
    _store.save(state).catchError((Object e) {
      debugPrint('save failed: $e');
    });
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    sfx.dispose();
    super.dispose();
  }
}

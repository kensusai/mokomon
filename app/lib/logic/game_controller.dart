import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/sfx_player.dart';
import '../audio/sound_synth.dart';
import '../data/foods.dart';
import '../data/items.dart';
import '../data/save_store.dart';
import '../data/species.dart';
import '../models/game_state.dart';

/// たまごタップの結果。3タップ目で孵化する(docs/game-design.md §4)。
enum EggTapOutcome { crack, hatched }

/// ショップのセルをタップした結果(docs/game-design.md §7)。
enum ShopTapOutcome { bought, equipped, unequipped, notEnoughCoins }

/// ユースケース層: ゲーム操作とその副作用(通知・保存)をまとめる。
/// UI は本クラス経由でのみ状態を変更する。
class GameController extends ChangeNotifier {
  GameController(this.state, this._store, {Random? rng})
      : _rng = rng ?? Random();

  final GameState state;
  final SaveStore _store;
  final Random _rng;
  Timer? _decayTimer;

  /// 効果音(ミュート設定は state.sound を参照)。
  late final SfxPlayer sfx = SfxPlayer(enabled: () => state.sound);

  /// アプリ起動中の減衰(10秒ごと)。docs/game-design.md §3。
  void startDecayTimer() {
    _decayTimer ??=
        Timer.periodic(const Duration(seconds: 10), (_) => decayTick());
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

  /// なでなで: happy +3 / xp +1。docs/game-design.md §3。
  void pet() {
    state.happy = min(100, state.happy + 3);
    state.xp += 1;
    sfx.play(Sfx.happy);
    _commit();
  }

  /// 💨(隠し機能・名前を付けない)。happy +2。docs/game-design.md §9。
  void puff() {
    state.happy = min(100, state.happy + 2);
    sfx.play(Sfx.puff);
    _commit();
  }

  /// サウンドのミュートトグル(設定は保存される)。
  void toggleSound() {
    state.sound = !state.sound;
    sfx.play(Sfx.tap);
    _commit();
  }

  /// hunger≧98 は給餌不可(「おなかいっぱい」)。
  bool get isFull => state.hunger >= 98;

  /// ごはん。コイン不足なら false を返し何も変更しない。
  bool feed(Food food) {
    if (state.coins < food.cost) return false;
    state.coins -= food.cost;
    state.hunger = min(100, state.hunger + food.hunger);
    state.happy = min(100, state.happy + food.happy);
    state.xp += food.xp;
    sfx.play(Sfx.munch);
    _commit();
    return true;
  }

  /// ミニゲームクリアの共通報酬: コイン+獲得分、happy+12、xp+10。
  /// docs/game-design.md §5。
  void finishMinigame(int coins) {
    state.coins += coins;
    state.happy = min(100, state.happy + 12);
    state.xp += 10;
    sfx.play(Sfx.fanfare);
    _commit();
  }

  /// 進化を確定する。カットシーンのリビール時点で呼ぶこと
  /// (判定は state.evolveCheck())。キング到達でずかん登録。
  void applyEvolution(int newStage) {
    state.stage = newStage;
    if (newStage == 3) state.collection[state.species] = true;
    _commit();
  }

  /// 新しいたまごを迎える(抽選は docs/game-design.md §4)。
  /// コイン・ずかん・きせかえは引き継ぎ、育成状態はリセットする。
  int newEgg() {
    final next = state.nextEggSpecies(_rng);
    state
      ..species = next
      ..stage = 0
      ..eggTaps = 0
      ..xp = 0
      ..hunger = 80
      ..happy = 80
      ..pattern = null
      ..color = speciesList[next].color.toARGB32();
    _commit();
    return next;
  }

  /// ショップのセルをタップ: 未所持なら購入(即装備)、
  /// 所持済みなら着脱トグル。装備は種族をまたいで維持される。
  ShopTapOutcome tapShopItem(ShopItem item) {
    final outcome = _tapShopItem(item);
    switch (outcome) {
      case ShopTapOutcome.bought:
        sfx.play(Sfx.coin);
      case ShopTapOutcome.equipped:
        sfx.play(Sfx.happy);
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

  /// 変更を通知し保存する。書き込みは操作のたび(仕様)。
  void _commit() {
    notifyListeners();
    _store.save(state);
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    sfx.dispose();
    super.dispose();
  }
}

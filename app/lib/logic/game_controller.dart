import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/foods.dart';
import '../data/save_store.dart';
import '../data/species.dart';
import '../models/game_state.dart';

/// たまごタップの結果。3タップ目で孵化する(docs/game-design.md §4)。
enum EggTapOutcome { crack, hatched }

/// ユースケース層: ゲーム操作とその副作用(通知・保存)をまとめる。
/// UI は本クラス経由でのみ状態を変更する。
class GameController extends ChangeNotifier {
  GameController(this.state, this._store, {Random? rng})
      : _rng = rng ?? Random();

  final GameState state;
  final SaveStore _store;
  final Random _rng;
  Timer? _decayTimer;

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
    _commit();
    return EggTapOutcome.crack;
  }

  /// なでなで: happy +3 / xp +1。docs/game-design.md §3。
  void pet() {
    state.happy = min(100, state.happy + 3);
    state.xp += 1;
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
      ..color = speciesList[next].color.toARGB32();
    _commit();
    return next;
  }

  /// 変更を通知し保存する。書き込みは操作のたび(仕様)。
  void _commit() {
    notifyListeners();
    _store.save(state);
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    super.dispose();
  }
}

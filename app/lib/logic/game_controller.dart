import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/save_store.dart';
import '../models/game_state.dart';

/// ユースケース層: ゲーム操作とその副作用(通知・保存)をまとめる。
/// UI は本クラス経由でのみ状態を変更する。
class GameController extends ChangeNotifier {
  GameController(this.state, this._store);

  final GameState state;
  final SaveStore _store;

  /// なでなで: happy +3 / xp +1。docs/game-design.md §3。
  void pet() {
    state.happy = min(100, state.happy + 3);
    state.xp += 1;
    _commit();
  }

  /// 変更を通知し保存する。書き込みは操作のたび(仕様)。
  void _commit() {
    notifyListeners();
    _store.save(state);
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

/// インフラ層: GameState の永続化(shared_preferences)。
/// ドメイン(GameState)は本クラスに依存しない。docs/game-design.md §2。
class SaveStore {
  static const _prefsKey = 'mokomon-v1';

  Future<void> save(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  /// 保存データから復元し、オフライン減衰を適用する。
  /// データが無い/壊れている場合は初期状態を返す。
  Future<GameState> load() async {
    final state = GameState();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        state.loadJson(jsonDecode(raw) as Map<String, dynamic>);
        state.applyOfflineDecay();
      } catch (_) {
        /* 壊れたデータは初期状態で継続 */
      }
    }
    return state;
  }
}

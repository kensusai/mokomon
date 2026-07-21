import 'dart:async';

import 'package:flutter/material.dart';

/// 画面が張った一発 `Timer` をまとめて持ち、`dispose()` で確実にキャンセルする。
///
/// ミニゲーム画面は「少し待ってから次のラウンドへ」「お手本を順に光らせる」など
/// 遅延処理を多用するが、途中で画面を閉じられると破棄済み State に対して
/// `setState()` が走る。各画面が `List<Timer>` と同じ `dispose()` ループを
/// 持っていた重複をここに集約した(docs/review-findings.md #13 の後始末)。
///
/// [later] のコールバックは `mounted` が false なら呼ばれない。`dispose()` で
/// キャンセル済みのため通常は到達しないが、二重の安全弁として残している。
mixin TimerBagMixin<T extends StatefulWidget> on State<T> {
  final _timers = <Timer>[];

  /// [d] 後に [fn] を呼ぶ。画面が破棄されていれば発火しない。
  void later(Duration d, VoidCallback fn) {
    _timers.add(Timer(d, () {
      if (!mounted) return;
      fn();
    }));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}

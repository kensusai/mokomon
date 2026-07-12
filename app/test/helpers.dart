/// テスト共通ヘルパー(boot/drain/決定的Random)。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/main.dart';
import 'package:mokomon/models/game_state.dart';

/// なでなでの6%💨判定を出さない決定的Random(フレーク防止)。
class NoPuffRandom implements Random {
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

/// nextDouble が固定値を返すテスト用 Random(💨の6%判定を制御する)。
class FixedRandom implements Random {
  final double value;
  FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

/// アプリ全体を起動してコントローラを返す。
/// いきものをタップするテストは rng に [NoPuffRandom] を渡して決定的にする。
Future<GameController> bootApp(WidgetTester tester,
    {GameState? state, Random? rng}) async {
  final c = GameController(state ?? GameState(), SaveStore(), rng: rng);
  await tester.pumpWidget(MokomonApp(controller: c));
  return c;
}

/// ホームのタイマー(ヒント・キラキラ等)を流してから画面を破棄する。
/// 常時アニメーションがあるため pumpAndSettle は使えない(docs/frontend.md)。
Future<void> drainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

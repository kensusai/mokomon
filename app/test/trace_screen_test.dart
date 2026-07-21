import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/screens/trace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// なぞってかこう(docs/game-design.md §5)。
/// review-findings.md #13 で Future.delayed → Timer に変更したので、
/// 判定後の遅延中に画面を閉じても例外にならないことを確認する。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tracing all shapes advances rounds and finally pays out', (
    tester,
  ) async {
    final c = stage1Controller();
    await pumpScreen(
      tester,
      TraceScreen(controller: c, shapes: const ['circle', 'heart', 'star']),
    );

    for (var round = 0; round < 3; round++) {
      expect(find.text('${round + 1} / 3  てんせんを なぞってね'), findsOneWidget);
      await tester.drag(find.byType(CustomPaint).first, const Offset(20, 0));
      await tester.pump();
      await tester.tap(find.text('できた!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
    }

    expect(find.textContaining('コイン!'), findsOneWidget);
  });

  testWidgets('leaving the screen during the post-judge delay does not throw', (
    tester,
  ) async {
    final c = stage1Controller();
    await pumpScreen(
      tester,
      TraceScreen(controller: c, shapes: const ['circle', 'heart', 'star']),
    );

    await tester.drag(find.byType(CustomPaint).first, const Offset(20, 0));
    await tester.pump();
    await tester.tap(find.text('できた!'));
    await tester.pump(); // タイマー開始、まだ発火前

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 1)); // 保留タイマー・遷移を固定時間で流す
  });
}

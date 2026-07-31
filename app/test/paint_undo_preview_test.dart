import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/screens/paint_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// おえかきのライブプレビューと「もどす」(docs/game-design.md §6)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameController> boot(WidgetTester tester) async {
    final c = GameController(GameState()..stage = 1, SaveStore());
    await tester.pumpWidget(MaterialApp(home: PaintScreen(controller: c)));
    return c;
  }

  /// キャンバス中央を横切る1ストロークを描く(パンのタッチスロップで
  /// 始点がずれるため、中心を必ず通るよう往復させる)。
  Future<void> drawStroke(WidgetTester tester) async {
    final canvas = find.byKey(const ValueKey('paint-canvas'));
    final gesture = await tester.startGesture(tester.getCenter(canvas));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.up();
    await tester.pump();
  }

  /// できた!で保存し、保存された模様の (x, y) のアルファ値を返す。
  Future<int> saveAndAlphaAt(
    WidgetTester tester,
    GameController c,
    int x,
    int y,
  ) async {
    late int alpha;
    await tester.runAsync(() async {
      await tester.tap(find.text('できた!'));
      for (var i = 0; i < 20 && c.state.pattern == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final img = await decodeImageFromList(base64Decode(c.state.pattern!));
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      alpha = data!.buffer.asUint8List()[(y * 300 + x) * 4 + 3];
    });
    await tester.pump();
    return alpha;
  }

  testWidgets('paint: live preview of the creature is shown', (tester) async {
    await boot(tester);
    expect(find.byKey(const ValueKey('paint-preview')), findsOneWidget);
  });

  testWidgets('paint: undo removes the last stroke', (tester) async {
    final c = await boot(tester);
    await drawStroke(tester);
    await tester.tap(find.byKey(const ValueKey('paint-undo')));
    await tester.pump();

    final alpha = await saveAndAlphaAt(tester, c, 150, 150);
    expect(alpha, 0, reason: 'もどした線は保存されない');
  });

  testWidgets('paint: undo restores the layer before a bucket fill', (
    tester,
  ) async {
    final c = await boot(tester);
    await tester.tap(find.text('ぬりつぶし'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('paint-canvas')));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('paint-undo')));
    await tester.pump();

    final alpha = await saveAndAlphaAt(tester, c, 150, 150);
    expect(alpha, 0, reason: 'もどした ぬりつぶしは保存されない');
  });

  testWidgets('paint: undo rescues an accidental ぜんぶけす', (tester) async {
    final c = await boot(tester);
    await drawStroke(tester);
    await tester.tap(find.text('ぜんぶけす'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paint-undo')));
    await tester.pump();

    final alpha = await saveAndAlphaAt(tester, c, 150, 150);
    expect(alpha, isNot(0), reason: 'けす前の線が もどって保存される');
  });

  testWidgets('paint: undo with nothing to undo is a no-op', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const ValueKey('paint-undo')));
    await tester.pump();
    // 落ちなければOK(ボタンは無効表示)
    expect(find.byKey(const ValueKey('paint-undo')), findsOneWidget);
  });
}

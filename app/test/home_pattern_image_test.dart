import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// 4x4 単色PNGの base64 を作る(ホームの模様として使う)。
Future<String> _tinyPngBase64(Color color) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = color);
  final img = await rec.endRecording().toImage(4, 4);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return base64Encode(bytes!.buffer.asUint8List());
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home survives a pattern that decodes but is not a PNG', (
    tester,
  ) async {
    // docs/review-findings.md #43: base64 としては正しいが画像として壊れた
    // pattern は decodeImageFromList が非同期例外を投げる。onError が無いと
    // 未処理例外になる。模様なしとして無視されること。
    final garbage = base64Encode(List<int>.filled(64, 0x42));
    await bootApp(
      tester,
      state: GameState()
        ..stage = 1
        ..pattern = garbage,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await drainTimers(tester);
  });

  testWidgets(
    'home: replacing and leaving the pattern image disposes the old ui.Image',
    (tester) async {
      // docs/review-findings.md #18: _patternImage の差し替え・画面破棄で
      // 古い ui.Image が dispose されること。生成/破棄イベントで生存数を数える。
      final live = <Object>{};
      void onEvent(ObjectEvent e) {
        if (e.object is ui.Image) {
          if (e is ObjectCreated) live.add(e.object);
          if (e is ObjectDisposed) live.remove(e.object);
        }
      }

      FlutterMemoryAllocations.instance.addListener(onEvent);
      addTearDown(
        () => FlutterMemoryAllocations.instance.removeListener(onEvent),
      );

      // デコードは実asyncなので、既存規約どおり固定回数のポーリングで待つ
      // (docs/review-findings.md #44)。
      Future<void> waitFor(bool Function() cond) async {
        await tester.runAsync(() async {
          for (var i = 0; i < 40 && !cond(); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pump();
      }

      late final String pngA;
      late final String pngB;
      await tester.runAsync(() async {
        pngA = await _tinyPngBase64(const Color(0xFFFF0000));
        pngB = await _tinyPngBase64(const Color(0xFF00FF00));
      });
      live.clear(); // PNG生成用の一時イメージは数えない

      final c = await bootApp(
        tester,
        state: GameState()
          ..stage = 1
          ..pattern = pngA,
      );
      await waitFor(() => live.length == 1);
      expect(live.length, 1, reason: 'pattern A is decoded and alive');
      final imageA = live.single;

      // おえかき保存 → 模様が差し替わり、古いデコード結果は不要になる。
      c.savePaint(pngB);
      await waitFor(() => live.length == 1 && !live.contains(imageA));
      expect(
        live.length,
        1,
        reason: 'pattern A must be disposed on replacement',
      );
      expect(live, isNot(contains(imageA)));

      // 模様を消す(null 経路)でも破棄されること(同期処理なので待ち不要)。
      c.clearPattern();
      await tester.pump();
      expect(live, isEmpty, reason: 'pattern B must be disposed when cleared');

      // 最後にもう一度表示してから画面を破棄 → dispose() が解放する。
      c.savePaint(pngA);
      await waitFor(() => live.length == 1);
      expect(live.length, 1);
      await drainTimers(tester);
      expect(
        live,
        isEmpty,
        reason: 'leaving the screen must release the image',
      );
    },
  );
}

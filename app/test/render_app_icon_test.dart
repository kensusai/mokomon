// 開発用: アプリアイコン(1024px)をゲーム内の描画コードから書き出す。
// 各プラットフォームへの配置は tool/gen_icons.sh が行う。
// MOKOMON_PREVIEW_DIR が未設定ならスキップされる(CIでは走らない)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/backgrounds.dart';
import 'package:mokomon/widgets/creature_painter.dart';

void main() {
  final dir = Platform.environment['MOKOMON_PREVIEW_DIR'];

  test('render app icon', () async {
    if (dir == null) {
      markTestSkipped('MOKOMON_PREVIEW_DIR not set');
      return;
    }
    const size = 1024.0;
    const rect = Rect.fromLTWH(0, 0, size, size);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, rect);

    // 背景は既定テーマ「そら」のグラデーション(ホーム画面と同じ色)
    final sora = bgThemes.first;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sora.top, sora.bottom],
        ).createShader(rect),
    );

    // 雲を2つ(ホーム背景の装飾と同じ白い丸の重なり)
    final cloud = Paint()..color = Colors.white;
    for (final (cx, cy, r) in [(190.0, 250.0, 70.0), (840.0, 330.0, 55.0)]) {
      canvas.drawCircle(Offset(cx, cy), r, cloud);
      canvas.drawCircle(Offset(cx - r * 0.9, cy + r * 0.3), r * 0.7, cloud);
      canvas.drawCircle(Offset(cx + r * 0.9, cy + r * 0.3), r * 0.7, cloud);
    }

    // 主役はゲーム名の由来「もこもん」(moko ステージ2)。
    // Android の maskable 安全域(中央80%)に収まるよう 72% の大きさで中央に置く。
    const creature = size * 0.72;
    canvas.save();
    canvas.translate((size - creature) / 2, (size - creature) / 2 + 30);
    canvas.scale(creature / 300);
    CreaturePainter(
      speciesIndex: 0,
      stage: 2,
      sad: false,
    ).paint(canvas, const Size(300, 300));
    canvas.restore();

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/app_icon.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

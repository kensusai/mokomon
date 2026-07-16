// 開発用プレビュー: 種族×ステージをPNGに書き出して目視確認する。
// MOKOMON_PREVIEW_DIR が未設定ならスキップされる(CIでは走らない)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/widgets/creature_faces.dart';
import 'package:mokomon/widgets/creature_painter.dart';
import 'package:mokomon/widgets/egg_painter.dart';

void main() {
  final dir = Platform.environment['MOKOMON_PREVIEW_DIR'];

  test('render species x stage preview sheet', () async {
    if (dir == null) {
      markTestSkipped('MOKOMON_PREVIEW_DIR not set');
      return;
    }
    const cell = 220.0;
    final cols = 4; // egg + stage1..3
    final rows = speciesList.length;
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, cell * cols, cell * rows));
    canvas.drawRect(Rect.fromLTWH(0, 0, cell * cols, cell * rows),
        Paint()..color = const Color(0xFFEAF6FF));

    for (var sp = 0; sp < rows; sp++) {
      for (var stage = 0; stage <= 3; stage++) {
        canvas.save();
        canvas.translate(stage * cell + 10, sp * cell + 10);
        canvas.scale((cell - 20) / 300);
        if (stage == 0) {
          EggPainter(cracks: 0, golden: sp == secretSpeciesIndex)
              .paint(canvas, const Size(300, 300));
        } else {
          CreaturePainter(speciesIndex: sp, stage: stage, sad: false)
              .paint(canvas, const Size(300, 300));
        }
        canvas.restore();
      }
    }

    final image = await recorder
        .endRecording()
        .toImage((cell * cols).toInt(), (cell * rows).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/species_sheet.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });

  test('render expression preview sheet', () async {
    if (dir == null) {
      markTestSkipped('MOKOMON_PREVIEW_DIR not set');
      return;
    }
    const cell = 220.0;
    const species = [0, 4, 6]; // 通常顔・変顔2種で表情の重なりを確認
    final moods = CreatureMood.values;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, cell * moods.length, cell * species.length));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, cell * moods.length, cell * species.length),
        Paint()..color = const Color(0xFFEAF6FF));
    for (var r = 0; r < species.length; r++) {
      for (var c = 0; c < moods.length; c++) {
        canvas.save();
        canvas.translate(c * cell + 10, r * cell + 10);
        canvas.scale((cell - 20) / 300);
        CreaturePainter(
                speciesIndex: species[r], stage: 2, sad: false, mood: moods[c])
            .paint(canvas, const Size(300, 300));
        canvas.restore();
      }
    }
    final image = await recorder.endRecording().toImage(
        (cell * moods.length).toInt(), (cell * species.length).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/expressions_sheet.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

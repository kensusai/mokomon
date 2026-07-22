import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_painter.dart';

void main() {
  group('new species: にゃん / ダンディ (index 7, 8)', () {
    test('are appended in order so あいことば stay compatible', () {
      expect(speciesList, hasLength(15));
      expect(speciesList[7].key, 'nyan');
      expect(speciesList[8].key, 'dandy');
      expect(speciesList.sublist(9).map((s) => s.key).toList(), [
        'mojya',
        'guru',
        'paku',
        'nemu',
        'robo',
        'obake',
      ]);
      expect(secretSpeciesIndex, 3); // 金のたまごは変わらず pika
      // 色・名前・絵文字が全種族で揃っている
      for (final sp in speciesList) {
        expect(sp.names, hasLength(5), reason: sp.key);
        expect(sp.emojis, hasLength(5), reason: sp.key);
      }
    });

    test('display names follow the stage pattern', () {
      expect(
        (GameState()
              ..species = 7
              ..stage = 1)
            .displayName,
        '🐱 にゃん',
      );
      expect(
        (GameState()
              ..species = 7
              ..stage = kingStage)
            .displayName,
        '👑 キングにゃんこ',
      );
      expect(
        (GameState()
              ..species = 8
              ..stage = 2)
            .displayName,
        '🧔 ダンディ',
      );
      expect(
        (GameState()
              ..species = 8
              ..stage = kingStage)
            .displayName,
        '👑 キングダンディ',
      );
    });

    test('collection bits for index 8 roundtrip through あいことば', () {
      final s = GameState();
      s.collection[7] = true;
      s.collection[8] = true;
      final restored = GameState();
      expect(restored.loadCode(s.makeCode()), isTrue);
      expect(restored.collection[7], isTrue);
      expect(restored.collection[8], isTrue);
      expect(restored.collection[0], isFalse);
    });

    test('egg lottery can draw every new species', () {
      final s = GameState();
      final drawn = <int>{};
      for (var i = 0; i < 2000; i++) {
        drawn.add(s.nextEggSpecies(Random(i)));
      }
      expect(drawn, containsAll([7, 8, 9, 10, 11, 12, 13, 14]));
    });

    testWidgets('every species renders at every stage without throwing', (
      tester,
    ) async {
      for (var sp = 0; sp < speciesList.length; sp++) {
        for (var stage = 1; stage <= 3; stage++) {
          for (final sad in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                home: CustomPaint(
                  size: const Size(300, 300),
                  painter: CreaturePainter(
                    speciesIndex: sp,
                    stage: stage,
                    sad: sad,
                  ),
                ),
              ),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'species=$sp stage=$stage sad=$sad',
            );
          }
        }
      }
    });
  });
}

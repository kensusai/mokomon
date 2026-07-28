import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_painter.dart';

void main() {
  group('new species: にゃん / ダンディ (index 7, 8)', () {
    test('are appended in order so あいことば stay compatible', () {
      expect(speciesList, hasLength(16));
      expect(speciesList[7].key, 'nyan');
      expect(speciesList[8].key, 'dandy');
      expect(speciesList.sublist(9).map((s) => s.key).toList(), [
        'mojya',
        'guru',
        'paku',
        'nemu',
        'robo',
        'obake',
        'yuni',
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
      expect(drawn, containsAll([7, 8, 9, 10, 11, 12, 13, 14, 15]));
    });

    test('ゆに (index 15) display names follow the stage pattern', () {
      expect(
        (GameState()
              ..species = 15
              ..stage = 1)
            .displayName,
        '🐴 ゆに',
      );
      expect(
        (GameState()
              ..species = 15
              ..stage = kingStage)
            .displayName,
        '👑 キングゆにこーん',
      );
    });

    test(
      'body silhouettes are distinct per species and change on evolution',
      () {
        // こどもFB「イラストが全部似ている」: 種族ごとに別の体形パスを持ち、
        // 進化(stage2→キング)でも形が変わることをパスの点標本で固定する。
        String signature(int sp, int stage) {
          final path = CreaturePainter.bodyPathFor(sp, stage);
          final buf = StringBuffer();
          for (var y = 0; y < 20; y++) {
            for (var x = 0; x < 20; x++) {
              buf.write(
                path.contains(Offset(x * 15.0 + 7.5, y * 15.0 + 7.5))
                    ? '1'
                    : '0',
              );
            }
          }
          return buf.toString();
        }

        final stage2 = {
          for (var sp = 0; sp < speciesList.length; sp++) signature(sp, 2),
        };
        expect(
          stage2.length,
          greaterThanOrEqualTo(12),
          reason: 'stage2 のシルエットは種族ごとにほぼ別物',
        );
        final kings = {
          for (var sp = 0; sp < speciesList.length; sp++)
            signature(sp, kingStage),
        };
        expect(
          kings.length,
          greaterThanOrEqualTo(12),
          reason: 'キングのシルエットも種族ごとにほぼ別物',
        );
        for (var sp = 0; sp < speciesList.length; sp++) {
          expect(
            signature(sp, 2),
            isNot(signature(sp, 3)),
            reason: '中間→新段階でも輪郭が変わる (species=$sp)',
          );
          expect(
            signature(sp, 3),
            isNot(signature(sp, kingStage)),
            reason: '新段階→キングでも輪郭が変わる (species=$sp)',
          );
        }
      },
    );

    testWidgets('every species renders at every stage without throwing', (
      tester,
    ) async {
      for (var sp = 0; sp < speciesList.length; sp++) {
        for (var stage = 1; stage <= kingStage; stage++) {
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

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/logic/minigames.dart';

/// リズムタッチのロジック(docs/game-design.md §5)。
void main() {
  test('generates 20 beats with no immediate pad repeats', () {
    for (var seed = 0; seed < 30; seed++) {
      final g = RhythmGame(rng: Random(seed));
      expect(g.pads, hasLength(rhythmBeats));
      for (var i = 0; i < g.pads.length; i++) {
        expect(g.pads[i], inInclusiveRange(0, rhythmPads - 1));
        if (i > 0) {
          expect(g.pads[i], isNot(g.pads[i - 1]), reason: '同じパッドが連続しない');
        }
      }
    }
  });

  test('beat interval accelerates from 600ms to 420ms', () {
    expect(RhythmGame.intervalMsAt(0), 600);
    expect(RhythmGame.intervalMsAt(rhythmBeats - 1), 420);
    for (var i = 1; i < rhythmBeats; i++) {
      expect(
        RhythmGame.intervalMsAt(i),
        lessThanOrEqualTo(RhythmGame.intervalMsAt(i - 1)),
        reason: 'だんだん速くなる',
      );
    }
  });

  test('correct pad scores, tight timing is a perfect', () {
    final g = RhythmGame(rng: Random(1));
    expect(g.tap(g.pads[0], 100), RhythmTap.perfect);
    expect(g.hits, 1);
    expect(g.tap(g.pads[0], 200), RhythmTap.ignored, reason: '1ビート1回だけ');
    expect(g.hits, 1);
    g.nextBeat();
    expect(g.tap(g.pads[1], 300), RhythmTap.hit);
    expect(g.hits, 2);
    expect(g.reward, 2, reason: 'あたり1回=1コイン');
  });

  test('wrong pad does not score and the beat can still be hit', () {
    final g = RhythmGame(rng: Random(2));
    final wrong = (g.pads[0] + 1) % rhythmPads;
    expect(g.tap(wrong, 100), RhythmTap.wrongPad);
    expect(g.hits, 0);
    expect(g.tap(g.pads[0], 200), RhythmTap.hit);
    expect(g.hits, 1);
  });

  test('finishes after all beats and taps are then ignored', () {
    final g = RhythmGame(rng: Random(3));
    for (var i = 0; i < rhythmBeats; i++) {
      expect(g.finished, isFalse);
      g.tap(g.pads[i], 50);
      g.nextBeat();
    }
    expect(g.finished, isTrue);
    expect(g.hits, rhythmBeats);
    expect(g.reward, rhythmBeats, reason: '全部あたりで最大20コイン');
    expect(g.tap(0, 10), RhythmTap.ignored);
  });
}

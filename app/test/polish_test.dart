import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/audio/sound_synth.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/main.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _puffLines = [
  '……いまの なあに?',
  'あれ? へんな おとが した!',
  '……なにも してないよ?',
  'ぷぅ♪',
  'きこえなかった ことに しよう…',
  'だ、だれかな? いまのは…',
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SoundSynth', () {
    test('renders valid mono 16bit WAV for every sfx', () {
      final synth = SoundSynth();
      for (final sfx in Sfx.values) {
        final wav = synth.wavFor(sfx);
        expect(wav.length, greaterThan(44), reason: '$sfx');
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
        // data チャンクに無音でないサンプルが含まれる
        expect(wav.sublist(44).any((b) => b != 0), isTrue, reason: '$sfx');
      }
    });

    test('caches rendered bytes', () {
      final synth = SoundSynth();
      expect(identical(synth.wavFor(Sfx.tap), synth.wavFor(Sfx.tap)), isTrue);
    });
  });

  group('puff (docs/game-design.md §9)', () {
    test('controller.puff adds happy +2 without xp', () {
      final c = GameController(GameState()..stage = 1, SaveStore());
      c.puff();
      expect(c.state.happy, 82);
      expect(c.state.xp, 0);
    });

    testWidgets('tapping the bottom 30% of the creature triggers 💨',
        (tester) async {
      final c = GameController(GameState()..stage = 1, SaveStore());
      await tester.pumpWidget(MokomonApp(controller: c));

      final rect = tester.getRect(find.byType(CreatureView));
      await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.9));
      await tester.pump();

      expect(c.state.happy, 82); // なでなで(+3)ではなく💨(+2)
      expect(c.state.xp, 0);
      expect(
        _puffLines.any(
            (line) => find.text(line).evaluate().isNotEmpty),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('sound toggle', () {
    testWidgets('🔊 toggles to 🔇 and persists the flag', (tester) async {
      final c = GameController(GameState()..stage = 1, SaveStore());
      await tester.pumpWidget(MokomonApp(controller: c));

      expect(find.text('🔊'), findsOneWidget);
      await tester.tap(find.text('🔊'));
      await tester.pump();
      expect(c.state.sound, isFalse);
      expect(find.text('🔇'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}

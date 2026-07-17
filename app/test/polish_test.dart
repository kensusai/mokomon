import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/audio/sound_synth.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:mokomon/widgets/creature_faces.dart';
import 'package:mokomon/widgets/creature_painter.dart';
import 'package:mokomon/widgets/creature_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

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
      final c = await bootApp(tester, state: GameState()..stage = 1);

      final rect = tester.getRect(find.byType(CreatureView));
      await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.9));
      await tester.pump();

      expect(c.state.happy, 82); // なでなで(+3)ではなく💨(+2)
      expect(c.state.xp, 0);
      expect(
        _puffLines.any((line) => find.text(line).evaluate().isNotEmpty),
        isTrue,
      );

      await drainTimers(tester);
    });
  });

  group('petting reactions vary by tap zone (docs/game-design.md §3)', () {
    const headLines = ['えへへ〜', 'あたま なでなで すき!', 'もっと なでて〜', 'きもちいい〜'];
    const bellyLines = ['くすぐったい〜!', 'ぽんぽん だいすき', 'ぷにぷに でしょ?', 'ぽかぽか する〜'];
    const sideLines = ['ひゃっ!', 'そこ そこ〜!', 'わきわき くすぐったい!', 'なになに〜?'];

    Future<void> expectZoneLine(WidgetTester tester, Offset Function(Rect) pos,
        List<String> pool) async {
      final c = await bootApp(tester,
          state: GameState()..stage = 1, rng: NoPuffRandom());
      final rect = tester.getRect(find.byType(CreatureView));
      await tester.tapAt(pos(rect));
      await tester.pump();
      expect(c.state.happy, 83); // なでなで +3
      expect(c.state.xp, 1);
      expect(pool.any((line) => find.text(line).evaluate().isNotEmpty), isTrue,
          reason: 'expected one of $pool');
      await drainTimers(tester);
    }

    testWidgets('head tap (top 34%)', (tester) async {
      await expectZoneLine(tester,
          (r) => Offset(r.center.dx, r.top + r.height * 0.15), headLines);
    });

    testWidgets('side tap (outer 30%)', (tester) async {
      await expectZoneLine(tester,
          (r) => Offset(r.left + r.width * 0.08, r.center.dy), sideLines);
    });

    testWidgets('belly tap (center)', (tester) async {
      await expectZoneLine(tester, (r) => r.center, bellyLines);
    });
  });

  group('expression flash (docs/game-design.md §3)', () {
    testWidgets('petting flashes a happy face then reverts', (tester) async {
      await bootApp(tester, state: GameState()..stage = 1, rng: NoPuffRandom());

      bool hasMood(CreatureMood? mood) => tester
          .widgetList(find.byWidgetPredicate((w) =>
              w is CustomPaint &&
              w.painter is CreaturePainter &&
              (w.painter as CreaturePainter).mood == mood))
          .isNotEmpty;

      expect(hasMood(null), isTrue); // 通常は種族の顔

      await tester.tap(find.byType(CreatureView));
      await tester.pump();
      expect(hasMood(CreatureMood.happy), isTrue);

      await tester.pump(const Duration(milliseconds: 1100));
      expect(hasMood(CreatureMood.happy), isFalse); // 元の顔に戻る

      await drainTimers(tester);
    });

    testWidgets('💨 flashes a surprised face', (tester) async {
      await bootApp(tester, state: GameState()..stage = 1);
      final rect = tester.getRect(find.byType(CreatureView));
      await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.9));
      await tester.pump();
      expect(
          tester
              .widgetList(find.byWidgetPredicate((w) =>
                  w is CustomPaint &&
                  w.painter is CreaturePainter &&
                  (w.painter as CreaturePainter).mood ==
                      CreatureMood.surprised))
              .isNotEmpty,
          isTrue);
      await drainTimers(tester);
    });
  });

  group('paint praise (docs/game-design.md §6)', () {
    const praiseLines = [
      'わあ! すてきな もよう!',
      'かわいく なっちゃった!',
      'みてみて〜!',
      'あたらしい もよう だいすき!',
    ];

    testWidgets('saving a drawing makes the creature celebrate',
        (tester) async {
      final c = await bootApp(tester,
          state: GameState()..stage = 1, rng: NoPuffRandom());

      await tester.tap(find.text('おえかき'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final canvas = find.byType(CustomPaint).first;
      final gesture = await tester.startGesture(tester.getCenter(canvas));
      await gesture.moveBy(const Offset(30, 20));
      await gesture.up();
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('できた!'));
        for (var i = 0; i < 20 && c.state.pattern == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      expect(c.state.pattern, isNotNull);

      // ホームに戻って褒めセリフ
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(praiseLines.any((line) => find.text(line).evaluate().isNotEmpty),
          isTrue);

      await drainTimers(tester);
    });
  });

  group('BGM', () {
    test('renders three looping tracks', () {
      final synth = SoundSynth();
      for (final t in [Sfx.bgm, Sfx.bgm2, Sfx.bgm3]) {
        // どの曲も数秒以上のループ(22050Hz 16bit mono)
        expect(synth.wavFor(t).length, greaterThan(200000), reason: '$t');
      }
    });

    test('cycleBgm rotates tracks and persists the choice', () {
      final c = GameController(GameState()..stage = 1, SaveStore());
      expect(c.state.bgmTrack, 0);
      expect(c.cycleBgm(), 1);
      expect(c.cycleBgm(), 2);
      expect(c.cycleBgm(), 0);
      c.state.bgmTrack = 2;
      final restored = GameState()..loadJson(c.state.toJson());
      expect(restored.bgmTrack, 2);
    });

    testWidgets('🎵 button cycles the track and shows the name',
        (tester) async {
      final c = await bootApp(tester, state: GameState()..stage = 1);
      await tester.tap(find.text('🎵'));
      await tester.pump();
      expect(c.state.bgmTrack, 1);
      expect(find.text('♪ わくわく'), findsWidgets);
      await drainTimers(tester);
    });
  });

  group('babble voice (docs/game-design.md §3)', () {
    test('renders a valid deterministic voice per species/variant', () {
      final synth = SoundSynth();
      for (final species in [0, 4, 8]) {
        for (var variant = 0; variant < 3; variant++) {
          final wav = synth.wavForBabble(species, variant);
          expect(wav.length, greaterThan(44));
          expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        }
      }
      // キャッシュされ、同じ入力は同一バイト列
      expect(identical(synth.wavForBabble(0, 0), synth.wavForBabble(0, 0)),
          isTrue);
      // 種族が違えば別の声
      expect(synth.wavForBabble(0, 0), isNot(equals(synth.wavForBabble(5, 0))));
    });
  });

  group('sound toggle', () {
    testWidgets('🔊 toggles to 🔇 and persists the flag', (tester) async {
      final c = await bootApp(tester, state: GameState()..stage = 1);

      expect(find.text('🔊'), findsOneWidget);
      await tester.tap(find.text('🔊'));
      await tester.pump();
      expect(c.state.sound, isFalse);
      expect(find.text('🔇'), findsOneWidget);

      await drainTimers(tester);
    });
  });
}

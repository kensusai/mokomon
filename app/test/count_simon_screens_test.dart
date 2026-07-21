import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/audio/sound_synth.dart';
import 'package:mokomon/logic/minigames.dart';
import 'package:mokomon/screens/count_screen.dart';
import 'package:mokomon/screens/simon_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// 新ゲーム2種の画面フロー(docs/game-design.md §5)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('count: answering all 6 rounds pays 18 coins', (tester) async {
    final c = stage1Controller();
    final game = CountGame(rng: Random(2));
    await pumpScreen(tester, CountScreen(controller: c, game: game));

    for (var round = 0; round < countRounds; round++) {
      final i = game.choices.indexOf(game.answer);
      await tester.tap(find.byKey(ValueKey('count-choice-$i')));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.textContaining('+18 コイン'), findsOneWidget);
    expect(c.state.coins, 28); // 10 + 18
  });

  testWidgets('count: tapping during the victory delay plays no wrong sfx', (
    tester,
  ) async {
    // docs/review-findings.md #23: 最終ラウンド正解後、_ended が立つまでの
    // 400ms に選択肢をタップすると、全問正解なのに不正解音が鳴っていた。
    final rec = RecordingSfx();
    final c = stage1Controller(sfx: rec.sfx);
    final game = CountGame(rng: Random(2));
    await pumpScreen(tester, CountScreen(controller: c, game: game));

    for (var round = 0; round < countRounds - 1; round++) {
      final i = game.choices.indexOf(game.answer);
      await tester.tap(find.byKey(ValueKey('count-choice-$i')));
      await tester.pump(const Duration(milliseconds: 600));
    }
    // 最終ラウンド正解 → 勝利待ちの400msに入る
    final last = game.choices.indexOf(game.answer);
    await tester.tap(find.byKey(ValueKey('count-choice-$last')));
    await tester.pump(const Duration(milliseconds: 100));
    // 勝利待ち中の追いタップ
    await tester.tap(find.byKey(const ValueKey('count-choice-0')));
    await tester.pump(const Duration(milliseconds: 500));

    final wrongWav = SoundSynth().wavFor(Sfx.wrong);
    expect(
      rec.players
          .expand((p) => p.playedBytes)
          .where((b) => listEquals(b, wrongWav)),
      isEmpty,
      reason: '全問正解の直後に不正解音を鳴らさない',
    );
    expect(find.textContaining('+18 コイン'), findsOneWidget);
    // 注入した SfxPlayer は no-op でないため、曲長由来の仮想時間で
    // タイマーを流す(#64)
    await drainRewardJingle(tester);
  });

  testWidgets('count: wrong choice does not advance', (tester) async {
    final c = stage1Controller();
    final game = CountGame(rng: Random(2));
    await pumpScreen(tester, CountScreen(controller: c, game: game));

    final wrong = game.choices.indexWhere((n) => n != game.answer);
    await tester.tap(find.byKey(ValueKey('count-choice-$wrong')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.round, 0);
    expect(c.state.coins, 10);
  });

  testWidgets('simon: clear round 1 then a wrong pad ends with +3 coins', (
    tester,
  ) async {
    final c = stage1Controller();
    final game = SimonGame(rng: Random(1));
    await pumpScreen(tester, SimonScreen(controller: c, game: game));

    // お手本再生中はタップしても進まない
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(
      find.byKey(const ValueKey('simon-0')),
      warnIfMissed: false,
    );
    expect(game.reward, 0);

    // お手本(2連)が終わるまで待つ → じゅんばんにタッチ
    await tester.pump(const Duration(milliseconds: 2200));
    final first = [...game.sequence];
    for (final pad in first) {
      await tester.tap(find.byKey(ValueKey('simon-$pad')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.reward, simonRewardPerRound);

    // 3連のお手本を待って、わざと間違える → 終了(ごほうびは持ち帰り)
    await tester.pump(const Duration(milliseconds: 4000));
    final wrongPad = (game.sequence[0] + 1) % simonPads;
    await tester.tap(find.byKey(ValueKey('simon-$wrongPad')));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.textContaining('+3 コイン'), findsOneWidget);
    expect(c.state.coins, 13); // 10 + 3
  });
}

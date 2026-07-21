import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/audio/sfx_player.dart';
import 'package:mokomon/audio/sound_synth.dart';

import 'helpers.dart';

/// BGM 状態機械のユニットテスト(docs/review-findings.md #22)。
/// FakeAudioPlayer を注入することで flutter test 下でも実物の遷移を検証する。
void main() {
  final synth = SoundSynth();
  var soundOn = true;
  late RecordingSfx rec;

  SfxPlayer build() {
    rec = RecordingSfx(enabled: () => soundOn);
    return rec.sfx;
  }

  test('durationFor matches the rendered wav length', () {
    // docs/review-findings.md #35: 再生時間はヘッダ44バイトを除いた
    // 16bit mono サンプル数 ÷ 22050Hz。
    final wav = synth.wavFor(Sfx.rewardJingle);
    final expectedUs = (wav.length - 44) ~/ 2 * 1000000 ~/ 22050;
    expect(synth.durationFor(Sfx.rewardJingle).inMicroseconds, expectedUs);
    expect(synth.durationFor(Sfx.tap), greaterThan(Duration.zero));
  });

  test('sfx playback is skipped entirely while muted', () async {
    soundOn = false;
    final player = build();
    await player.play(Sfx.tap);
    expect(rec.players, isEmpty); // ミュート中はプレイヤーすら作らない
  });

  test(
    'unmuting after a muted override starts the override track (bug #2)',
    () async {
      soundOn = false;
      final player = build();
      await player.startBgm();
      await player.playOverrideBgm(Sfx.bgmGame);
      final bgm = rec.players.single;
      expect(bgm.calls, isNot(contains('play'))); // ミュート中は鳴らさない

      soundOn = true;
      await player.syncBgm(); // ミュート解除(toggleSound 相当)
      // 音源未設定のまま resume() すると無音になる(#2 の回帰)。
      expect(bgm.calls, isNot(contains('resume')));
      expect(bgm.calls, contains('play'));
      expect(bgm.playedBytes.last, synth.wavFor(Sfx.bgmGame));
    },
  );

  test(
    'a failed play() recovers with a real play on the next sync (bug #49)',
    () async {
      // docs/review-findings.md #49: play() 失敗時に _bgmStarted が立ったまま
      // だと、以降 syncBgm() が音源の無いプレイヤーを resume し続けて無音が
      // 固定化する。失敗後の次の同期では play で音源を載せ直すこと。
      soundOn = true;
      final player = build();
      await player.startBgm();
      final bgm = rec.players.single;

      bgm.throwOnPlay = true;
      await player.playOverrideBgm(Sfx.bgmGame); // 失敗する(catch 済み)
      expect(bgm.calls.last, 'play-failed');

      bgm.throwOnPlay = false;
      await player.syncBgm();
      expect(bgm.calls.last, 'play', reason: 'resume ではなく音源を載せ直す');
      expect(bgm.playedBytes.last, synth.wavFor(Sfx.bgmGame));
    },
  );

  test('clearing the override returns to the selected bgm track', () async {
    soundOn = true;
    final player = build();
    await player.startBgm();
    final bgm = rec.players.single;
    expect(bgm.playedBytes.last, synth.wavFor(SfxPlayer.bgmTracks[0]));

    await player.playOverrideBgm(Sfx.bgmGame);
    expect(bgm.playedBytes.last, synth.wavFor(Sfx.bgmGame));

    await player.clearOverrideBgm();
    expect(bgm.playedBytes.last, synth.wavFor(SfxPlayer.bgmTracks[0]));
  });

  test(
    'clearing during a non-loop override lets the tune finish (bug #50)',
    () async {
      // docs/review-findings.md #50: 勝利曲(非ループ)の再生中に画面から
      // 戻っても曲を切らず、曲側のタイマーがホームBGMへ戻す。
      soundOn = true;
      final player = build();
      await player.startBgm();
      final bgm = rec.players.single;

      // 実時間で待てるよう短い音源で代用(タイマーは duration+300ms)
      await player.playOverrideBgm(Sfx.tap, loop: false);
      await player.clearOverrideBgm(); // 「もどる」相当
      expect(
        bgm.playedBytes.last,
        synth.wavFor(Sfx.tap),
        reason: '再生中の非ループ曲は切られない',
      );

      // 曲が終わればタイマーが選択中トラックへ戻す
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(bgm.playedBytes.last, synth.wavFor(SfxPlayer.bgmTracks[0]));
    },
  );

  test(
    'a jingle ducks the bgm and resumes it after the jingle ends (#54)',
    () async {
      // docs/review-findings.md #54: playJingle → pause → durationFor+250ms 後に
      // syncBgm で復帰する経路。実時間で待てるよう短い音源で代用。
      soundOn = true;
      final player = build();
      await player.startBgm();
      final bgm = rec.players.single; // ジングル用プレイヤーが増える前に捕まえる

      await player.playJingle(Sfx.tap);
      expect(bgm.calls.last, 'pause', reason: 'ジングル中はBGMを止める');

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(bgm.calls.last, 'resume', reason: 'ジングル後にBGMを再開する');
    },
  );

  test('playBabble plays one of the species voice variants (#54)', () async {
    soundOn = true;
    final player = build();
    await player.playBabble(3);
    final voice = rec.players.single;
    expect(voice.calls, contains('play'));
    final variants = [for (var v = 0; v < 3; v++) synth.wavForBabble(3, v)];
    expect(
      variants.any((w) => listEquals(w, voice.playedBytes.last)),
      isTrue,
      reason: '種族3の3バリエーションのいずれかが再生される',
    );
  });

  test('dispose disposes every created player (#54)', () async {
    soundOn = true;
    final player = build();
    await player.startBgm();
    await player.play(Sfx.tap);
    await player.playBabble(0);
    expect(rec.players, hasLength(3)); // bgm / sfx / voice
    player.dispose();
    for (final p in rec.players) {
      expect(p.calls.last, 'dispose');
    }
  });

  test('suspend pauses and resuming does not restart the track', () async {
    soundOn = true;
    final player = build();
    await player.startBgm();
    final bgm = rec.players.single;
    final plays = bgm.calls.where((c) => c == 'play').length;

    await player.syncBgm(suspend: true); // バックグラウンドへ
    expect(bgm.calls.last, 'pause');

    await player.syncBgm(); // 復帰
    expect(bgm.calls.last, 'resume');
    expect(bgm.calls.where((c) => c == 'play').length, plays); // 頭出ししない
  });
}

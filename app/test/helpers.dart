/// テスト共通ヘルパー(boot/drain/決定的Random/偽AudioPlayer)。
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/audio/sfx_player.dart';
import 'package:mokomon/audio/sound_synth.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/main.dart';
import 'package:mokomon/models/game_state.dart';

/// 単一画面を MaterialApp で包んで表示する(ミニゲーム画面テストの共通足場。
/// docs/review-findings.md #62)。
Future<void> pumpScreen(WidgetTester tester, Widget screen) =>
    tester.pumpWidget(MaterialApp(home: screen));

/// stage1 の標準テスト用コントローラ(ミニゲーム画面テストの既定。#62)。
GameController stage1Controller({int coins = 10, SfxPlayer? sfx}) =>
    GameController(
      GameState()
        ..stage = 1
        ..coins = coins,
      SaveStore(),
      sfx: sfx,
    );

/// ミニゲーム報酬後のタイマー掃除: 注入した SfxPlayer が張るジングル/勝利曲の
/// タイマーを、最長の曲(victoryTune)の実長+余裕の仮想時間で流す。
/// 報酬バランスが bigScoreCoins を跨いでも壊れない(docs/review-findings.md #64)。
Future<void> drainRewardJingle(WidgetTester tester) => tester.pump(
      SoundSynth().durationFor(Sfx.victoryTune) + const Duration(seconds: 1),
    );

/// 記録用 SfxPlayer の組み立て(FakeAudioPlayer 注入。#62)。
/// 生成された全プレイヤーは [players] に溜まる。
class RecordingSfx {
  RecordingSfx({bool Function()? enabled}) : _enabled = enabled ?? (() => true);
  final bool Function() _enabled;
  final players = <FakeAudioPlayer>[];
  late final SfxPlayer sfx = SfxPlayer(
    enabled: _enabled,
    bgmTrack: () => 0,
    playerFactory: () {
      final p = FakeAudioPlayer();
      players.add(p);
      return p;
    },
  );
}

/// 呼び出しを記録するだけの偽 AudioPlayer(プラグイン不要)。
/// `SfxPlayer(playerFactory: ...)` に注入して再生内容を検証する
/// (docs/review-findings.md #22)。
class FakeAudioPlayer extends Fake implements AudioPlayer {
  final calls = <String>[];
  final playedBytes = <Uint8List>[];

  /// true の間は play() が例外を投げる(再生失敗経路の検証用。#49)。
  var throwOnPlay = false;

  @override
  Future<void> setPlayerMode(PlayerMode playerMode) async {}

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (throwOnPlay) {
      calls.add('play-failed');
      throw Exception('play failed (injected)');
    }
    calls.add('play');
    playedBytes.add((source as BytesSource).bytes);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async =>
      calls.add('release');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

/// なでなでの6%💨判定を出さない決定的Random(フレーク防止)。
class NoPuffRandom implements Random {
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

/// nextDouble が固定値を返すテスト用 Random(💨の6%判定を制御する)。
class FixedRandom implements Random {
  final double value;
  FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

/// アプリ全体を起動してコントローラを返す。
/// いきものをタップするテストは rng に [NoPuffRandom] を渡して決定的にする。
Future<GameController> bootApp(
  WidgetTester tester, {
  GameState? state,
  Random? rng,
}) async {
  final c = GameController(state ?? GameState(), SaveStore(), rng: rng);
  await tester.pumpWidget(MokomonApp(controller: c));
  return c;
}

/// ホームのタイマー(ヒント・キラキラ等)を流してから画面を破棄する。
/// 常時アニメーションがあるため pumpAndSettle は使えない(docs/frontend.md)。
Future<void> drainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

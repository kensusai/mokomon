import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound_synth.dart';

/// flutter test 環境ではプラグインが無く AudioPlayer 生成自体が
/// 非同期例外を投げるため、再生を丸ごとスキップする。
final bool _isFlutterTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// 効果音プレイヤー(インフラ層)。合成WAVを audioplayers で再生する。
/// [enabled] でミュート設定(GameState.sound)を参照する。
class SfxPlayer {
  SfxPlayer({required this.enabled});

  final bool Function() enabled;
  final _synth = SoundSynth();
  final _players = <Sfx, AudioPlayer>{};

  AudioPlayer? _bgm;
  var _bgmStarted = false;

  Future<void> play(Sfx sfx) async {
    if (_isFlutterTest || !enabled()) return;
    try {
      final player = _players.putIfAbsent(
          sfx, () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
      await player.stop();
      await player.play(BytesSource(_synth.wavFor(sfx), mimeType: 'audio/wav'));
    } catch (e) {
      // 効果音の失敗でゲームを止めない
      debugPrint('sfx failed: $e');
    }
  }

  /// BGMのループ再生を開始する(ミュート中は待機)。
  Future<void> startBgm() async {
    if (_isFlutterTest) return;
    try {
      _bgm ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await syncBgm();
    } catch (e) {
      debugPrint('bgm failed: $e');
    }
  }

  /// ミュート設定・ライフサイクルに合わせてBGMを再生/停止する。
  /// [suspend] はアプリのバックグラウンド時に true。
  Future<void> syncBgm({bool suspend = false}) async {
    final player = _bgm;
    if (_isFlutterTest || player == null) return;
    try {
      if (!suspend && enabled()) {
        if (_bgmStarted) {
          await player.resume();
        } else {
          _bgmStarted = true;
          await player
              .play(BytesSource(_synth.wavFor(Sfx.bgm), mimeType: 'audio/wav'));
        }
      } else {
        await player.pause();
      }
    } catch (e) {
      debugPrint('bgm failed: $e');
    }
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _bgm?.dispose();
  }
}

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

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
  }
}

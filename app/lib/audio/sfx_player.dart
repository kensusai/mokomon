import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound_synth.dart';

/// flutter test 環境ではプラグインが無く AudioPlayer 生成自体が
/// 非同期例外を投げるため、再生を丸ごとスキップする。
final bool _isFlutterTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// 効果音プレイヤー(インフラ層)。合成WAVを audioplayers で再生する。
/// [enabled] はミュート設定、[bgmTrack] は選択中のBGM(GameState参照)。
class SfxPlayer {
  SfxPlayer({required this.enabled, this.bgmTrack});

  /// 選択できるBGMトラック(GameState.bgmTrack の index に対応)。
  static const bgmTracks = [Sfx.bgm, Sfx.bgm2, Sfx.bgm3];

  final bool Function() enabled;
  final int Function()? bgmTrack;
  final _synth = SoundSynth();
  final _players = <Sfx, AudioPlayer>{};
  final _rng = Random();

  AudioPlayer? _bgm;
  AudioPlayer? _voice;
  var _bgmStarted = false;
  Timer? _duckTimer;

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

  /// いきもののバブル音声(種族ごとの声・3バリエーションからランダム)。
  Future<void> playBabble(int species) async {
    if (_isFlutterTest || !enabled()) return;
    try {
      _voice ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _voice!.stop();
      await _voice!.play(BytesSource(
          _synth.wavForBabble(species, _rng.nextInt(3)),
          mimeType: 'audio/wav'));
    } catch (e) {
      debugPrint('sfx failed: $e');
    }
  }

  /// 派手ジングル: 鳴っている間はBGMを止めて主役にする。
  Future<void> playJingle(Sfx sfx) async {
    if (_isFlutterTest) return;
    final wav = _synth.wavFor(sfx);
    final seconds = (wav.length - 44) / 2 / 22050;
    play(sfx);
    try {
      await _bgm?.pause();
    } catch (_) {}
    _duckTimer?.cancel();
    _duckTimer =
        Timer(Duration(milliseconds: (seconds * 1000).round() + 250), syncBgm);
  }

  /// BGMトラック変更を反映する(再生し直す)。
  Future<void> restartBgm() async {
    if (_isFlutterTest) return;
    try {
      await _bgm?.stop();
      _bgmStarted = false;
      await syncBgm();
    } catch (e) {
      debugPrint('bgm failed: $e');
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
          final track =
              bgmTracks[(bgmTrack?.call() ?? 0).clamp(0, bgmTracks.length - 1)];
          await player
              .play(BytesSource(_synth.wavFor(track), mimeType: 'audio/wav'));
        }
      } else {
        await player.pause();
      }
    } catch (e) {
      debugPrint('bgm failed: $e');
    }
  }

  void dispose() {
    _duckTimer?.cancel();
    for (final p in _players.values) {
      p.dispose();
    }
    _voice?.dispose();
    _bgm?.dispose();
  }
}

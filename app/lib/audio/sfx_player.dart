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
///
/// [playerFactory] はテスト専用のフック: 偽 AudioPlayer を注入すると
/// flutter test 下でも BGM 状態機械を実際に動かして検証できる
/// (docs/review-findings.md #22)。未指定ならテスト環境では全メソッドが
/// no-op になる(widget test がプラグイン無しで動くための既定挙動)。
class SfxPlayer {
  SfxPlayer({required this.enabled, this.bgmTrack, this.playerFactory});

  /// 選択できるBGMトラック(GameState.bgmTrack の index に対応)。
  static const bgmTracks = [Sfx.bgm, Sfx.bgm2, Sfx.bgm3];

  final bool Function() enabled;
  final int Function()? bgmTrack;
  final AudioPlayer Function()? playerFactory;
  final _synth = SoundSynth();
  final _players = <Sfx, AudioPlayer>{};
  final _rng = Random();

  AudioPlayer _createPlayer() => (playerFactory ?? AudioPlayer.new)();
  bool get _disabled => playerFactory == null && _isFlutterTest;

  AudioPlayer? _bgm;
  AudioPlayer? _voice;
  var _bgmStarted = false;
  Timer? _duckTimer;
  Sfx? _overrideTrack; // ゲームBGM・勝利曲など一時的な差し替え
  Timer? _overrideTimer;

  Future<void> play(Sfx sfx) async {
    if (_disabled || !enabled()) return;
    try {
      final player = _players.putIfAbsent(
        sfx,
        () => _createPlayer()..setPlayerMode(PlayerMode.lowLatency),
      );
      await player.stop();
      await player.play(BytesSource(_synth.wavFor(sfx), mimeType: 'audio/wav'));
    } catch (e) {
      // 効果音の失敗でゲームを止めない
      debugPrint('sfx failed: $e');
    }
  }

  /// いきもののバブル音声(種族ごとの声・3バリエーションからランダム)。
  Future<void> playBabble(int species) async {
    if (_disabled || !enabled()) return;
    try {
      _voice ??= _createPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _voice!.stop();
      await _voice!.play(
        BytesSource(
          _synth.wavForBabble(species, _rng.nextInt(3)),
          mimeType: 'audio/wav',
        ),
      );
    } catch (e) {
      debugPrint('sfx failed: $e');
    }
  }

  /// 派手ジングル: 鳴っている間はBGMを止めて主役にする。
  Future<void> playJingle(Sfx sfx) async {
    if (_disabled) return;
    play(sfx);
    try {
      await _bgm?.pause();
    } catch (_) {}
    _duckTimer?.cancel();
    _duckTimer = Timer(
      _synth.durationFor(sfx) + const Duration(milliseconds: 250),
      syncBgm,
    );
  }

  /// BGMを一時的に差し替える(ゲームBGM・勝利曲)。
  /// [loop] が false のときは曲が終わると自動で元のBGMへ戻る。
  Future<void> playOverrideBgm(Sfx track, {bool loop = true}) async {
    if (_disabled) return;
    _overrideTimer?.cancel();
    _overrideTrack = track;
    try {
      _bgm ??= _createPlayer();
      await _bgm!.stop();
      await _bgm!.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      // stop() で音源が外れるので、いったん「再生中でない」扱いにする。
      // フラグは再生に**成功してから**立てる。先に立てると、ミュート中や
      // play() 失敗時に syncBgm() が音源未設定のまま resume() してしまい
      // 無音が固定化する(docs/review-findings.md #2, #49)。
      _bgmStarted = false;
      if (enabled()) {
        await _bgm!.play(
          BytesSource(_synth.wavFor(track), mimeType: 'audio/wav'),
        );
        _bgmStarted = true;
      }
      if (!loop) {
        _overrideTimer = Timer(
          _synth.durationFor(track) + const Duration(milliseconds: 300),
          () {
            if (_overrideTrack == track) clearOverrideBgm();
          },
        );
      }
    } catch (e) {
      debugPrint('bgm failed: $e');
    }
  }

  /// 差し替えを解除して通常のBGM(選択中トラック)に戻す。
  /// 非ループの一時曲(勝利曲)が再生中の場合は途中で切らず、曲側の
  /// タイマーによる自動復帰に任せる(docs/review-findings.md #50)。
  Future<void> clearOverrideBgm() async {
    if (_disabled) return;
    if (_overrideTimer?.isActive ?? false) return;
    _overrideTimer?.cancel();
    _overrideTrack = null;
    try {
      await _bgm?.setReleaseMode(ReleaseMode.loop);
    } catch (_) {}
    await restartBgm();
  }

  /// BGMトラック変更を反映する(再生し直す)。
  Future<void> restartBgm() async {
    if (_disabled) return;
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
    if (_disabled) return;
    try {
      _bgm ??= _createPlayer()..setReleaseMode(ReleaseMode.loop);
      await syncBgm();
    } catch (e) {
      debugPrint('bgm failed: $e');
    }
  }

  /// ミュート設定・ライフサイクルに合わせてBGMを再生/停止する。
  /// [suspend] はアプリのバックグラウンド時に true。
  Future<void> syncBgm({bool suspend = false}) async {
    final player = _bgm;
    if (_disabled || player == null) return;
    try {
      if (!suspend && enabled()) {
        if (_bgmStarted) {
          await player.resume();
        } else {
          final track = _overrideTrack ??
              bgmTracks[(bgmTrack?.call() ?? 0).clamp(0, bgmTracks.length - 1)];
          await player.play(
            BytesSource(_synth.wavFor(track), mimeType: 'audio/wav'),
          );
          // 成功してから立てる(play() 失敗時に無音が固定化しないように。#49)
          _bgmStarted = true;
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
    _overrideTimer?.cancel();
    for (final p in _players.values) {
      p.dispose();
    }
    _voice?.dispose();
    _bgm?.dispose();
  }
}

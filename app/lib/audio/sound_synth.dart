import 'dart:math';
import 'dart:typed_data';

/// 効果音の種類(docs/game-design.md §10)。
/// coo/giggle はなでなでの鳴き声、bgm はホームのループ曲。
enum Sfx {
  tap,
  coin,
  munch,
  happy,
  wrong,
  pop,
  fanfare,
  evoRiser,
  shine,
  puff,
  coo,
  giggle,
  bgm,
}

enum _Wave { sine, square, sawtooth, triangle }

/// WebAudio の tone(freq, dur, type, vol, delay) 1回分。
class _Tone {
  final double freq;
  final double dur;
  final _Wave wave;
  final double vol;
  final double delay;
  const _Tone(this.freq, this.dur, this.wave, this.vol, [this.delay = 0]);
}

/// プロトタイプの sfx 定義をそのまま移植。
final Map<Sfx, List<_Tone>> _recipes = {
  Sfx.tap: const [_Tone(600, 0.06, _Wave.sine, 0.1)],
  Sfx.coin: const [
    _Tone(880, 0.08, _Wave.square, 0.06),
    _Tone(1320, 0.12, _Wave.square, 0.06, 0.07),
  ],
  Sfx.munch: const [
    _Tone(300, 0.08, _Wave.sawtooth, 0.08),
    _Tone(260, 0.08, _Wave.sawtooth, 0.08, 0.12),
    _Tone(300, 0.1, _Wave.sawtooth, 0.08, 0.24),
  ],
  Sfx.happy: const [
    _Tone(660, 0.1, _Wave.sine, 0.14),
    _Tone(830, 0.1, _Wave.sine, 0.14, 0.09),
    _Tone(990, 0.16, _Wave.sine, 0.14, 0.18),
  ],
  Sfx.wrong: const [_Tone(220, 0.18, _Wave.square, 0.05)],
  Sfx.pop: const [
    _Tone(500, 0.05, _Wave.triangle, 0.12),
    _Tone(750, 0.07, _Wave.triangle, 0.12, 0.05),
  ],
  // ファンファーレ: 4和音上昇+トップ音
  Sfx.fanfare: const [
    _Tone(523, 0.22, _Wave.triangle, 0.13),
    _Tone(659, 0.22, _Wave.triangle, 0.13, 0.13),
    _Tone(784, 0.22, _Wave.triangle, 0.13, 0.26),
    _Tone(1047, 0.22, _Wave.triangle, 0.13, 0.39),
    _Tone(1319, 0.5, _Wave.triangle, 0.13, 0.55),
  ],
  // 進化の上昇音階(180Hz→1080Hz、13音)
  Sfx.evoRiser: [
    for (var i = 0; i < 13; i++)
      _Tone(180.0 + i * 75, 0.14, _Wave.square, 0.07, i * 0.17),
  ],
  Sfx.shine: const [_Tone(1400, 0.5, _Wave.sine, 0.15)],
  // 💨: 低い下降音3連(のこぎり波)
  Sfx.puff: const [
    _Tone(165, 0.09, _Wave.sawtooth, 0.13),
    _Tone(128, 0.09, _Wave.sawtooth, 0.13, 0.10),
    _Tone(92, 0.18, _Wave.sawtooth, 0.13, 0.20),
  ],
  // なでなでの鳴き声: やわらかい2音(くぅ〜ん)
  Sfx.coo: const [
    _Tone(523, 0.10, _Wave.sine, 0.12),
    _Tone(659, 0.16, _Wave.sine, 0.12, 0.09),
  ],
  // なでなでの鳴き声: 笑い声風の3連(きゃはっ)
  Sfx.giggle: const [
    _Tone(700, 0.06, _Wave.triangle, 0.11),
    _Tone(880, 0.06, _Wave.triangle, 0.11, 0.07),
    _Tone(1047, 0.09, _Wave.triangle, 0.11, 0.14),
  ],
  // ホームBGM: ペンタトニックのやさしいループ(約19秒)
  Sfx.bgm: _bgmTones(),
};

// ---------- BGM(実行時合成のチップチューン風ループ) ----------

const _bpm = 100.0;
const _beat = 60.0 / _bpm; // 1拍 = 0.6秒

/// メロディ(三角波)+ベース(サイン波)の8小節ループを _Tone 列で組み立てる。
/// 音量はSFXよりかなり小さく(BGMは背景に徹する)。
List<_Tone> _bgmTones() {
  // C メジャーペンタトニック中心。0 は休符。
  const melody = [
    // 小節1-2
    523, 659, 784, 659, 880, 784, 659, 587,
    // 小節3-4
    523, 659, 784, 880, 784, 659, 587, 523,
    // 小節5-6
    659, 784, 880, 1047, 880, 784, 659, 784,
    // 小節7-8(終止形でループ頭へ戻る)
    880, 784, 659, 587, 523, 587, 659, 0,
  ];
  // ベースは1小節(4拍)ごとに1音
  const bass = [131.0, 175.0, 147.0, 196.0, 131.0, 175.0, 196.0, 131.0];

  final tones = <_Tone>[];
  for (var i = 0; i < melody.length; i++) {
    if (melody[i] == 0) continue;
    tones.add(_Tone(
        melody[i].toDouble(), _beat * 0.9, _Wave.triangle, 0.045, i * _beat));
  }
  for (var bar = 0; bar < bass.length; bar++) {
    tones.add(_Tone(bass[bar], _beat * 3.6, _Wave.sine, 0.05, bar * 4 * _beat));
  }
  return tones;
}

const _sampleRate = 22050;

/// 効果音を 16bit PCM WAV バイト列として合成する(実行時・アセット不要)。
/// 再生は audioplayers の BytesSource(呼び出し側)。
class SoundSynth {
  final _cache = <Sfx, Uint8List>{};

  Uint8List wavFor(Sfx sfx) => _cache.putIfAbsent(sfx, () => _render(sfx));

  Uint8List _render(Sfx sfx) {
    final tones = _recipes[sfx]!;
    var totalSec = 0.0;
    for (final t in tones) {
      totalSec = max(totalSec, t.delay + t.dur + 0.03);
    }
    final n = (totalSec * _sampleRate).ceil();
    final mix = Float64List(n);

    for (final t in tones) {
      final start = (t.delay * _sampleRate).round();
      final len = (t.dur * _sampleRate).round();
      for (var i = 0; i < len && start + i < n; i++) {
        final time = i / _sampleRate;
        // exponentialRampToValueAtTime(0.001) 相当の減衰
        final env = t.vol * pow(0.001 / t.vol, time / t.dur);
        mix[start + i] += _sample(t.wave, t.freq, time) * env;
      }
    }

    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      pcm[i] = (mix[i].clamp(-1.0, 1.0) * 32767).round();
    }
    return _wrapWav(pcm);
  }

  double _sample(_Wave wave, double freq, double time) {
    final phase = (time * freq) % 1.0;
    switch (wave) {
      case _Wave.sine:
        return sin(2 * pi * phase);
      case _Wave.square:
        return phase < 0.5 ? 1.0 : -1.0;
      case _Wave.sawtooth:
        return 2 * phase - 1;
      case _Wave.triangle:
        return phase < 0.5 ? 4 * phase - 1 : 3 - 4 * phase;
    }
  }

  /// モノラル 16bit PCM を WAV コンテナに包む。
  Uint8List _wrapWav(Int16List pcm) {
    final dataLen = pcm.length * 2;
    final bytes = ByteData(44 + dataLen);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLen, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // fmt チャンクサイズ
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // モノラル
    bytes.setUint32(24, _sampleRate, Endian.little);
    bytes.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    bytes.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      bytes.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}

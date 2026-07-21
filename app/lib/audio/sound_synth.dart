import 'dart:math';
import 'dart:typed_data';

/// 効果音の種類(docs/game-design.md §10)。
/// megaFanfare〜dressUp は派手ジングル、bgm* はループ曲。
/// なでなでの鳴き声は種族別の [SoundSynth.wavForBabble] が担う。
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
  megaFanfare,
  rewardJingle,
  dressUp,
  bgm,
  bgm2,
  bgm3,
  bgmGame,
  bgmGame2,
  bgmPaint,
  victoryTune,
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

/// 和音: 複数周波数に同じ長さ・音量の _Tone を追加する。
void _addChord(
  List<_Tone> tones,
  List<num> freqs,
  double at,
  double dur, [
  double vol = 0.1,
  _Wave wave = _Wave.triangle,
]) {
  for (final f in freqs) {
    tones.add(_Tone(f.toDouble(), dur, wave, vol, at));
  }
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
  // 💨: 低い下降音「ブゥ〜ブブブッ」(こどもFBでおなら感アップ)
  Sfx.puff: const [
    _Tone(155, 0.14, _Wave.sawtooth, 0.15),
    _Tone(150, 0.14, _Wave.sawtooth, 0.12, 0.03), // うなり(ビート)
    _Tone(118, 0.12, _Wave.sawtooth, 0.15, 0.18),
    _Tone(95, 0.13, _Wave.sawtooth, 0.15, 0.33),
    _Tone(78, 0.2, _Wave.sawtooth, 0.16, 0.48),
    _Tone(66, 0.16, _Wave.sawtooth, 0.12, 0.55),
  ],
  // 進化リビール用メガファンファーレ(駆け上がり+和音3連+シャンシャン)
  Sfx.megaFanfare: _megaFanfareTones(),
  // ミニゲーム報酬「タタタ・ジャーン!」+キラキラ
  Sfx.rewardJingle: const [
    _Tone(659, 0.11, _Wave.triangle, 0.12),
    _Tone(659, 0.11, _Wave.triangle, 0.12, 0.14),
    _Tone(659, 0.11, _Wave.triangle, 0.12, 0.28),
    _Tone(880, 0.55, _Wave.triangle, 0.13, 0.45),
    _Tone(220, 0.5, _Wave.sine, 0.09, 0.45),
    _Tone(1760, 0.1, _Wave.sine, 0.07, 0.62),
    _Tone(2093, 0.14, _Wave.sine, 0.07, 0.78),
  ],
  // きせかえのハープ風グリッサンド+ベル
  Sfx.dressUp: const [
    _Tone(523, 0.16, _Wave.sine, 0.1),
    _Tone(659, 0.16, _Wave.sine, 0.1, 0.08),
    _Tone(784, 0.16, _Wave.sine, 0.1, 0.16),
    _Tone(1047, 0.16, _Wave.sine, 0.1, 0.24),
    _Tone(1319, 0.2, _Wave.sine, 0.1, 0.32),
    _Tone(1568, 0.4, _Wave.triangle, 0.09, 0.5),
  ],
  // ホームBGM 3曲(docs/game-design.md §10)
  Sfx.bgm: _bgmTones(),
  Sfx.bgm2: _bgm2Tones(),
  Sfx.bgm3: _bgm3Tones(),
  // ミニゲーム中の専用BGM(疾走感・ループ)。2曲からランダム
  Sfx.bgmGame: _bgmGameTones(),
  Sfx.bgmGame2: _bgmGame2Tones(),
  // おえかき中のまったり曲(オルゴール風アルペジオ)
  Sfx.bgmPaint: _bgmPaintTones(),
  // ハイスコア・進化リビール用の勝利曲(約9秒・ループしない)
  Sfx.victoryTune: _victoryTuneTones(),
};

/// ゲームBGM: 140bpmで駆けるスクエアリード+刻むベース。
List<_Tone> _bgmGameTones() {
  // 8分音符 ≒ 0.214s(140bpm)
  return _song(
    melody: const [
      659,
      784,
      880,
      784,
      1047,
      880,
      784,
      659,
      587,
      659,
      784,
      880,
      784,
      659,
      587,
      523,
      659,
      784,
      880,
      1047,
      1175,
      1047,
      880,
      784,
      880,
      784,
      659,
      587,
      659,
      587,
      523,
      587,
    ],
    melodyBeat: 0.214,
    melodyWave: _Wave.square,
    melodyVol: 0.032,
    bass: const [
      131,
      175,
      196,
      175,
      131,
      175,
      196,
      196,
      131,
      175,
      196,
      175,
      147,
      175,
      131,
      131,
    ],
    bassBeat: 0.428,
    bassVol: 0.06,
  );
}

/// ゲームBGM2: 120bpmのはずむポップ(三角波リード+スクエアベース)。
List<_Tone> _bgmGame2Tones() {
  return _song(
    melody: const [
      523,
      659,
      523,
      784,
      659,
      880,
      784,
      659,
      587,
      784,
      587,
      880,
      784,
      1047,
      880,
      784,
      659,
      880,
      659,
      1047,
      880,
      1175,
      1047,
      880,
      784,
      659,
      587,
      659,
      523,
      587,
      659,
      523,
    ],
    melodyBeat: 0.25,
    melodyWave: _Wave.triangle,
    melodyVol: 0.055,
    bass: const [
      131,
      196,
      175,
      196,
      131,
      196,
      175,
      196,
      147,
      196,
      175,
      196,
      131,
      175,
      147,
      131,
    ],
    bassBeat: 0.5,
    bassVol: 0.045,
  );
}

/// おえかきBGM: 84bpmのやさしいアルペジオ(サイン波)。
List<_Tone> _bgmPaintTones() {
  const beat = 60.0 / 84 / 2; // 8分 ≒ 0.357s
  return _song(
    melody: const [
      523,
      659,
      784,
      659,
      880,
      784,
      659,
      784,
      440,
      587,
      659,
      587,
      784,
      659,
      587,
      659,
      523,
      659,
      784,
      659,
      1047,
      880,
      784,
      659,
      587,
      659,
      587,
      523,
      440,
      523,
      587,
      523,
    ],
    melodyBeat: beat,
    melodyWave: _Wave.sine,
    melodyVol: 0.05,
    bass: const [131, 147, 175, 131],
    bassBeat: beat * 8,
    bassVol: 0.05,
  );
}

/// 勝利曲: ファンファーレ導入 → 明るいメロディ → 大団円(約9秒)。
List<_Tone> _victoryTuneTones() {
  final tones = <_Tone>[];
  // 導入の駆け上がり
  const run = <double>[523, 659, 784, 1047];
  for (var i = 0; i < run.length; i++) {
    tones.add(_Tone(run[i], 0.14, _Wave.square, 0.08, i * 0.09));
  }
  // 和音ドン!
  _addChord(tones, const [523, 659, 784], 0.5, 0.5);
  tones.add(const _Tone(131, 0.5, _Wave.sine, 0.07, 0.5));
  // メロディ(100bpm)
  const beat = 0.6;
  const melody = [
    784,
    880,
    1047,
    880,
    784,
    659,
    784,
    880,
    1047,
    1175,
    1047,
    880,
  ];
  const bass = <double>[175, 196, 131, 175, 196, 131];
  for (var i = 0; i < melody.length; i++) {
    tones.add(
      _Tone(
        melody[i].toDouble(),
        beat * 0.9,
        _Wave.triangle,
        0.07,
        1.3 + i * beat * 0.5,
      ),
    );
  }
  for (var i = 0; i < bass.length; i++) {
    tones.add(_Tone(bass[i], beat * 0.9, _Wave.sine, 0.06, 1.3 + i * beat));
  }
  // 大団円の和音+シャンシャン
  const endAt = 1.3 + 12 * 0.3 + 0.3; // ≒ 5.2
  _addChord(tones, const [523, 659, 784, 1047], endAt, 1.6, 0.11);
  tones.add(const _Tone(1319, 1.6, _Wave.triangle, 0.09, endAt));
  tones.add(const _Tone(1568, 1.2, _Wave.sine, 0.08, endAt + 0.3));
  tones.add(const _Tone(2093, 0.9, _Wave.sine, 0.06, endAt + 0.6));
  tones.add(const _Tone(131, 1.6, _Wave.sine, 0.08, endAt));
  return tones;
}

/// メガファンファーレ: 8音駆け上がり → 和音2連 → ロング和音+高音シャンシャン
List<_Tone> _megaFanfareTones() {
  const run = <double>[392, 440, 523, 587, 659, 698, 784, 880];
  final tones = <_Tone>[
    for (var i = 0; i < run.length; i++)
      _Tone(run[i], 0.1, _Wave.square, 0.07, i * 0.07),
  ];
  _addChord(tones, const [523, 659, 784], 0.66, 0.28);
  _addChord(tones, const [587, 740, 880], 0.98, 0.28);
  _addChord(tones, const [523, 659, 784, 1047], 1.32, 0.85, 0.11);
  tones.add(const _Tone(1568, 0.8, _Wave.sine, 0.08, 1.32));
  tones.add(const _Tone(2093, 0.5, _Wave.sine, 0.06, 1.6));
  return tones;
}

// ---------- BGM(実行時合成のチップチューン風ループ) ----------

const _bpm = 100.0;
const _beat = 60.0 / _bpm; // 1拍 = 0.6秒

/// メロディ+ベースの音列からBGM用 _Tone 列を組み立てる共通処理。
List<_Tone> _song({
  required List<num> melody,
  required double melodyBeat,
  required _Wave melodyWave,
  required double melodyVol,
  required List<num> bass,
  required double bassBeat,
  required double bassVol,
}) {
  final tones = <_Tone>[];
  for (var i = 0; i < melody.length; i++) {
    if (melody[i] == 0) continue;
    tones.add(
      _Tone(
        melody[i].toDouble(),
        melodyBeat * 0.9,
        melodyWave,
        melodyVol,
        i * melodyBeat,
      ),
    );
  }
  for (var i = 0; i < bass.length; i++) {
    tones.add(
      _Tone(
        bass[i].toDouble(),
        bassBeat * 0.9,
        _Wave.sine,
        bassVol,
        i * bassBeat,
      ),
    );
  }
  return tones;
}

/// BGM2「わくわく」: アップテンポ(132bpm)の跳ねるスクエアリード。
List<_Tone> _bgm2Tones() {
  // 8分音符 ≒ 0.227s(132bpm)で軽快に
  return _song(
    melody: const [
      523,
      784,
      659,
      784,
      880,
      784,
      659,
      523,
      587,
      659,
      587,
      523,
      659,
      523,
      440,
      523,
      523,
      784,
      659,
      784,
      880,
      1047,
      880,
      784,
      659,
      784,
      880,
      1047,
      784,
      659,
      587,
      523,
    ],
    melodyBeat: 0.227,
    melodyWave: _Wave.square,
    melodyVol: 0.03,
    bass: const [
      131,
      131,
      196,
      196,
      175,
      175,
      196,
      196,
      131,
      131,
      196,
      196,
      175,
      196,
      131,
      131,
    ],
    bassBeat: 0.454,
    bassVol: 0.05,
  );
}

/// BGM3「ぽかぽか」: ゆったり(76bpm)のオルゴール風サインリード。
List<_Tone> _bgm3Tones() {
  const beat = 60.0 / 76; // 0.789s
  return _song(
    melody: const [
      659,
      587,
      523,
      587,
      659,
      659,
      587,
      523,
      440,
      523,
      587,
      523,
      440,
      392,
      440,
      523,
    ],
    melodyBeat: beat,
    melodyWave: _Wave.sine,
    melodyVol: 0.055,
    bass: const [131, 175, 147, 131],
    bassBeat: beat * 4,
    bassVol: 0.05,
  );
}

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
  const bass = [131.0, 175.0, 147.0, 196.0, 131.0, 175.0, 196.0, 131.0];

  // ベースは1小節(4拍)ごとに1音 = bassBeat を4拍にすれば _song と同じ配置
  return _song(
    melody: melody,
    melodyBeat: _beat,
    melodyWave: _Wave.triangle,
    melodyVol: 0.045,
    bass: bass,
    bassBeat: _beat * 4,
    bassVol: 0.05,
  );
}

const _sampleRate = 22050;

/// 種族ごとの「声の高さ」(Hz)。しゃべり声はこれを基準に合成する。
///
/// 42Hz刻みで9段だけ用意していたため、10体目以降が `species % 9` で1体目から
/// 順に同じ高さへ折り返し、種族を追加するたびに「声が変わらない」いきものが
/// 増えていた。9体を1周として、周ごとに14Hzずらすことで全種族を別の高さにする
/// (既存9体の高さは変えない)。3周目で42Hzに達し衝突するため、種族が27体を
/// 超えるときは段数を見直すこと — `polish_test.dart` が衝突を検知する。
double babbleBaseFreq(int species) =>
    300.0 + (species % 9) * 42 + (species ~/ 9) * 14;

/// 効果音を 16bit PCM WAV バイト列として合成する(実行時・アセット不要)。
/// 再生は audioplayers の BytesSource(呼び出し側)。
class SoundSynth {
  final _cache = <Sfx, Uint8List>{};
  final _babbleCache = <int, Uint8List>{};

  Uint8List wavFor(Sfx sfx) =>
      _cache.putIfAbsent(sfx, () => _render(_recipes[sfx]!));

  /// [sfx] の再生時間。ヘッダ44バイトを除いた 16bit mono サンプル数から
  /// 求める。ジングル復帰・override 解除のタイマーはこれを使うこと —
  /// サンプルレートを変えたときに時間計算が無言でずれないように
  /// (docs/review-findings.md #35)。
  Duration durationFor(Sfx sfx) {
    final samples = (wavFor(sfx).length - 44) ~/ 2;
    return Duration(microseconds: samples * 1000000 ~/ _sampleRate);
  }

  /// しゃべり風バブル音声(どうぶつの森式)。種族ごとに声の高さが変わり、
  /// variant(0-2)で毎回すこし違う「喋り」になる。決定的に生成しキャッシュ。
  Uint8List wavForBabble(int species, int variant) {
    return _babbleCache.putIfAbsent(species * 16 + variant, () {
      final rng = Random(species * 31 + variant * 7 + 5);
      final base = babbleBaseFreq(species);
      final syllables = 5 + rng.nextInt(4);
      final tones = <_Tone>[];
      var t = 0.0;
      for (var i = 0; i < syllables; i++) {
        final f = base * (0.85 + rng.nextDouble() * 0.85);
        final dur = 0.07 + rng.nextDouble() * 0.06;
        tones.add(_Tone(f, dur, _Wave.triangle, 0.17, t));
        tones.add(_Tone(f * 2, dur, _Wave.sine, 0.07, t)); // 倍音で声らしく
        t += dur + 0.02 + rng.nextDouble() * 0.04;
      }
      return _render(tones);
    });
  }

  Uint8List _render(List<_Tone> tones) {
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

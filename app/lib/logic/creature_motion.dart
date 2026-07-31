/// ホームのいきもの回遊(docs/game-design.md §3)。
/// 位置・傾きは時間の純関数として計算する(乱数・状態を持たないので
/// テストが決定的になり、Ticker の経過秒をそのまま渡せばよい)。
library;

import 'dart:math';
import 'dart:ui';

/// 動きの型。種族の性格に合わせて割り当てる([motionStyleFor])。
enum MotionStyle {
  /// ふわふわ宙を漂う(もこ・めだま・おばけ)
  floaty,

  /// 地面からぴょんぴょん跳ねる(ぴょん・にゃん)
  hopper,

  /// 横に大きくすいすい泳ぐ(とげ・ぱく・ろぼ)
  swimmer,

  /// くるくる輪を描く(ぴか・もじゃ・ぐる・ゆに)
  circler,

  /// 地面ちかくでのんびり(べろ・ぶう・だんでぃ・ねむ)
  lazy,
}

/// 種族 index → 動きの型。種族は speciesList の末尾にのみ追加される
/// 不変条件があるため、このリストの並びは speciesList と対応する。
/// リスト外(将来の種族)は index の剰余でフォールバックする。
const _styleByIndex = [
  MotionStyle.floaty, // moko
  MotionStyle.hopper, // pyon
  MotionStyle.swimmer, // toge
  MotionStyle.circler, // pika
  MotionStyle.lazy, // bero
  MotionStyle.lazy, // buu
  MotionStyle.floaty, // medama
  MotionStyle.hopper, // nyan
  MotionStyle.lazy, // dandy
  MotionStyle.circler, // mojya
  MotionStyle.circler, // guru
  MotionStyle.swimmer, // paku
  MotionStyle.lazy, // nemu
  MotionStyle.swimmer, // robo
  MotionStyle.floaty, // obake
  MotionStyle.circler, // yuni
];

/// [species] の動きの型を返す。
MotionStyle motionStyleFor(int species) => species < _styleByIndex.length
    ? _styleByIndex[species]
    : MotionStyle.values[species % MotionStyle.values.length];

/// いきもの1体ぶんの回遊。[at] が Alignment 座標系(-1..1)の位置を返す。
/// 同じ型でも種族ごとに速さ([_speed])と位相([_phase])が違うので、
/// 全種族が固有の軌道になる。地面は y=0.85(ホームの従来アンカー)。
class CreatureMotion {
  CreatureMotion(int species)
    : style = motionStyleFor(species),
      _phase = species * 0.9,
      _speed = 0.8 + 0.05 * (species % 7);

  final MotionStyle style;
  final double _phase;
  final double _speed;

  /// 経過 [t] 秒での位置(Alignment 座標系)。
  Offset at(double t) {
    final w = t * _speed;
    switch (style) {
      case MotionStyle.floaty:
        return Offset(
          0.75 * sin(w * 0.35 + _phase) + 0.15 * sin(w * 0.9 + _phase * 2),
          0.25 + 0.5 * sin(w * 0.23 + _phase * 1.7),
        );
      case MotionStyle.hopper:
        return Offset(
          0.8 * sin(w * 0.3 + _phase),
          0.85 - 0.45 * sin(w * 1.1 + _phase).abs(),
        );
      case MotionStyle.swimmer:
        return Offset(
          0.9 * sin(w * 0.55 + _phase),
          0.35 + 0.35 * sin(w * 0.9 + _phase * 1.3),
        );
      case MotionStyle.circler:
        return Offset(
          0.7 * sin(w * 0.5 + _phase),
          0.35 + 0.42 * cos(w * 0.5 + _phase),
        );
      case MotionStyle.lazy:
        return Offset(
          0.35 * sin(w * 0.13 + _phase),
          0.78 + 0.07 * sin(w * 0.5 + _phase),
        );
    }
  }

  /// 進行方向に合わせた軽い傾き(ラジアン)。数値微分で向きを出し、
  /// 型ごとの係数を掛けて ±0.16 に抑える(ぴょんぴょんは直立のまま)。
  double tiltAt(double t) {
    final k = switch (style) {
      MotionStyle.swimmer => 0.35,
      MotionStyle.circler => 0.22,
      MotionStyle.floaty => 0.18,
      MotionStyle.lazy => 0.1,
      MotionStyle.hopper => 0.0,
    };
    if (k == 0) return 0;
    final dx = (at(t + 0.15).dx - at(t).dx) / 0.15;
    return (dx * k).clamp(-0.16, 0.16);
  }
}

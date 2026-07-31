import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/logic/creature_motion.dart';

/// ホームのいきもの回遊(docs/game-design.md §3)。
/// 位置は時間の純関数: Alignment 座標系(x,y とも -1..1)で返る。
void main() {
  test('every species stays inside the stage bounds', () {
    for (var sp = 0; sp < speciesList.length; sp++) {
      final m = CreatureMotion(sp);
      for (var t = 0.0; t < 90; t += 0.05) {
        final p = m.at(t);
        expect(p.dx, inInclusiveRange(-0.95, 0.95), reason: 'species=$sp t=$t');
        expect(p.dy, inInclusiveRange(-0.4, 0.9), reason: 'species=$sp t=$t');
      }
    }
  });

  test('movement is smooth (no teleporting between frames)', () {
    for (var sp = 0; sp < speciesList.length; sp++) {
      final m = CreatureMotion(sp);
      var prev = m.at(0);
      for (var t = 1 / 60; t < 60; t += 1 / 60) {
        final p = m.at(t);
        expect(
          (p - prev).distance,
          lessThan(0.03),
          reason: 'species=$sp t=$t で飛んでいる',
        );
        prev = p;
      }
    }
  });

  test('all species trace pairwise different paths', () {
    const t = 7.3;
    final points = [
      for (var sp = 0; sp < speciesList.length; sp++) CreatureMotion(sp).at(t),
    ];
    for (var a = 0; a < points.length; a++) {
      for (var b = a + 1; b < points.length; b++) {
        expect(points[a], isNot(points[b]), reason: 'species $a と $b が同じ動き');
      }
    }
  });

  test('all five motion styles are used by the roster', () {
    final used = {
      for (var sp = 0; sp < speciesList.length; sp++) motionStyleFor(sp),
    };
    expect(used, MotionStyle.values.toSet());
  });

  test('hoppers land on the ground and jump high', () {
    final hopper = List.generate(
      speciesList.length,
      (i) => i,
    ).firstWhere((sp) => motionStyleFor(sp) == MotionStyle.hopper);
    final m = CreatureMotion(hopper);
    var maxY = -2.0, minY = 2.0;
    for (var t = 0.0; t < 60; t += 0.02) {
      final y = m.at(t).dy;
      if (y > maxY) maxY = y;
      if (y < minY) minY = y;
    }
    expect(maxY, greaterThan(0.8), reason: '地面(0.85付近)に着地する');
    expect(minY, lessThan(0.55), reason: '高くジャンプする');
  });

  test('lazy species stay low and move little', () {
    final lazy = List.generate(
      speciesList.length,
      (i) => i,
    ).firstWhere((sp) => motionStyleFor(sp) == MotionStyle.lazy);
    final m = CreatureMotion(lazy);
    for (var t = 0.0; t < 60; t += 0.05) {
      final p = m.at(t);
      expect(p.dy, greaterThan(0.55), reason: 'のんびり組は地面ちかくに居る');
      expect(p.dx.abs(), lessThan(0.5), reason: 'あまり遠くへ行かない');
    }
  });

  test('tilt is gentle and returns to level', () {
    for (var sp = 0; sp < speciesList.length; sp++) {
      final m = CreatureMotion(sp);
      for (var t = 0.0; t < 30; t += 0.1) {
        expect(
          m.tiltAt(t).abs(),
          lessThanOrEqualTo(0.17),
          reason: 'species=$sp',
        );
      }
    }
  });

  test('future species (index beyond the map) still get a style', () {
    expect(motionStyleFor(speciesList.length + 3), isA<MotionStyle>());
    final m = CreatureMotion(speciesList.length + 3);
    expect(m.at(1).dx, inInclusiveRange(-0.95, 0.95));
  });
}

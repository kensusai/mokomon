import 'package:flutter/material.dart';

import 'cloud.dart';

Widget _dot(double left, double top, double d, Color color) => Positioned(
  left: left,
  top: top,
  child: Container(
    width: d,
    height: d,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  ),
);

/// 背景テーマごとの飾り(雲・月・あわ・木など)。docs/game-design.md §13。
///
/// [themeKey] は `bgThemes[...].key`。未知のキーは 'sora'(既定の空)として扱う。
/// ホーム画面の `Stack` にそのまま spread する `Positioned` のリストを返す。
List<Widget> bgDecor(String themeKey) {
  const deco = TextStyle(fontSize: 40);
  switch (themeKey) {
    case 'yuyake':
      return [
        Positioned(
          top: 30,
          right: 30,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFE28A), Color(0xFFFFB25E)],
              ),
            ),
          ),
        ),
        const Positioned(top: 96, left: 30, child: Cloud(width: 62)),
        const Positioned(
          top: 140,
          right: 100,
          child: Text('🦅', style: TextStyle(fontSize: 18)),
        ),
      ];
    case 'yozora':
      return [
        const Positioned(
          top: 20,
          right: 28,
          child: Text('🌙', style: TextStyle(fontSize: 54)),
        ),
        const Positioned(
          top: 80,
          left: 40,
          child: Text('✨', style: TextStyle(fontSize: 22)),
        ),
        const Positioned(
          top: 40,
          left: 110,
          child: Text('✨', style: TextStyle(fontSize: 16)),
        ),
        const Positioned(
          top: 130,
          right: 90,
          child: Text('✨', style: TextStyle(fontSize: 18)),
        ),
        const Positioned(
          top: 160,
          left: 80,
          child: Text('⭐', style: TextStyle(fontSize: 14)),
        ),
        for (final q in const [
          (30.0, 30.0),
          (150.0, 60.0),
          (230.0, 110.0),
          (70.0, 140.0),
          (300.0, 50.0),
        ])
          _dot(q.$1, q.$2, 4, Colors.white70),
      ];
    case 'umi':
      return [
        const Positioned(
          bottom: 20,
          left: 12,
          child: Text('🪸', style: TextStyle(fontSize: 30)),
        ),
        const Positioned(
          top: 120,
          left: 60,
          child: Text('🐟', style: TextStyle(fontSize: 22)),
        ),
        const Positioned(
          top: 40,
          right: 40,
          child: Text('🐠', style: TextStyle(fontSize: 28)),
        ),
        for (final b in const [
          (30.0, 60.0, 18.0),
          (90.0, 120.0, 12.0),
          (300.0, 50.0, 14.0),
          (260.0, 130.0, 10.0),
          (180.0, 40.0, 9.0),
          (330.0, 110.0, 12.0),
        ])
          _dot(b.$1, b.$2, b.$3, Colors.white.withValues(alpha: 0.5)),
      ];
    case 'mori':
      return const [
        Positioned(bottom: 10, left: 8, child: Text('🌳', style: deco)),
        Positioned(bottom: 14, right: 8, child: Text('🌲', style: deco)),
        Positioned(
          bottom: 60,
          right: 60,
          child: Text('🍄', style: TextStyle(fontSize: 20)),
        ),
        Positioned(
          top: 90,
          right: 100,
          child: Text('🦋', style: TextStyle(fontSize: 18)),
        ),
        Positioned(top: 40, left: 40, child: Cloud(width: 56)),
      ];
    case 'yuki':
      return [
        const Positioned(
          top: 100,
          right: 50,
          child: Text('❄️', style: TextStyle(fontSize: 24)),
        ),
        const Positioned(
          top: 50,
          right: 130,
          child: Text('❄️', style: TextStyle(fontSize: 16)),
        ),
        const Positioned(
          top: 150,
          left: 40,
          child: Text('❄️', style: TextStyle(fontSize: 18)),
        ),
        const Positioned(bottom: 30, right: 16, child: Text('⛄', style: deco)),
        const Positioned(
          bottom: 60,
          left: 16,
          child: Text('🌨️', style: TextStyle(fontSize: 26)),
        ),
        for (final q in const [
          (50.0, 40.0),
          (170.0, 30.0),
          (260.0, 80.0),
          (110.0, 110.0),
          (320.0, 140.0),
        ])
          _dot(q.$1, q.$2, 6, const Color(0xFFDCEAF7)),
      ];
    case 'uchu':
      return [
        const Positioned(
          top: 24,
          right: 28,
          child: Text('🪐', style: TextStyle(fontSize: 48)),
        ),
        const Positioned(
          top: 110,
          left: 30,
          child: Text('🚀', style: TextStyle(fontSize: 30)),
        ),
        const Positioned(
          top: 60,
          left: 120,
          child: Text('🌟', style: TextStyle(fontSize: 18)),
        ),
        const Positioned(
          top: 150,
          right: 80,
          child: Text('✨', style: TextStyle(fontSize: 16)),
        ),
        for (final q in const [
          (40.0, 40.0),
          (90.0, 90.0),
          (200.0, 40.0),
          (260.0, 130.0),
          (320.0, 70.0),
          (150.0, 150.0),
        ])
          _dot(q.$1, q.$2, 3.5, Colors.white),
      ];
    case 'sabaku':
      return const [
        Positioned(
          top: 26,
          right: 34,
          child: Text('☀️', style: TextStyle(fontSize: 44)),
        ),
        Positioned(bottom: 16, left: 14, child: Text('🌵', style: deco)),
        Positioned(
          bottom: 40,
          right: 24,
          child: Text('🌵', style: TextStyle(fontSize: 28)),
        ),
        Positioned(
          bottom: 70,
          left: 120,
          child: Text('🦎', style: TextStyle(fontSize: 20)),
        ),
      ];
    case 'yuenchi':
      return const [
        Positioned(
          top: 24,
          left: 18,
          child: Text('🎡', style: TextStyle(fontSize: 50)),
        ),
        Positioned(
          top: 40,
          right: 24,
          child: Text('🎈', style: TextStyle(fontSize: 26)),
        ),
        Positioned(
          top: 110,
          right: 70,
          child: Text('🎈', style: TextStyle(fontSize: 18)),
        ),
        Positioned(
          bottom: 30,
          right: 14,
          child: Text('🎠', style: TextStyle(fontSize: 34)),
        ),
        Positioned(
          top: 90,
          left: 110,
          child: Text('🎪', style: TextStyle(fontSize: 22)),
        ),
      ];
    case 'kazan':
      return [
        const Positioned(
          bottom: 14,
          left: 8,
          child: Text('🌋', style: TextStyle(fontSize: 52)),
        ),
        const Positioned(
          top: 40,
          right: 40,
          child: Text('🌫️', style: TextStyle(fontSize: 30)),
        ),
        const Positioned(
          top: 90,
          left: 60,
          child: Text('🔥', style: TextStyle(fontSize: 20)),
        ),
        for (final q in const [
          (60.0, 50.0),
          (180.0, 40.0),
          (280.0, 90.0),
          (120.0, 130.0),
        ])
          _dot(q.$1, q.$2, 5, const Color(0xFFFF9A3D)),
      ];
    case 'niji':
      return const [
        Positioned(
          top: 20,
          left: 20,
          child: Text('🌈', style: TextStyle(fontSize: 54)),
        ),
        Positioned(
          top: 100,
          right: 30,
          child: Text('☁️', style: TextStyle(fontSize: 30)),
        ),
        Positioned(
          top: 50,
          right: 110,
          child: Text('🦋', style: TextStyle(fontSize: 20)),
        ),
        Positioned(
          bottom: 40,
          right: 18,
          child: Text('🌼', style: TextStyle(fontSize: 26)),
        ),
      ];
    default: // sora
      return const [
        Positioned(top: 40, left: 30, child: Cloud(width: 70)),
        Positioned(top: 90, right: 36, child: Cloud(width: 56)),
        Positioned(
          top: 150,
          left: 100,
          child: Text('🐦', style: TextStyle(fontSize: 18)),
        ),
      ];
  }
}

import 'package:flutter/material.dart';

/// おなか/ごきげんメーター(CSS .meter 相当)。値の変化は0.5秒でアニメーション。
class StatMeter extends StatelessWidget {
  final String icon;
  final double value; // 0-100
  final List<Color> colors;
  const StatMeter({
    super.key,
    required this.icon,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 28,
            child: Text(icon,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22))),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0F7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: (value / 100).clamp(0.0, 1.0),
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

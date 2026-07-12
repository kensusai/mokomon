import 'package:flutter/material.dart';

/// ふわふわ雲(ホーム背景の装飾)。CSS .cloud 相当。
class Cloud extends StatelessWidget {
  final double width;
  const Cloud({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final h = width * 0.34;
    return Opacity(
      opacity: 0.8,
      child: SizedBox(
        width: width,
        height: h * 2.2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: width,
                height: h,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Positioned(
              bottom: h * 0.5,
              left: width * 0.17,
              child: _bump(width * 0.43),
            ),
            Positioned(
              bottom: h * 0.55,
              left: width * 0.51,
              child: _bump(width * 0.31),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bump(double d) => Container(
        width: d,
        height: d,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
}

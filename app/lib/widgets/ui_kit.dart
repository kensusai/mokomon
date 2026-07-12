/// 共通UI部品とデザイントークン(プロトタイプ :root に対応)。
/// 新しい画面部品を作る前にここを確認すること(docs/frontend.md)。
library;

import 'package:flutter/material.dart';

// ---------- デザイントークン ----------

const inkColor = Color(0xFF3A3F52); // --ink
const ink2Color = Color(0xFF8A90A8); // --ink2
const fieldGray = Color(0xFFEEF0F7);
const goldColor = Color(0xFFFFD23E);

const greenGradient = [Color(0xFF34C98E), Color(0xFF1FAE76)];
const orangeGradient = [Color(0xFFFFAB49), Color(0xFFFF8F1F)];
const pinkGradient = [Color(0xFFFF9CC2), Color(0xFFFF6EA6)];
const purpleGradient = [Color(0xFFAB9DFF), Color(0xFF8A78F5)];
const blueGradient = [Color(0xFF6CC4FF), Color(0xFF3BA4EC)];

/// 白カードの浮き影(CSS --shadow 相当)
const cardShadow =
    BoxShadow(color: Color(0x1F3A3F52), blurRadius: 12, offset: Offset(0, 4));

// ---------- 部品 ----------

/// 白い丸ピル(コイン・名前・タイム表示)。CSS .pill 相当。
class StatPill extends StatelessWidget {
  final String text;
  const StatPill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [cardShadow],
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: inkColor)),
    );
  }
}

/// 白い丸アイコンボタン(ずかん・セーブ・戻る等)。CSS .iconbtn 相当。
class CircleIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const CircleIconButton({super.key, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x1F3A3F52),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    );
  }
}

/// 押し込み式のグラデーションボタンの共通シェル。
/// 各ボタンはレイアウト(child)だけを持ち込む。CSS .bigbtn 系の土台。
class PressableGradient extends StatelessWidget {
  final List<Color> colors;
  final double radius;
  final VoidCallback onTap;
  final Widget child;
  const PressableGradient({
    super.key,
    required this.colors,
    required this.onTap,
    required this.child,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

/// モーダル下部のグレーの閉じるボタン。CSS .closebtn 相当。
class ModalCloseButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const ModalCloseButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fieldGray,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: ink2Color)),
        ),
      ),
    );
  }
}

/// モーダル共通の外枠(白・角丸28・最大幅360)。CSS .modal .box 相当。
class MokoModalShell extends StatelessWidget {
  final Widget child;
  const MokoModalShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

/// モーダルの見出し。CSS .modal h2 相当。
class ModalTitle extends StatelessWidget {
  final String text;
  const ModalTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800, color: inkColor));
  }
}

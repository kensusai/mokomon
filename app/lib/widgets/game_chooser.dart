import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// ミニゲーム選択モーダル(プロトタイプ #chooser)。選ばれたキーを返す。
Future<String?> showGameChooser(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => MokoModalShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ModalTitle('どっちで あそぶ?'),
          const SizedBox(height: 12),
          _GameCard(
            emoji: '🍎',
            title: 'フルーツキャッチ',
            desc: 'おちてくるフルーツを タッチ!',
            colors: blueGradient,
            onTap: () => Navigator.of(dialogContext).pop('catch'),
          ),
          const SizedBox(height: 10),
          _GameCard(
            emoji: '🧩',
            title: 'おなじの どれ?',
            desc: 'おなじ かたちを さがそう!',
            colors: pinkGradient,
            onTap: () => Navigator.of(dialogContext).pop('puzzle'),
          ),
          const SizedBox(height: 10),
          _GameCard(
            emoji: '🃏',
            title: 'ペアさがし',
            desc: 'おなじ カードを めくろう!',
            colors: purpleGradient,
            onTap: () => Navigator.of(dialogContext).pop('memory'),
          ),
          const SizedBox(height: 10),
          ModalCloseButton(
              label: 'やめる', onTap: () => Navigator.of(dialogContext).pop()),
        ],
      ),
    ),
  );
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final List<Color> colors;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableGradient(
      colors: colors,
      radius: 20,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

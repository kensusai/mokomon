import 'package:flutter/material.dart';

/// ミニゲーム選択モーダル(プロトタイプ #chooser)。選ばれたキーを返す。
Future<String?> showGameChooser(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('どっちで あそぶ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A3F52))),
            const SizedBox(height: 12),
            _GameCard(
              emoji: '🍎',
              title: 'フルーツキャッチ',
              desc: 'おちてくるフルーツを タッチ!',
              colors: const [Color(0xFF6CC4FF), Color(0xFF3BA4EC)],
              onTap: () => Navigator.of(dialogContext).pop('catch'),
            ),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '🧩',
              title: 'おなじの どれ?',
              desc: 'おなじ かたちを さがそう!',
              colors: const [Color(0xFFFF9CC2), Color(0xFFFF6EA6)],
              onTap: () => Navigator.of(dialogContext).pop('puzzle'),
            ),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '🃏',
              title: 'ペアさがし',
              desc: 'おなじ カードを めくろう!',
              colors: const [Color(0xFFAB9DFF), Color(0xFF8A78F5)],
              onTap: () => Navigator.of(dialogContext).pop('memory'),
            ),
            const SizedBox(height: 10),
            Material(
              color: const Color(0xFFEEF0F7),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('やめる',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8A90A8))),
                ),
              ),
            ),
          ],
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), offset: Offset(0, 5)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
        ),
      ),
    );
  }
}

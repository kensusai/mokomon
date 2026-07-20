import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// ゲーム一覧(key, 絵文字, 名前, グラデ)。
const _games = [
  ('catch', '🍎', 'フルーツキャッチ', blueGradient),
  ('balloon', '🎈', 'ふうせんわり', pinkGradient),
  ('whack', '🔨', 'もぐらたたき', greenGradient),
  ('trace', '✏️', 'なぞってかこう', orangeGradient),
  ('puzzle', '🧩', 'おなじの どれ?', purpleGradient),
  ('odd', '👀', 'ちがうの どっち?', [Color(0xFF5BC8E8), Color(0xFF2E9BC0)]),
  ('memory', '🃏', 'ペアさがし', [Color(0xFF9B8CFF), Color(0xFF6B5BD6)]),
  ('order', '🔢', 'じゅんばんタッチ', [Color(0xFF7ED6A5), Color(0xFF4CAF7D)]),
  ('count', '🧮', 'かぞえてタッチ', [Color(0xFFFFB65C), Color(0xFFE8892A)]),
  ('simon', '💡', 'おぼえてタッチ', [Color(0xFFB78CFF), Color(0xFF7E5BD6)]),
];

/// ミニゲーム選択モーダル。2列グリッドで10種を1画面に(スクロールなし)。
Future<String?> showGameChooser(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => MokoModalShell(
      header: const [ModalTitle('どれで あそぶ?')],
      body: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.15,
          children: [
            for (final (key, emoji, title, colors) in _games)
              PressableGradient(
                colors: colors,
                radius: 18,
                onTap: () => Navigator.of(dialogContext).pop(key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(title,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
      footer: [
        ModalCloseButton(
            label: 'やめる', onTap: () => Navigator.of(dialogContext).pop()),
      ],
    ),
  );
}

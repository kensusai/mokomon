import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import 'ui_kit.dart';

/// ミニゲーム1件の定義(docs/review-findings.md #69)。
/// 選択モーダルの表示(絵文字・名前・グラデ)と画面生成を1箇所で持ち、
/// キー文字列の二重管理(chooser の一覧と home の switch)をなくす。
/// 一覧の実体は screens/game_registry.dart。
class GameEntry {
  /// テスト・識別用のキー(保存はしない)。
  final String key;
  final String emoji;
  final String title;
  final List<Color> colors;

  /// このゲームの画面を作る。
  final Widget Function(GameController controller) build;

  const GameEntry(this.key, this.emoji, this.title, this.colors, this.build);
}

/// ミニゲーム選択モーダル。3列グリッド(20種+おまかせで7行ちょうど。
/// 必要なら本文だけスクロール)。
/// [games] には screens/game_registry.dart の一覧をそのまま渡す。
/// 先頭の「おまかせ🎲」をタップすると [games] からランダムに1つ選んで返す
/// ([rng] はテストで抽選を固定するためのフック)。
Future<GameEntry?> showGameChooser(
  BuildContext context,
  List<GameEntry> games, {
  Random? rng,
}) {
  Widget tile(
    BuildContext dialogContext, {
    required String emoji,
    required String title,
    required List<Color> colors,
    required GameEntry Function() pick,
  }) => PressableGradient(
    colors: colors,
    radius: 18,
    onTap: () => Navigator.of(dialogContext).pop(pick()),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  return showDialog<GameEntry>(
    context: context,
    builder: (dialogContext) => MokoModalShell(
      header: const [ModalTitle('どれで あそぶ?')],
      body: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
          children: [
            tile(
              dialogContext,
              emoji: '🎲',
              title: 'おまかせ',
              colors: const [Color(0xFF8C9BFF), Color(0xFFFF8FB2)],
              pick: () => games[(rng ?? Random()).nextInt(games.length)],
            ),
            for (final g in games)
              tile(
                dialogContext,
                emoji: g.emoji,
                title: g.title,
                colors: g.colors,
                pick: () => g,
              ),
          ],
        ),
      ],
      footer: [
        ModalCloseButton(
          label: 'やめる',
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

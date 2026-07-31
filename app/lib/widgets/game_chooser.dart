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

/// ミニゲーム選択モーダル。2列グリッド(必要なら本文だけスクロール)。
/// [games] には screens/game_registry.dart の一覧をそのまま渡す。
Future<GameEntry?> showGameChooser(
  BuildContext context,
  List<GameEntry> games,
) {
  return showDialog<GameEntry>(
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
            for (final g in games)
              PressableGradient(
                colors: g.colors,
                radius: 18,
                onTap: () => Navigator.of(dialogContext).pop(g),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(g.emoji, style: const TextStyle(fontSize: 26)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          g.title,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
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
          label: 'やめる',
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

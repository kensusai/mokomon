import 'package:flutter/material.dart';

import 'game_overlays.dart';

/// ミニゲーム画面共通の外枠(docs/game-design.md §5)。
///
/// `Scaffold > 縦グラデ背景 > SafeArea > Stack > Padding(14) > Column` に
/// [GameHeaderBar] を載せた形が7画面で完全に同型だったため、差分である
/// タイトルと背景2色だけを受け取る形に集約した。
///
/// [children] はヘッダーの下に縦に並ぶ本体、[overlays] は画面全体に重ねる
/// オーバーレイ(スタート/終了/ゲームオーバー)。オーバーレイは背景と本体の
/// 上に積まれるので、`if (...) SomeOverlay(...)` をそのまま渡してよい。
class MinigameScaffold extends StatelessWidget {
  final String title;

  /// 背景の縦グラデーション。上端→下端の2色。
  final Color topColor;
  final Color bottomColor;

  /// ヘッダー右側の余白幅([GameHeaderBar.trailingWidth] にそのまま渡す)。
  final double trailingWidth;

  final List<Widget> children;
  final List<Widget> overlays;

  const MinigameScaffold({
    super.key,
    required this.title,
    required this.topColor,
    required this.bottomColor,
    required this.children,
    this.trailingWidth = 48,
    this.overlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, bottomColor],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    GameHeaderBar(
                      title: title,
                      onBack: () => Navigator.of(context).pop(),
                      trailingWidth: trailingWidth,
                    ),
                    ...children,
                  ],
                ),
              ),
              ...overlays,
            ],
          ),
        ),
      ),
    );
  }
}

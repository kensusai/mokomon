/// 共通UI部品とデザイントークン(プロトタイプ :root に対応)。
/// 新しい画面部品を作る前にここを確認すること(docs/frontend.md)。
library;

import 'package:flutter/material.dart';

// ---------- デザイントークン ----------

const inkColor = Color(0xFF3A3F52); // --ink
const ink2Color = Color(0xFF8A90A8); // --ink2
const fieldGray = Color(0xFFEEF0F7);
const goldColor = Color(0xFFFFD23E);

/// 「選択中」を示すアクセント緑(選択枠・フォーカス枠・進捗ドット。#60)
const accentGreen = Color(0xFF34C98E);

const greenGradient = [accentGreen, Color(0xFF1FAE76)];
const orangeGradient = [Color(0xFFFFAB49), Color(0xFFFF8F1F)];
const pinkGradient = [Color(0xFFFF9CC2), Color(0xFFFF6EA6)];
const purpleGradient = [Color(0xFFAB9DFF), Color(0xFF8A78F5)];
const blueGradient = [Color(0xFF6CC4FF), Color(0xFF3BA4EC)];

/// 白カードの浮き影(CSS --shadow 相当)
const cardShadow = BoxShadow(
  color: Color(0x1F3A3F52),
  blurRadius: 12,
  offset: Offset(0, 4),
);

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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: inkColor,
        ),
      ),
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
        child: SizedBox(width: 48, height: 48, child: Center(child: child)),
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
          colors: colors,
        ),
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

/// 絵文字アイコン+ラベルの大きなアクションボタン。CSS .bigbtn 相当。
/// ホームの4ボタンとおえかきの けす/できた! で共用。
class BigActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final String? sub;
  final List<Color> colors;
  final VoidCallback onTap;
  const BigActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableGradient(
      colors: colors,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 緑の大きな開始ボタン(CSS .startbtn 相当)。共通利用(docs/review-findings.md #53 で celebrate_overlay から移設)。
class StartButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const StartButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return PressableGradient(
      colors: greenGradient,
      radius: 999,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ink2Color,
            ),
          ),
        ),
      ),
    );
  }
}

/// モーダル共通の外枠(白・角丸28・最大幅360)。CSS .modal .box 相当。
///
/// [header] と [footer] はスクロールしても常に画面内に留まり、
/// [body] だけが必要なときにスクロールする(こどもFB「操作ボタンまで
/// スクロールせずに見えるようにしたい」)。ダイアログの高さは端末の
/// 画面サイズに合わせて自動で収まる(レスポンシブ)。
class MokoModalShell extends StatelessWidget {
  final List<Widget> header;
  final List<Widget> body;
  final List<Widget> footer;
  const MokoModalShell({
    super.key,
    this.header = const [],
    this.body = const [],
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 360, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...header,
              if (header.isNotEmpty) const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body,
                  ),
                ),
              ),
              if (footer.isNotEmpty) const SizedBox(height: 10),
              ...footer,
            ],
          ),
        ),
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
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: inkColor,
      ),
    );
  }
}

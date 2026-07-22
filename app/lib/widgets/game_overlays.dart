import 'dart:async';

import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// 白スクリム+中央寄せ Column の共通骨格(docs/review-findings.md #31)。
class _OverlayScrim extends StatelessWidget {
  final double opacity;
  final List<Widget> children;
  const _OverlayScrim({required this.children, this.opacity = 0.75});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: opacity),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// オーバーレイ用のグレー二次ボタン(「もどる」「あきらめる」)。
/// ModalCloseButton とは余白が違う(横32)ため見た目を変えずに共通化できず、
/// オーバーレイ専用として持つ(docs/review-findings.md #31)。
class _GrayButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GrayButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: fieldGray,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: ink2Color,
        ),
      ),
    );
  }
}

/// ミニゲーム開始前の説明オーバーレイ(CSS .gameOverlay 相当)。
class GameStartOverlay extends StatelessWidget {
  final String title;
  final String desc;
  final VoidCallback onStart;
  final VoidCallback onBack;

  const GameStartOverlay({
    super.key,
    required this.title,
    required this.desc,
    required this.onStart,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _OverlayScrim(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.7,
            fontWeight: FontWeight.w700,
            color: ink2Color,
          ),
        ),
        const SizedBox(height: 16),
        StartButton(label: 'はじめる!', onPressed: onStart),
        const SizedBox(height: 12),
        _GrayButton(label: 'もどる', onPressed: onBack),
      ],
    );
  }
}

/// ミニゲーム終了オーバーレイ。
class GameEndOverlay extends StatelessWidget {
  final String emoji;
  final String result;
  final VoidCallback onDone;

  /// 閉じるボタンのラベル。報酬ゼロの「ざんねん」系メッセージでは
  /// 「やったー!」が不自然なため、画面側で励まし文言に差し替えられる。
  final String buttonLabel;

  const GameEndOverlay({
    super.key,
    required this.emoji,
    required this.result,
    required this.onDone,
    this.buttonLabel = 'やったー!',
  });

  @override
  Widget build(BuildContext context) {
    return _OverlayScrim(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 10),
        Text(
          result,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 16),
        StartButton(label: buttonLabel, onPressed: onDone),
      ],
    );
  }
}

/// ミス回数の上限に達したときのオーバーレイ(報酬なしで終了)。
/// コインを払えば [onContinue]、あきらめれば [onGiveUp]。
class GameOverOverlay extends StatelessWidget {
  final int cost;
  final bool canAfford;
  final VoidCallback onContinue;
  final VoidCallback onGiveUp;

  const GameOverOverlay({
    super.key,
    required this.cost,
    required this.canAfford,
    required this.onContinue,
    required this.onGiveUp,
  });

  @override
  Widget build(BuildContext context) {
    return _OverlayScrim(
      opacity: 0.85,
      children: [
        const Text('😣', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 10),
        const Text(
          'まちがえすぎ! ゲームオーバー',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 16),
        // コイン不足時は押せない見た目+無反応にする。終了は「あきらめる」
        // だけに限定する(docs/review-findings.md #20)。
        Opacity(
          opacity: canAfford ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !canAfford,
            child: StartButton(
              label: '🪙$cost コインで つづける',
              onPressed: onContinue,
            ),
          ),
        ),
        if (!canAfford) ...[
          const SizedBox(height: 8),
          const Text(
            'コインが たりないよ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ink2Color,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _GrayButton(label: 'あきらめる', onPressed: onGiveUp),
      ],
    );
  }
}

/// 3・2・1 カウントダウン(700ms間隔)。終わると [onDone]。
/// [onTick] は数字が出るたびに呼ばれる(効果音用)。
class GameCountdown extends StatefulWidget {
  final VoidCallback onDone;
  final VoidCallback? onTick;
  const GameCountdown({super.key, required this.onDone, this.onTick});

  @override
  State<GameCountdown> createState() => _GameCountdownState();
}

class _GameCountdownState extends State<GameCountdown> {
  var _n = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.onTick?.call();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (_n <= 1) {
        _timer?.cancel();
        widget.onDone();
      } else {
        setState(() => _n--);
        widget.onTick?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Text(
          '$_n',
          style: const TextStyle(
            fontSize: 110,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Color(0x40000000),
                offset: Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 丸い白の戻るボタン(CSS .iconbtn .backbtn 相当)。
class BackIconButton extends StatelessWidget {
  final VoidCallback onTap;
  const BackIconButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      onTap: onTap,
      child: const Icon(Icons.arrow_back, size: 26, color: inkColor),
    );
  }
}

/// ミニゲーム共通のヘッダー行: 戻るボタン+中央タイトル。
/// 右側は戻るボタンの見た目の幅とバランスさせるための空白(既定48px)。
class GameHeaderBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final double trailingWidth;
  const GameHeaderBar({
    super.key,
    required this.title,
    required this.onBack,
    this.trailingWidth = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BackIconButton(onTap: onBack),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: inkColor,
            ),
          ),
        ),
        SizedBox(width: trailingWidth),
      ],
    );
  }
}

/// ラウンド進捗ドット(パズル/ちがうのどっち/かぞえて 共通)。
class RoundProgressDots extends StatelessWidget {
  final int total;
  final int current;
  final double size;
  final Color color;
  final Color trackColor;
  const RoundProgressDots({
    super.key,
    required this.total,
    required this.current,
    this.size = 14,
    this.color = accentGreen,
    this.trackColor = const Color(0xFFDFE3EF),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.symmetric(horizontal: size >= 14 ? 4 : 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < current ? color : trackColor,
            ),
          ),
      ],
    );
  }
}

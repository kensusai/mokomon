import 'dart:async';

import 'package:flutter/material.dart';

import 'celebrate_overlay.dart';
import 'ui_kit.dart';

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
    return Container(
      color: Colors.white.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: inkColor)),
          const SizedBox(height: 16),
          Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  fontWeight: FontWeight.w700,
                  color: ink2Color)),
          const SizedBox(height: 16),
          StartButton(label: 'はじめる!', onPressed: onStart),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onBack,
            style: TextButton.styleFrom(
              backgroundColor: fieldGray,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('もどる',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ink2Color)),
          ),
        ],
      ),
    );
  }
}

/// ミニゲーム終了オーバーレイ。
class GameEndOverlay extends StatelessWidget {
  final String emoji;
  final String result;
  final VoidCallback onDone;

  const GameEndOverlay({
    super.key,
    required this.emoji,
    required this.result,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 10),
          Text(result,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: inkColor)),
          const SizedBox(height: 16),
          StartButton(label: 'やったー!', onPressed: onDone),
        ],
      ),
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
                  blurRadius: 18),
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

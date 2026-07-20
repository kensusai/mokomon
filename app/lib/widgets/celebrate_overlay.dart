import 'package:flutter/material.dart';

import '../audio/sfx_player.dart';
import '../audio/sound_synth.dart';
import 'confetti.dart';
import 'ui_kit.dart';

/// お祝い全画面オーバーレイ(誕生・金のたまご等)。
/// プロトタイプの celebrate() に対応。ボタンで閉じるまで待つ。
///
/// [sound] は再生する効果音(既定はふつうのファンファーレ)。
/// [duckBgm] を true にすると、進化リビールと同じくBGMを一時停止して
/// 効果音を主役にする(たまご孵化など、より劇的にしたい場面で使う)。
Future<void> showCelebrate(
  BuildContext context, {
  required String emoji,
  required String title,
  required String desc,
  SfxPlayer? sfx,
  Sfx sound = Sfx.fanfare,
  bool duckBgm = false,
}) {
  if (duckBgm) {
    sfx?.playJingle(sound);
  } else {
    sfx?.play(sound);
  }
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.white.withValues(alpha: 0.88),
    builder: (context) => Stack(
      children: [
        const Positioned.fill(child: ConfettiBurst()),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingEmoji(emoji),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: inkColor),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(desc,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink2Color),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              StartButton(
                  label: 'わーい!', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 大きな絵文字が 1s ごとに拡大縮小(CSS pop 相当)。
class _PulsingEmoji extends StatefulWidget {
  final String emoji;
  const _PulsingEmoji(this.emoji);

  @override
  State<_PulsingEmoji> createState() => _PulsingEmojiState();
}

class _PulsingEmojiState extends State<_PulsingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.15).animate(_c),
      child: Text(widget.emoji,
          style: const TextStyle(fontSize: 64), textAlign: TextAlign.center),
    );
  }
}

/// 緑の大きな開始ボタン(CSS .startbtn 相当)。共通利用。
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
        child: Text(label,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
    );
  }
}

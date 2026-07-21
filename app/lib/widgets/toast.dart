import 'package:flutter/material.dart';

/// 画面下部のトースト。プロトタイプの toast() に対応(2.2秒で消える)。
/// コイン不足の共通トースト(ショップ2箇所+ごはんで同一文言だったため集約。
/// docs/review-findings.md #59)。
void showNotEnoughCoinsToast(BuildContext context) =>
    showToast(context, 'コインが たりないよ! 「あそぶ」で あつめよう🎮');

void showToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  const _Toast({required this.message, required this.onDone});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // CSS toastIn: 0%で透明+10px下、12%〜80%で表示、100%で透明
  double _opacity(double t) {
    if (t < 0.12) return t / 0.12;
    if (t < 0.80) return 1;
    return 1 - (t - 0.80) / 0.20;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 120,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Opacity(
            opacity: _opacity(_c.value).clamp(0, 1),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEB3A3F52),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

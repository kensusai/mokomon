import 'package:flutter/material.dart';

import '../data/foods.dart';
import '../logic/game_controller.dart';
import 'toast.dart';

const _foodGradients = {
  'apple': [Color(0xFF34C98E), Color(0xFF1FAE76)],
  'meat': [Color(0xFFFFAB49), Color(0xFFFF8F1F)],
  'cake': [Color(0xFFFF9CC2), Color(0xFFFF6EA6)],
};

/// ごはんモーダル(プロトタイプ #foodModal)。
/// 給餌に成功したら閉じて [onFed] を呼ぶ。コイン不足はトーストで誘導。
Future<void> showFoodModal(BuildContext context, GameController controller,
    {required void Function(Food) onFed}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('なにを たべる?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A3F52))),
            const SizedBox(height: 12),
            for (final f in foods) ...[
              _FoodRow(
                food: f,
                poor: controller.state.coins < f.cost,
                onTap: () {
                  if (!controller.feed(f)) {
                    showToast(context, 'コインが たりないよ! 「あそぶ」で あつめよう🎮');
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  onFed(f);
                },
              ),
              const SizedBox(height: 10),
            ],
            _CloseButton(
                label: 'やめる',
                onTap: () => Navigator.of(dialogContext).pop()),
          ],
        ),
      ),
    ),
  );
}

class _FoodRow extends StatelessWidget {
  final Food food;
  final bool poor;
  final VoidCallback onTap;
  const _FoodRow({required this.food, required this.poor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: poor ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _foodGradients[food.key]!,
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(food.emoji, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(food.name,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text(food.desc,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.92))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('🪙${food.cost}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CloseButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEEF0F7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A90A8))),
        ),
      ),
    );
  }
}

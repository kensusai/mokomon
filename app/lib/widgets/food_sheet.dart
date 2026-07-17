import 'package:flutter/material.dart';

import '../data/foods.dart';
import '../logic/game_controller.dart';
import 'toast.dart';
import 'ui_kit.dart';

const _foodGradients = {
  'apple': greenGradient,
  'meat': orangeGradient,
  'cake': pinkGradient,
  'onigiri': blueGradient,
  'ramen': [Color(0xFFFF9A62), Color(0xFFE8702A)],
  'parfait': purpleGradient,
};

/// ごはんモーダル(プロトタイプ #foodModal)。
/// 給餌に成功したら閉じて [onFed] を呼ぶ。コイン不足はトーストで誘導。
Future<void> showFoodModal(BuildContext context, GameController controller,
    {required void Function(Food) onFed}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => MokoModalShell(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ModalTitle('なにを たべる?'),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                ],
              ),
            ),
          ),
          ModalCloseButton(
              label: 'やめる', onTap: () => Navigator.of(dialogContext).pop()),
        ],
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
      child: PressableGradient(
        colors: _foodGradients[food.key]!,
        radius: 20,
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
    );
  }
}

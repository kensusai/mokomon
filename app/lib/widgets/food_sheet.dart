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
  'tamago': [Color(0xFFFFD86B), Color(0xFFF0B429)],
  'pizza': [Color(0xFFFF8A65), Color(0xFFE05B3A)],
  'burger': [Color(0xFFD9A05B), Color(0xFFB0722E)],
  'ice': [Color(0xFF9AD9F5), Color(0xFF5FB4E0)],
};

/// ごはんモーダル。2列グリッドで10種を1画面に(スクロールなし)。
/// 給餌に成功したら閉じて [onFed] を呼ぶ。コイン不足はトーストで誘導。
Future<void> showFoodModal(BuildContext context, GameController controller,
    {required void Function(Food) onFed}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => MokoModalShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ModalTitle('なにを たべる?'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.05,
            children: [
              for (final f in foods)
                Opacity(
                  opacity: controller.state.coins < f.cost ? 0.55 : 1,
                  child: PressableGradient(
                    colors: _foodGradients[f.key]!,
                    radius: 18,
                    onTap: () {
                      if (!controller.feed(f)) {
                        showToast(context, 'コインが たりないよ! 「あそぶ」で あつめよう🎮');
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      onFed(f);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f.emoji, style: const TextStyle(fontSize: 26)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('${f.name}  🪙${f.cost}',
                                maxLines: 1,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ModalCloseButton(
              label: 'やめる', onTap: () => Navigator.of(dialogContext).pop()),
        ],
      ),
    ),
  );
}

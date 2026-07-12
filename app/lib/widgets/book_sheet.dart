import 'package:flutter/material.dart';

import '../data/species.dart';
import '../logic/game_controller.dart';
import '../widgets/creature_painter.dart';
import 'ui_kit.dart';

/// いきものずかん(プロトタイプ #bookModal)。
/// 「あたらしいたまごを むかえる」を押したら抽選した種族indexを返して閉じる。
Future<int?> showBookModal(BuildContext context, GameController controller) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      final s = controller.state;
      final kinged = s.stage == 3;
      return MokoModalShell(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ModalTitle('📖 いきもの ずかん'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
                children: [
                  for (var i = 0; i < speciesList.length; i++)
                    _BookCell(
                        speciesIndex: i,
                        owned: s.collection[i],
                        current: i == s.species),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                kinged
                    ? 'あたらしい たまごを むかえよう!'
                    : 'キングまで そだてると ずかんに とうろくされて、あたらしい たまごが もらえるよ!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                    color: ink2Color),
              ),
              if (kinged) ...[
                const SizedBox(height: 10),
                PressableGradient(
                  colors: greenGradient,
                  onTap: () =>
                      Navigator.of(dialogContext).pop(controller.newEgg()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      children: [
                        Text('🥚', style: TextStyle(fontSize: 26)),
                        Text('あたらしい たまごを むかえる',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ModalCloseButton(
                  label: 'とじる', onTap: () => Navigator.of(dialogContext).pop()),
            ],
          ),
        ),
      );
    },
  );
}

class _BookCell extends StatelessWidget {
  final int speciesIndex;
  final bool owned;
  final bool current;
  const _BookCell({
    required this.speciesIndex,
    required this.owned,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final sp = speciesList[speciesIndex];
    Widget mini = CustomPaint(
      size: const Size(64, 64),
      painter: CreaturePainter(
          speciesIndex: speciesIndex, stage: 3, sad: false), // キング姿(王冠つき)
    );
    if (!owned) {
      // 未入手はシルエット+「?」
      mini = Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter:
                const ColorFilter.mode(Color(0xFFD5D9E6), BlendMode.srcIn),
            child: mini,
          ),
          const Text('?',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFAAB0C5))),
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: owned ? const Color(0xFFEAFAF1) : const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(18),
        border: current
            ? Border.all(color: const Color(0xFF34C98E), width: 3)
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 64, height: 64, child: mini),
          const SizedBox(height: 2),
          Text(owned ? sp.names[3] : '???',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: owned ? inkColor : ink2Color)),
          if (current)
            const Text('そだてちゅう',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF34C98E))),
        ],
      ),
    );
  }
}

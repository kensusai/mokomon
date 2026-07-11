import 'package:flutter/material.dart';

import '../data/items.dart';
import '../logic/game_controller.dart';
import 'toast.dart';

/// きせかえショップ(プロトタイプ #shopModal)。docs/game-design.md §7。
Future<void> showShopModal(BuildContext context, GameController controller) {
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🛍️ きせかえショップ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3A3F52))),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
                children: [
                  for (final item in shopItems)
                    _ShopCell(item: item, controller: controller),
                ],
              ),
              const SizedBox(height: 8),
              const Text('かったものは タップで きたり ぬいだり できるよ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A90A8))),
              const SizedBox(height: 10),
              Material(
                color: const Color(0xFFEEF0F7),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('とじる',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A90A8))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShopCell extends StatelessWidget {
  final ShopItem item;
  final GameController controller;
  const _ShopCell({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final owned = s.owned.contains(item.key);
    final equipped =
        (item.slot == ItemSlot.head ? s.equipHead : s.equipFace) == item.key;
    final poor = !owned && s.coins < item.cost;

    return Material(
      color: equipped ? const Color(0xFFEAFAF1) : const Color(0xFFF4F6FB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: equipped
            ? const BorderSide(color: Color(0xFF34C98E), width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          switch (controller.tapShopItem(item)) {
            case ShopTapOutcome.bought:
              showToast(context, '${item.name}を かった! にあうね✨');
            case ShopTapOutcome.notEnoughCoins:
              showToast(context, 'コインが たりないよ! 「あそぶ」で あつめよう🎮');
            case ShopTapOutcome.equipped:
            case ShopTapOutcome.unequipped:
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 4),
              Text(item.name,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3A3F52))),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x143A3F52),
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Text(
                  owned ? (equipped ? 'きてる✓' : 'きる') : '🪙${item.cost}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: poor
                          ? const Color(0xFFD05555)
                          : const Color(0xFF3A3F52)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

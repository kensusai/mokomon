import 'package:flutter/material.dart';

import '../data/backgrounds.dart';
import '../data/items.dart';
import '../logic/game_controller.dart';
import 'toast.dart';
import 'ui_kit.dart';

/// きせかえショップ(docs/game-design.md §7)。
/// 「あたま/かお/はいけい」のタブ切替で、各タブは1画面(スクロールなし)。
Future<void> showShopModal(BuildContext context, GameController controller) {
  return showDialog(
    context: context,
    builder: (dialogContext) => DefaultTabController(
      length: 3,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MokoModalShell(
          header: [
            const ModalTitle('🛍️ きせかえショップ'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: fieldGray,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: const Color(0xFF34C98E),
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: Colors.white,
                unselectedLabelColor: ink2Color,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(height: 40, text: '👒 あたま'),
                  Tab(height: 40, text: '🕶️ かお'),
                  Tab(height: 40, text: '🖼️ はいけい'),
                ],
              ),
            ),
          ],
          body: [
            SizedBox(
              height: 320,
              child: TabBarView(
                children: [
                  _itemGrid(controller, ItemSlot.head),
                  _itemGrid(controller, ItemSlot.face),
                  _bgGrid(controller),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text('かったものは タップで きたり ぬいだり できるよ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ink2Color)),
          ],
          footer: [
            ModalCloseButton(
                label: 'とじる', onTap: () => Navigator.of(dialogContext).pop()),
          ],
        ),
      ),
    ),
  );
}

Widget _itemGrid(GameController controller, ItemSlot slot) => GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.74,
      children: [
        for (final item in shopItems)
          if (item.slot == slot) _ShopCell(item: item, controller: controller),
      ],
    );

/// 背景テーマの切替(コインで購入・端末ローカルで所持管理)。docs/game-design.md §13。
Widget _bgGrid(GameController controller) => GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.8,
      children: [
        for (var i = 0; i < bgThemes.length; i++)
          _BgCell(index: i, controller: controller),
        _BgCell(index: null, controller: controller), // おまかせ(デフォルト)
      ],
    );

class _BgCell extends StatelessWidget {
  final int? index; // null = 種族デフォルトに戻す
  final GameController controller;
  const _BgCell({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final theme = bgThemes[index ?? speciesDefaultBg[s.species]];
    final selected = index == null ? s.bg == null : s.bg == index;
    final owned = index == null || s.ownsBg(index!);
    final poor = !owned && s.coins < theme.cost;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? const BorderSide(color: Color(0xFF34C98E), width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          switch (controller.tapBackground(index)) {
            case BgTapOutcome.bought:
              showToast(context, '${theme.name}を かった! すてきだね✨');
            case BgTapOutcome.notEnoughCoins:
              showToast(context, 'コインが たりないよ! 「あそぶ」で あつめよう🎮');
            case BgTapOutcome.selected:
              break;
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.top, theme.bottom]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Opacity(
            opacity: poor ? 0.55 : 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(index == null ? '🎲' : theme.emoji,
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                      index == null
                          ? 'おまかせ'
                          : (owned
                              ? theme.name
                              : '${theme.name} 🪙${theme.cost}'),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: inkColor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(16),
        side: equipped
            ? const BorderSide(color: Color(0xFF34C98E), width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(item.name,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: inkColor)),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x143A3F52),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Text(
                  owned ? (equipped ? 'きてる✓' : 'きる') : '🪙${item.cost}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: poor ? const Color(0xFFD05555) : inkColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

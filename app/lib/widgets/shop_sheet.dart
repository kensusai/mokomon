import 'dart:math';

import 'package:flutter/material.dart';

import '../data/backgrounds.dart';
import '../data/items.dart';
import '../logic/game_controller.dart';
import 'toast.dart';
import 'ui_kit.dart';

/// きせかえショップ(docs/game-design.md §7)。
/// 「あたま/かお/はいけい」のタブ切替。各タブのグリッドは中でスクロールせず、
/// 全セルが並ぶ高さを確保する(入りきらない場合はモーダル本体側がスクロールする)。
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
            LayoutBuilder(
              builder: (context, box) => SizedBox(
                height: _tallestTabHeight(box.maxWidth),
                child: TabBarView(
                  children: [
                    _itemGrid(controller, ItemSlot.head),
                    _itemGrid(controller, ItemSlot.face),
                    _bgGrid(controller),
                  ],
                ),
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

/// グリッド共通のレイアウト定数。3タブとも同じ列数・間隔で並べる。
const _cols = 4;
const _gap = 8.0;
const _itemAspect = 0.74;
const _bgAspect = 0.8;

/// [count] 個のセルを [_cols] 列で並べたときに必要な高さ。
double _gridHeight(double width, int count, double aspect) {
  final cell = (width - _gap * (_cols - 1)) / _cols;
  final rows = (count / _cols).ceil();
  return rows * (cell / aspect) + (rows - 1) * _gap;
}

/// `TabBarView` は子の高さを測れないので、3タブのうち一番背の高いものに合わせる。
///
/// 固定値にしていたときは、アイテムや背景テーマを増やすたびに下の行が
/// 見切れ、`NeverScrollableScrollPhysics` のせいで手も届かなくなっていた
/// (実際には sliver がカリングして生成すらされない)。データ件数から
/// 算出することで、追加しても無言で壊れないようにする。
double _tallestTabHeight(double width) {
  int slotCount(ItemSlot slot) => shopItems.where((i) => i.slot == slot).length;
  return [
    _gridHeight(width, slotCount(ItemSlot.head), _itemAspect),
    _gridHeight(width, slotCount(ItemSlot.face), _itemAspect),
    _gridHeight(width, bgThemes.length + 1, _bgAspect), // +1 = おまかせ
  ].reduce(max);
}

Widget _itemGrid(GameController controller, ItemSlot slot) => GridView.count(
      crossAxisCount: _cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: _gap,
      crossAxisSpacing: _gap,
      childAspectRatio: _itemAspect,
      children: [
        for (final item in shopItems)
          if (item.slot == slot) _ShopCell(item: item, controller: controller),
      ],
    );

/// 背景テーマの切替(コインで購入・端末ローカルで所持管理)。docs/game-design.md §13。
Widget _bgGrid(GameController controller) => GridView.count(
      crossAxisCount: _cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: _gap,
      crossAxisSpacing: _gap,
      childAspectRatio: _bgAspect,
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

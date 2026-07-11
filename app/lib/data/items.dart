/// きせかえアイテム。docs/game-design.md §7 参照。
enum ItemSlot { head, face }

class ShopItem {
  final String key;
  final String emoji;
  final String name;
  final int cost;
  final ItemSlot slot;

  const ShopItem(this.key, this.emoji, this.name, this.cost, this.slot);
}

/// 順序はあいことば(ownedBits/equipIdx)の互換性に影響するため変更しないこと。
const shopItems = <ShopItem>[
  ShopItem('ribbon', '🎀', 'リボン', 15, ItemSlot.head),
  ShopItem('flower', '🌸', 'おはな', 15, ItemSlot.head),
  ShopItem('strawhat', '👒', 'むぎわら', 20, ItemSlot.head),
  ShopItem('tophat', '🎩', 'シルクハット', 25, ItemSlot.head),
  ShopItem('glasses', '👓', 'めがね', 20, ItemSlot.face),
  ShopItem('sunglass', '😎', 'サングラス', 30, ItemSlot.face),
];

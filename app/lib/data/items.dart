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
  // ---- 以降は追加分(あいことば互換のため必ず末尾に追加する) ----
  ShopItem('party', '🎉', 'パーティーぼうし', 15, ItemSlot.head),
  ShopItem('wizard', '🧙', 'とんがりぼうし', 25, ItemSlot.head),
  ShopItem('tiara', '👸', 'ティアラ', 30, ItemSlot.head),
  ShopItem('cap', '🧢', 'キャップ', 20, ItemSlot.head),
  ShopItem('flowercrown', '💐', 'はなかんむり', 25, ItemSlot.head),
  ShopItem('propeller', '🚁', 'プロペラぼうし', 35, ItemSlot.head),
  ShopItem('bearears', '🐻', 'くまみみ', 20, ItemSlot.head),
  ShopItem('halo', '😇', 'てんしのわ', 35, ItemSlot.head),
  ShopItem('heartglass', '💗', 'ハートめがね', 25, ItemSlot.face),
  ShopItem('starglass', '⭐', 'ほしめがね', 25, ItemSlot.face),
  ShopItem('groucho', '🥸', 'はなメガネ', 30, ItemSlot.face),
  ShopItem('clownnose', '🔴', 'ピエロのはな', 15, ItemSlot.face),
  ShopItem('monocle', '🧐', 'モノクル', 20, ItemSlot.face),
  ShopItem('cheekseal', '💟', 'ほっぺシール', 10, ItemSlot.face),
  ShopItem('eyepatch', '🏴‍☠️', 'かいぞくがんたい', 20, ItemSlot.face),
  ShopItem('whiskers', '🐈', 'ねこひげ', 15, ItemSlot.face),
  ShopItem('mask', '😷', 'ますく', 15, ItemSlot.face),
  ShopItem('starcheeks', '✨', 'キラキラほっぺ', 10, ItemSlot.face),
];

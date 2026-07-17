/// ごはん3種。docs/game-design.md §3 参照。
class Food {
  final String key;
  final String emoji;
  final String name;
  final String desc;
  final int cost;
  final int hunger;
  final int happy;
  final int xp;

  const Food(this.key, this.emoji, this.name, this.desc, this.cost, this.hunger,
      this.happy, this.xp);
}

const foods = <Food>[
  Food('apple', '🍎', 'りんご', 'ちょっと おなかが ふくれる', 3, 15, 2, 3),
  Food('meat', '🍖', 'おにく', 'しっかり おなかいっぱい!', 6, 32, 4, 6),
  Food('cake', '🍰', 'ケーキ', 'ごきげんも アップ!', 10, 45, 14, 9),
  Food('onigiri', '🍙', 'おにぎり', 'ほどよく おなかに たまる', 4, 20, 3, 4),
  Food('ramen', '🍜', 'ラーメン', 'あつあつ! おなかも こころも', 8, 38, 8, 7),
  Food('parfait', '🍨', 'パフェ', 'ごきげん ばくあげ!', 14, 30, 20, 12),
];

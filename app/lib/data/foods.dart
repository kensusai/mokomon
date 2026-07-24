/// ごはん10種。docs/game-design.md §3 参照。
/// あいことば互換のため末尾追記のみ(既存の並びは変えない)。
class Food {
  final String key;
  final String emoji;
  final String name;
  final String desc;
  final int cost;
  final int hunger;
  final int happy;
  final int xp;

  const Food(
    this.key,
    this.emoji,
    this.name,
    this.desc,
    this.cost,
    this.hunger,
    this.happy,
    this.xp,
  );
}

const foods = <Food>[
  Food('apple', '🍎', 'りんご', 'ちょっと おなかが ふくれる', 3, 15, 2, 3),
  Food('meat', '🍖', 'おにく', 'しっかり おなかいっぱい!', 6, 32, 4, 6),
  Food('cake', '🍰', 'ケーキ', 'ごきげんも アップ!', 10, 45, 14, 9),
  Food('onigiri', '🍙', 'おにぎり', 'ほどよく おなかに たまる', 4, 20, 3, 4),
  Food('ramen', '🍜', 'ラーメン', 'あつあつ! おなかも こころも', 8, 38, 8, 7),
  Food('parfait', '🍨', 'パフェ', 'ごきげん ばくあげ!', 14, 30, 20, 12),
  Food('tamago', '🍳', 'たまごやき', 'あさごはんの ていばん', 5, 26, 3, 5),
  Food('pizza', '🍕', 'ピザ', 'みんな だいすき!', 12, 42, 10, 10),
  Food('burger', '🍔', 'ハンバーガー', 'がぶっと ボリューム!', 9, 40, 6, 8),
  Food('ice', '🍦', 'アイス', 'つめたくて あまーい!', 7, 18, 16, 6),
  Food('sushi', '🍣', 'おすし', 'ごちそう! ぜんぶ もりもり', 20, 50, 15, 15),
  Food('pudding', '🍮', 'プリン', 'ぷるぷる ごきげん おやつ', 6, 14, 18, 5),
];

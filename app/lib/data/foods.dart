/// ごはん14種。docs/game-design.md §3 参照。
/// あいことば・セーブには食べ物は入らないため並びは自由。
/// 一覧はそのままモーダルに表示されるので、安い順を保って追加する。
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
  Food('onigiri', '🍙', 'おにぎり', 'ほどよく おなかに たまる', 4, 20, 3, 4),
  Food('tamago', '🍳', 'たまごやき', 'あさごはんの ていばん', 5, 26, 3, 5),
  Food('pudding', '🍮', 'プリン', 'ぷるぷる ごきげん おやつ', 7, 14, 18, 5),
  Food('meat', '🍖', 'おにく', 'しっかり おなかいっぱい!', 8, 32, 5, 7),
  Food('ice', '🍦', 'アイス', 'つめたくて あまーい!', 10, 18, 16, 8),
  Food('ramen', '🍜', 'ラーメン', 'あつあつ! おなかも こころも', 12, 38, 10, 10),
  Food('burger', '🍔', 'ハンバーガー', 'がぶっと ボリューム!', 14, 40, 8, 11),
  Food('cake', '🍰', 'ケーキ', 'ごきげんも アップ!', 16, 45, 14, 13),
  Food('pizza', '🍕', 'ピザ', 'みんな だいすき!', 18, 42, 12, 14),
  Food('parfait', '🍨', 'パフェ', 'ごきげん ばくあげ!', 22, 30, 22, 16),
  Food('sushi', '🍣', 'おすし', 'ごちそう! ぜんぶ もりもり', 30, 50, 15, 20),
  Food('steak', '🥩', 'ステーキ', 'ジュージュー! とくべつな ひに', 45, 60, 18, 28),
  Food('dinner', '🍱', 'おうさまディナー', 'さいこうきゅうの フルコース!', 80, 70, 30, 40),
];

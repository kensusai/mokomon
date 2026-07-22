import 'dart:ui';

/// 種族定義。docs/game-design.md §4 参照。
class Species {
  final String key;
  final Color color;

  /// [たまご, ベビー, 中間, キング] — 表示名(絵文字なし)
  final List<String> names;

  /// 名前ピルに付ける絵文字。プロトタイプの SPECIES[].names に対応。
  final List<String> emojis;

  const Species({
    required this.key,
    required this.color,
    required this.names,
    required this.emojis,
  });
}

const speciesList = <Species>[
  Species(
    key: 'moko',
    color: Color(0xFF7ED6A5),
    names: ['たまご', 'もこ', 'もこもん', 'もこもこもん', 'キングもこ'],
    emojis: ['🥚', '🐣', '🌱', '🌿', '👑'],
  ),
  Species(
    key: 'pyon',
    color: Color(0xFFFF9CC2),
    names: ['たまご', 'ぴょん', 'ぴょんこ', 'ぴょんぴょんこ', 'キングぴょん'],
    emojis: ['🥚', '🐰', '🎀', '🐇', '👑'],
  ),
  Species(
    key: 'toge',
    color: Color(0xFF8FC9FF),
    names: ['たまご', 'とげ', 'とげまる', 'とげとげまる', 'キングとげ'],
    emojis: ['🥚', '💧', '⚡', '🌩️', '👑'],
  ),
  Species(
    key: 'pika',
    color: Color(0xFFFFD23E),
    names: ['きんのたまご', 'ぴか', 'ぴかりん', 'ぴかぴかりん', 'キングぴかりん'],
    emojis: ['🥚', '✨', '🌟', '☀️', '👑'],
  ),
  Species(
    key: 'bero',
    color: Color(0xFFC9A7FF),
    names: ['たまご', 'べろ', 'べろべろ', 'べろべろりん', 'キングべろ'],
    emojis: ['🥚', '😝', '👅', '🤪', '👑'],
  ),
  Species(
    key: 'buu',
    color: Color(0xFFFFB37E),
    names: ['たまご', 'ぶう', 'ぶーちゃん', 'ぶうぶうちゃん', 'キングぶー'],
    emojis: ['🥚', '🐽', '🐷', '🐗', '👑'],
  ),
  Species(
    key: 'medama',
    color: Color(0xFFB8E986),
    names: ['たまご', 'めだま', 'めだまん', 'ぎょろめだまん', 'キングめだまん'],
    emojis: ['🥚', '👀', '😳', '👁️', '👑'],
  ),
  // 以降は Flutter 版で追加した種族(あいことば互換のため末尾に追加すること)
  Species(
    key: 'nyan',
    color: Color(0xFFFF9E9E),
    names: ['たまご', 'にゃん', 'にゃんこ', 'にゃんにゃんこ', 'キングにゃんこ'],
    emojis: ['🥚', '🐱', '😸', '😻', '👑'],
  ),
  Species(
    key: 'dandy',
    color: Color(0xFFA3D9C9),
    names: ['たまご', 'ひげ', 'ダンディ', 'ナイスダンディ', 'キングダンディ'],
    emojis: ['🥚', '🥸', '🧔', '🎩', '👑'],
  ),
  Species(
    key: 'mojya',
    color: Color(0xFFB08968),
    names: ['たまご', 'もじゃ', 'もじゃもじゃ', 'もじゃもじゃまる', 'キングもじゃ'],
    emojis: ['🥚', '🧶', '🦁', '🐻', '👑'],
  ),
  Species(
    key: 'guru',
    color: Color(0xFF7FE0E0),
    names: ['たまご', 'ぐる', 'ぐるりん', 'ぐるぐるりん', 'キングぐるりん'],
    emojis: ['🥚', '😵', '🌀', '🌪️', '👑'],
  ),
  Species(
    key: 'paku',
    color: Color(0xFFF2E86D),
    names: ['たまご', 'ぱく', 'ぱっくん', 'ぱくぱっくん', 'キングぱっくん'],
    emojis: ['🥚', '😮', '🦈', '🐋', '👑'],
  ),
  Species(
    key: 'nemu',
    color: Color(0xFFB9C3E8),
    names: ['たまご', 'ねむ', 'ねむりん', 'ねむねむりん', 'キングねむりん'],
    emojis: ['🥚', '😪', '💤', '😴', '👑'],
  ),
  Species(
    key: 'robo',
    color: Color(0xFFAEBFD0),
    names: ['たまご', 'ろぼ', 'ろぼっち', 'メカろぼっち', 'キングろぼっち'],
    emojis: ['🥚', '🤖', '🔩', '⚙️', '👑'],
  ),
  Species(
    key: 'obake',
    color: Color(0xFFE6E9F5),
    names: ['たまご', 'おば', 'おばけん', 'おばけばけん', 'キングおばけん'],
    emojis: ['🥚', '👻', '🌙', '🎃', '👑'],
  ),
];

/// シークレット種(金のたまご)の index
const secretSpeciesIndex = 3;

/// キング(最終進化)の stage 番号。5段階化(たまご0/ベビー1/中間2/新段階3/
/// キング4)で 3→4 に移動した。旧セーブ・あいことば(v1)の stage 3 は
/// 読み込み時にキングへ引き上げる(docs/game-design.md §3)。
const kingStage = 4;

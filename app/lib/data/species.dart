import 'dart:ui';

/// 種族定義。docs/game-design.md §4 参照。
class Species {
  final String key;
  final Color color;

  /// [たまご, ベビー, 中間, キング] — 表示名(絵文字なし)
  final List<String> names;

  /// 名前ピルに付ける絵文字。プロトタイプの SPECIES[].names に対応。
  final List<String> emojis;
  final bool secret;

  const Species({
    required this.key,
    required this.color,
    required this.names,
    required this.emojis,
    this.secret = false,
  });
}

const speciesList = <Species>[
  Species(
    key: 'moko',
    color: Color(0xFF7ED6A5),
    names: ['たまご', 'もこ', 'もこもん', 'キングもこ'],
    emojis: ['🥚', '🐣', '🌱', '👑'],
  ),
  Species(
    key: 'pyon',
    color: Color(0xFFFF9CC2),
    names: ['たまご', 'ぴょん', 'ぴょんこ', 'キングぴょん'],
    emojis: ['🥚', '🐰', '🎀', '👑'],
  ),
  Species(
    key: 'toge',
    color: Color(0xFF8FC9FF),
    names: ['たまご', 'とげ', 'とげまる', 'キングとげ'],
    emojis: ['🥚', '💧', '⚡', '👑'],
  ),
  Species(
    key: 'pika',
    color: Color(0xFFFFD23E),
    names: ['きんのたまご', 'ぴか', 'ぴかりん', 'キングぴかりん'],
    emojis: ['🥚', '✨', '🌟', '👑'],
    secret: true,
  ),
  Species(
    key: 'bero',
    color: Color(0xFFC9A7FF),
    names: ['たまご', 'べろ', 'べろべろ', 'キングべろ'],
    emojis: ['🥚', '😝', '👅', '👑'],
  ),
  Species(
    key: 'buu',
    color: Color(0xFFFFB37E),
    names: ['たまご', 'ぶう', 'ぶーちゃん', 'キングぶー'],
    emojis: ['🥚', '🐽', '🐷', '👑'],
  ),
  Species(
    key: 'medama',
    color: Color(0xFFB8E986),
    names: ['たまご', 'めだま', 'めだまん', 'キングめだまん'],
    emojis: ['🥚', '👀', '😳', '👑'],
  ),
  // 以降は Flutter 版で追加した種族(あいことば互換のため末尾に追加すること)
  Species(
    key: 'nyan',
    color: Color(0xFFFF9E9E),
    names: ['たまご', 'にゃん', 'にゃんこ', 'キングにゃんこ'],
    emojis: ['🥚', '🐱', '😸', '👑'],
  ),
  Species(
    key: 'dandy',
    color: Color(0xFFA3D9C9),
    names: ['たまご', 'ひげ', 'ダンディ', 'キングダンディ'],
    emojis: ['🥚', '🥸', '🧔', '👑'],
  ),
  Species(
    key: 'mojya',
    color: Color(0xFFB08968),
    names: ['たまご', 'もじゃ', 'もじゃもじゃ', 'キングもじゃ'],
    emojis: ['🥚', '🧶', '🦁', '👑'],
  ),
  Species(
    key: 'guru',
    color: Color(0xFF7FE0E0),
    names: ['たまご', 'ぐる', 'ぐるりん', 'キングぐるりん'],
    emojis: ['🥚', '😵', '🌀', '👑'],
  ),
  Species(
    key: 'paku',
    color: Color(0xFFF2E86D),
    names: ['たまご', 'ぱく', 'ぱっくん', 'キングぱっくん'],
    emojis: ['🥚', '😮', '🦈', '👑'],
  ),
  Species(
    key: 'nemu',
    color: Color(0xFFB9C3E8),
    names: ['たまご', 'ねむ', 'ねむりん', 'キングねむりん'],
    emojis: ['🥚', '😪', '💤', '👑'],
  ),
  Species(
    key: 'robo',
    color: Color(0xFFAEBFD0),
    names: ['たまご', 'ろぼ', 'ろぼっち', 'キングろぼっち'],
    emojis: ['🥚', '🤖', '🔩', '👑'],
  ),
  Species(
    key: 'obake',
    color: Color(0xFFE6E9F5),
    names: ['たまご', 'おば', 'おばけん', 'キングおばけん'],
    emojis: ['🥚', '👻', '🌙', '👑'],
  ),
];

/// シークレット種(金のたまご)の index
const secretSpeciesIndex = 3;

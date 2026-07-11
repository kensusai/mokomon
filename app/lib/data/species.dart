import 'dart:ui';

/// 種族定義。docs/game-design.md §4 参照。
class Species {
  final String key;
  final Color color;

  /// [たまご, ベビー, 中間, キング] — 表示名(絵文字なし)
  final List<String> names;
  final bool secret;

  const Species({
    required this.key,
    required this.color,
    required this.names,
    this.secret = false,
  });
}

const speciesList = <Species>[
  Species(
    key: 'moko',
    color: Color(0xFF7ED6A5),
    names: ['たまご', 'もこ', 'もこもん', 'キングもこ'],
  ),
  Species(
    key: 'pyon',
    color: Color(0xFFFF9CC2),
    names: ['たまご', 'ぴょん', 'ぴょんこ', 'キングぴょん'],
  ),
  Species(
    key: 'toge',
    color: Color(0xFF8FC9FF),
    names: ['たまご', 'とげ', 'とげまる', 'キングとげ'],
  ),
  Species(
    key: 'pika',
    color: Color(0xFFFFD23E),
    names: ['きんのたまご', 'ぴか', 'ぴかりん', 'キングぴかりん'],
    secret: true,
  ),
  Species(
    key: 'bero',
    color: Color(0xFFC9A7FF),
    names: ['たまご', 'べろ', 'べろべろ', 'キングべろ'],
  ),
  Species(
    key: 'buu',
    color: Color(0xFFFFB37E),
    names: ['たまご', 'ぶう', 'ぶーちゃん', 'キングぶー'],
  ),
  Species(
    key: 'medama',
    color: Color(0xFFB8E986),
    names: ['たまご', 'めだま', 'めだまん', 'キングめだまん'],
  ),
];

/// シークレット種(金のたまご)の index
const secretSpeciesIndex = 3;

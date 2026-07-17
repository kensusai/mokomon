import 'dart:ui';

/// 背景テーマ(docs/game-design.md §13)。無料で切替でき、個体ごとに保存。
class BgTheme {
  final String key;
  final String name;
  final String emoji;
  final Color top;
  final Color bottom;
  const BgTheme(this.key, this.name, this.emoji, this.top, this.bottom);
}

const bgThemes = <BgTheme>[
  BgTheme('sora', 'そら', '☁️', Color(0xFFBFE9FF), Color(0xFFE8F9EF)),
  BgTheme('yuyake', 'ゆうやけ', '🌇', Color(0xFFFFA26B), Color(0xFFFFE3EC)),
  BgTheme('yozora', 'よぞら', '🌙', Color(0xFF2C3A69), Color(0xFF7B8BD1)),
  BgTheme('umi', 'うみ', '🐠', Color(0xFF56C7E8), Color(0xFFC5F2E6)),
  BgTheme('mori', 'もり', '🌳', Color(0xFF8FD48A), Color(0xFFEAF7DC)),
  BgTheme('yuki', 'ゆき', '⛄', Color(0xFFDCEAF7), Color(0xFFFFFFFF)),
];

/// 種族ごとのデフォルト背景(bgThemes の index)。
/// 種族追加時はここにも1エントリ足すこと。
const speciesDefaultBg = <int>[
  0, // moko そら
  1, // pyon ゆうやけ
  3, // toge うみ
  1, // pika ゆうやけ(金色が映える)
  3, // bero うみ
  4, // buu もり
  4, // medama もり
  1, // nyan ゆうやけ
  5, // dandy ゆき
  4, // mojya もり
  3, // guru うみ
  0, // paku そら
  2, // nemu よぞら
  5, // robo ゆき
  2, // obake よぞら
];

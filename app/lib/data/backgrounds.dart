import 'dart:ui';

/// 背景テーマ(docs/game-design.md §13)。
/// [cost] が0のものは常に所持ずみ(最初からある無料テーマ)、
/// それ以外はコインで購入すると使えるようになる(端末ローカルの所持管理)。
class BgTheme {
  final String key;
  final String name;
  final String emoji;
  final Color top;
  final Color bottom;
  final int cost;
  const BgTheme(
    this.key,
    this.name,
    this.emoji,
    this.top,
    this.bottom, [
    this.cost = 0,
  ]);

  bool get free => cost == 0;
}

// 色は「ガラッと変わる」を優先(こどもFB): よぞらはほぼ真っ暗、ゆきはほぼ真っ白。
// 最初の11種は無料(既存プレイヤーを購入なしで引き続き使えるようにする)。
const bgThemes = <BgTheme>[
  BgTheme('sora', 'そら', '☁️', Color(0xFF8FD4FF), Color(0xFFEAF9F0)),
  BgTheme('yuyake', 'ゆうやけ', '🌇', Color(0xFFFF7A3C), Color(0xFFFFD9A0)),
  BgTheme('yozora', 'よぞら', '🌙', Color(0xFF0E1330), Color(0xFF2A3566)),
  BgTheme('umi', 'うみ', '🐠', Color(0xFF1E88C7), Color(0xFF7FE0D9)),
  BgTheme('mori', 'もり', '🌳', Color(0xFF5FA857), Color(0xFFC9EBB0)),
  BgTheme('yuki', 'ゆき', '⛄', Color(0xFFF4F8FC), Color(0xFFFFFFFF)),
  BgTheme('uchu', 'うちゅう', '🪐', Color(0xFF0B0620), Color(0xFF251B4D)),
  BgTheme('sabaku', 'さばく', '🌵', Color(0xFFF5C97B), Color(0xFFFBE8C0)),
  BgTheme('yuenchi', 'ゆうえんち', '🎡', Color(0xFF7FC5FF), Color(0xFFFFE3F2)),
  BgTheme('kazan', 'かざん', '🌋', Color(0xFF3B1212), Color(0xFFA62C2C)),
  BgTheme('niji', 'にじぞら', '🌈', Color(0xFFFFB6E1), Color(0xFFC9F0FF)),
  // ---- 以降は追加分(コインで購入)。追加は必ず末尾に ----
  BgTheme('fukaiumi', 'ふかいうみ', '🐋', Color(0xFF0B3B5C), Color(0xFF13698F), 40),
  BgTheme('janguru', 'ジャングル', '🐒', Color(0xFF0F3D1E), Color(0xFF2E7D42), 30),
  BgTheme('candy', 'キャンディランド', '🍬', Color(0xFFFFC9E6), Color(0xFFD9C6FF), 40),
  BgTheme('oshiro', 'おしろ', '🏰', Color(0xFFC9B8FF), Color(0xFFFFE8B8), 200),
  BgTheme('aurora', 'オーロラ', '🌌', Color(0xFF0C2B3D), Color(0xFF2E9B7A), 250),
  BgTheme('onsen', 'おんせん', '♨️', Color(0xFFFCE7EA), Color(0xFFFFF6EE), 30),
  BgTheme('yoichi', 'よいちまつり', '🏮', Color(0xFF3B1420), Color(0xFFB3402E), 40),
  BgTheme(
    'hanabatake',
    'はなばたけ',
    '🌷',
    Color(0xFF8FE0A8),
    Color(0xFFFFD3E8),
    20,
  ),
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
  8, // paku ゆうえんち
  2, // nemu よぞら
  6, // robo うちゅう
  2, // obake よぞら
  0, // yuni そら(にじが映える)
];

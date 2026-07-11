# もこもん Flutter版

## セットアップ

1. Flutter SDK をインストール: https://docs.flutter.dev/get-started/install
2. このディレクトリでプラットフォームファイルを生成:
   ```bash
   flutter create --org com.yourname --project-name mokomon .
   flutter pub get
   flutter run
   ```
   (`lib/` と `pubspec.yaml` は既存のものが使われます)

## 移植の進め方

`docs/game-design.md` が仕様の正。プロトタイプ(`prototype/mokomon.html`)を横に置いて画面ごとに移植する。

推奨順:
1. `GameState`(済・骨組み)+ ホーム画面のメーター/ボタン
2. クリーチャー描画(`CreaturePainter`) — SVGパス移植済みの体+顔
3. なでなで/ごはん/減衰/進化判定
4. 進化カットシーン
5. ミニゲーム3種
6. お絵かき / きせかえ / ずかん / あいことば

## 構成

```
lib/
├── main.dart               # エントリ・テーマ
├── data/
│   ├── species.dart         # 種族7種の定義
│   ├── foods.dart           # ごはん3種
│   └── items.dart           # きせかえ6種
├── models/
│   └── game_state.dart      # 状態・永続化・進化判定・あいことば
├── screens/
│   └── home_screen.dart     # ホーム画面(骨組み)
└── widgets/
    └── creature_painter.dart # キャラのCustomPainter(体パス移植済み)
```

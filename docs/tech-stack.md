# 技術選定

実装済みの選定を記録する(選定プロセスの詳細は各節)。

## アプリ本体

| 項目 | 選定 | 理由 | 不採用案 |
|---|---|---|---|
| フレームワーク | Flutter / Dart (SDK ^3.5.0) | 検証済みHTMLプロトタイプを単一コードベースで iOS/Android/Web に展開できる。子ども向けのリッチな描画・アニメーションが CustomPainter で実装しやすい | React Native(SVG描画の移植コスト大)、ネイティブ2本(工数2倍) |
| 状態管理 | ChangeNotifier + ListenableBuilder(標準のみ) | 画面数が少なく単一の GameState で足りる。依存を増やさない(YAGNI) | riverpod / bloc(現規模では過剰) |
| 永続化 | shared_preferences | セーブデータはJSON1件のみ。プラットフォーム横断で最小 | sqlite / hive(構造化データが無い) |
| 効果音 | audioplayers + 実行時WAV合成(自作 SoundSynth) | プロトタイプが WebAudio 合成音のため、同じ波形をPCM合成すれば音源アセット不要 | 音源ファイル同梱(アセット管理・容量増) |
| フォント | M PLUS Rounded 1c(OFL・同梱) | プロトタイプ指定の丸ゴシック。ライセンス同梱で配布可 | google_fonts パッケージ(実行時DL・オフライン不可) |

## CI

| 項目 | 選定 | 理由 |
|---|---|---|
| CI基盤 | GitHub Actions | リポジトリのホストに合わせる(skills/ci-construction)。Flutter 公式アクションとキャッシュが揃っている。詳細は docs/ci.md |

# もこもん 〜ふしぎないきもの〜

子ども向け・いきもの育成ゲーム。

## 構成

```
mokomon/
├── prototype/        # 検証済みHTMLプロトタイプ(凍結資料。最新仕様は docs/game-design.md と app/)
├── docs/
│   ├── game-design.md    # ゲーム設計書(パラメータ・全仕様。移植はこれを正とする)
│   ├── frontend.md       # Flutter実装ルール(構成・state方針・共通コンポーネント)
│   └── store-release.md  # ストア公開ガイド(子ども向け規約・チェックリスト)
└── app/              # Flutter アプリ(プロトタイプ全機能を移植済み)
```

## クイックスタート

### プロトタイプを遊ぶ
`prototype/mokomon.html` をブラウザで開くだけ。

### Flutter版を動かす
```bash
cd app
flutter pub get
flutter run        # -d macos / -d chrome / 実機
```

### テスト
```bash
cd app
flutter analyze && flutter test
```

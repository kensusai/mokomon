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

### ブラウザで遊ぶ(Web版)
https://kensusai.github.io/mokomon/ を開くだけ(main の最新を自動公開)。iPhone では Safari の共有メニューから「ホーム画面に追加」すると全画面で遊べる。

### プロトタイプを遊ぶ
`prototype/mokomon.html` をブラウザで開くだけ。

### Flutter版を動かす
```bash
cd app
flutter pub get
flutter run        # -d macos / -d chrome / -d iphone(シミュレータ) / 実機
```

### iOS シミュレータで動かす

初回は Xcode 16.2 以上と CocoaPods が必要(手順は `docs/ci.md` の「ローカルでの iOS 動作確認」)。環境が揃っていれば以下で起動する。

```bash
open -a Simulator            # iPhone シミュレータを立ち上げる
cd app
flutter devices              # 起動したシミュレータの ID を確認
flutter run -d iphone        # 候補が1台なら名前の一部で指定できる
```

`flutter doctor` で Xcode と CocoaPods の行に警告が出ている場合は、先に `docs/ci.md` の手順で解消する。

### テスト
```bash
cd app
flutter analyze && flutter test
```

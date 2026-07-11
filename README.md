# もこもん 〜ふしぎないきもの〜

6〜7歳の子ども向け・いきもの育成ゲーム。
HTMLプロトタイプで検証済みのゲームデザインを、Flutter でストア版として本実装するプロジェクト。

## 構成

```
mokomon/
├── prototype/        # 検証済みHTMLプロトタイプ(スマホブラウザでそのまま遊べる・仕様の原本)
├── docs/
│   ├── game-design.md    # ゲーム設計書(パラメータ・全仕様。移植はこれを正とする)
│   └── store-release.md  # ストア公開ガイド(子ども向け規約・収益化・チェックリスト)
└── app/              # Flutter アプリ(ストア版)
```

## クイックスタート

### プロトタイプを遊ぶ
`prototype/mokomon.html` をブラウザで開くだけ。

### Flutter版の開発を始める
```bash
cd app
flutter create .   # android/ ios/ などのプラットフォームファイルを生成
flutter pub get
flutter run
```
詳細は `app/README.md` を参照。

## 検証で得られた学び(プロトタイプより)

- 進化は「隠しパラメータ+光る予兆+劇的カットシーン」が正解。ゲージ表示は興ざめする
- 報酬間隔は短く。最初の進化まではミニゲーム2〜3回で届くテンポにする
- お絵かき(自由塗り)は最も長く遊ばれた機能。子どもは茶色を多用する(仕様です)
- 隠し機能(おしりタッチ💨)のような「自分で見つける笑い」が強い
- コレクション(ずかん)は「埋まったら終わり」になるため、きせかえ・シークレット枠で出口を用意する

## GitHubへのpush

```bash
cd mokomon
git remote add origin git@github.com:<あなたのユーザー名>/mokomon.git
git push -u origin main
```

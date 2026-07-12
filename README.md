# もこもん 〜ふしぎないきもの〜

6〜7歳の子ども向け・いきもの育成ゲーム。
HTMLプロトタイプで検証済みのゲームデザインを、Flutter でストア版として本実装するプロジェクト。

## 構成

```
mokomon/
├── prototype/        # 検証済みHTMLプロトタイプ(凍結資料。最新仕様は docs/game-design.md と app/)
├── docs/
│   ├── game-design.md    # ゲーム設計書(パラメータ・全仕様。移植はこれを正とする)
│   ├── frontend.md       # Flutter実装ルール(構成・state方針・共通コンポーネント)
│   └── store-release.md  # ストア公開ガイド(子ども向け規約・収益化・チェックリスト)
└── app/              # Flutter アプリ(ストア版・プロトタイプ全機能を移植済み)
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

実装状況: たまご孵化 → ごはん/なでなで → ミニゲーム3種 → 進化カットシーン → ずかん/新しいたまご → きせかえ/おえかき/あいことば/効果音/💨 まで、プロトタイプの全機能を移植済み。

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

<!-- agent-ready:begin -->
## AIエージェント開発

このリポジトリは **agent-ready** 対応です。AIコーディングエージェント向けの設定と手順書は [agent-ready](https://github.com/agent-ready/agent-ready) によって生成されています。

- `CLAUDE.md` — Claude Code 向けプロジェクトガイド
- `AGENTS.md` — Codex など `AGENTS.md` 対応エージェント向けのルールとワークフロー
- `.claude/commands/` — Claude Code スラッシュコマンド(`/review`, `/fix-bug`, `/add-feature`, `/test` ほか)
- `skills/` — 全エージェント共通のタスク手順書
- `docs/ai-workflow.md` — このリポジトリでのAIエージェントの使い方

適用中の開発プリセット: **クリーンアーキテクチャ, ドキュメント重視, パフォーマンス重視, 継続的リファクタリング, セキュリティ重視, シンプル実装, TDD(テスト駆動開発), 型安全重視**

開発フェーズ別ワークフロー: **プロジェクト概要, ドメイン理解, アーキテクチャ設計, 技術選定, DB設計, CI構築, バックエンド開発, フロントエンド開発, インフラ構築, 監視設計**

スタックが変わったら `npx agent-ready sync` で再生成、`npx agent-ready check` で乖離チェックができます(選択内容は `agent-ready.config.json` に保存されています)。
<!-- agent-ready:end -->

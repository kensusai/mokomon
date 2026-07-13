# agent-ready フィードバック

## 2026-07-12 | bug | CLAUDE.md(AIエージェントへの注意事項)
- 状況: 作業の区切りで指示どおり `npx agent-ready check` を実行したところ、npm レジストリに `agent-ready` パッケージが存在せず 404 で失敗した(`npx agent-ready modernize` / `update` も同様に実行不能)。
- 提案: 実在するパッケージ名/インストール手順を記載するか、未公開の間は CLAUDE.md の該当手順を「利用可能になったら実行」と明記する。
- ステータス: 反映済み(生成テンプレート全26ファイルの `npx agent-ready` を `agent-ready` に変更し、自己メンテナンスルールと ai-workflow に「npm 未公開・`npm link` 導入、コマンドが無い環境では check/update をスキップして報告」の注記を追加。ja/en)

## 2026-07-12 | gap | skills/frontend-development
- 状況: Flutter アプリの画面実装で SKILL.md を参照したが、内容が Web フロントエンド(Lighthouse・DOM 仮想化・TanStack Query 等)前提で、Flutter に読み替える判断が必要だった。
- 提案: フレームワーク非依存の原則(state 分離・テストファースト・a11y)と、Web 固有の節を分離する。Flutter/モバイル向けの対応表があるとよい。
- ステータス: 反映済み(frontend-development スキル冒頭に「Web 専用ではない」注記と読み替え表 — セマンティックHTML→アクセシビリティAPI(Semantics)、レスポンシブ→画面サイズ対応、仮想化→ListView.builder 等、Lighthouse→Flutter DevTools 等 — を追加。performance プリセットの同フェーズ断片にも読み替え行を追加。ja/en)

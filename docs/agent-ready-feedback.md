# agent-ready フィードバック

## 2026-07-12 | bug | CLAUDE.md(AIエージェントへの注意事項)
- 状況: 作業の区切りで指示どおり `npx agent-ready check` を実行したところ、npm レジストリに `agent-ready` パッケージが存在せず 404 で失敗した(`npx agent-ready modernize` / `update` も同様に実行不能)。
- 提案: 実在するパッケージ名/インストール手順を記載するか、未公開の間は CLAUDE.md の該当手順を「利用可能になったら実行」と明記する。
- ステータス: 未回収

## 2026-07-12 | gap | skills/frontend-development
- 状況: Flutter アプリの画面実装で SKILL.md を参照したが、内容が Web フロントエンド(Lighthouse・DOM 仮想化・TanStack Query 等)前提で、Flutter に読み替える判断が必要だった。
- 提案: フレームワーク非依存の原則(state 分離・テストファースト・a11y)と、Web 固有の節を分離する。Flutter/モバイル向けの対応表があるとよい。
- ステータス: 未回収

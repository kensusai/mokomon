---
description: コードベースを調査してプランを書く(APIキー不要)
---

プランを作成してください。種類: $ARGUMENTS(refactor / review / modernize、または自由指示。省略時は refactor)

`skills/write-plan/SKILL.md` に厳密に従ってください:

1. リポジトリを実際に調査する(読んでいないファイルに言及しない)
2. フォーマット契約どおりに `docs/plans/<type>/PLAN.md` を作成(`- [ ] <ID>:` チェックボックス・フェーズ見出し・空の進捗ログ)
3. modernize の場合、バージョンは `npm view` / endoflife.date で実測する

この時点では実装しないこと。完成後は `/plan-next` で1タスクずつ実行し、進捗は `agent-ready plan status` で確認できます。

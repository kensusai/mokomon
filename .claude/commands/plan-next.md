---
description: プランの次の未完了タスクを1つ実行する
---

プランの次の未チェックタスクを1つ実行してください。対象プラン: $ARGUMENTS(省略時は `docs/plans/` 配下で未完了タスクが残る最初の PLAN.md)

`skills/execute-plan/SKILL.md` の手順に厳密に従ってください:

1. 最初の未チェックタスク(`- [ ]`)を1つだけ選ぶ
2. 実装 → タスク記載の検証を実行
3. 通ったら `- [x]` に更新し、進捗ログに1行追記
4. 停止して報告(次のタスクには進まない)

進捗の確認は `agent-ready plan status`。連続実行したい場合は `/plan-all`(最後まで)か Claude Code の `/loop /plan-next` が使えます。

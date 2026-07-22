---
name: greenfield
description: 新規開発を要件定義からリリース・運用まで導く司令塔(いまの工程を判定して次の一手を提示する)。何から始めるか・次に何をするかに迷ったときに使う
---

# 新規開発ガイド(/greenfield)

0→1 の開発を、工程ごとの成果物で進行管理しながらリリース・運用まで導く手順書。各工程の実体は既存のフェーズスキルとプラン機構で、このスキルは「いまどこにいるか・次に何をするか」の判定と誘導だけを行う。

## 進行の判定

呼ばれたら、下表の成果物ドキュメントの有無(と内容の鮮度)で現在地を判定し、次の一手を提示する。ユーザーが工程を指定した場合はそこから始める。

| 工程 | 成果物 | 実行するもの |
|---|---|---|
| 1. 要件定義 | `docs/requirements.md` | `/requirements-definition` |
| 2. アーキテクチャ設計 | `docs/architecture.md`・`docs/tech-stack.md` | `/architecture-design` → `/tech-selection` |
| 3. 機能設計・DB設計 | `docs/functional-design.md`・`docs/database.md` | `/functional-design` → `/db-design` |
| 4. タスク分割 | `docs/plans/mvp/PLAN.md` | `/plan-write mvp` — 要件・機能設計・DB設計を入力に、機能単位のタスクへ分割 |
| 5. 開発 | プランのチェックボックス消化 | `/plan-next`(1タスクずつ)/ `/plan-all`(連続)。CI・インフラのタスクは `/ci-construction` `/infra-construction` の規約に従う |
| 6. デプロイ | `docs/deployment.md` | `/deployment` — 本番への適用は人間の承認を待つ |
| 7. アップデート | 運用(継続) | `agent-ready check` → `update`(ドキュメント追従)、`agent-ready modernize`(依存の最新化プラン) |

## ルール

- 工程を飛ばさない。ただしユーザーが「そこはもう決まっている」と言う工程は、決定内容を成果物ドキュメントに記録してから先へ進む(口頭のまま先へ進めない — 後続フェーズはドキュメントを入力にするため)。
- 使いたいフェーズのコマンドが無い場合(ワークフロー未選択・部分選択)は、`agent-ready workflow add <phase>` で追加してから実行する。
- タスク分割のプランは、要件ID(`REQ-`)・機能ID(`F-`)にトレースできる粒度で書く(1タスク = 1機能またはその一部)。
- このスキル自体は成果物を作らない。判定と誘導に徹し、実作業は各フェーズスキルの手順に従う。

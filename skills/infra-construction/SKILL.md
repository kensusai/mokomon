---
name: infra-construction
description: IaC(CloudFormation / CDK / Terraform 等)でインフラを構築し、方針を docs/infrastructure.md に整理する
---

# フェーズ 11: インフラ構築

## 目的

アプリケーションを動かす基盤を IaC(Infrastructure as Code)として構築し、方針を `docs/infrastructure.md` に整理する。「コンソールで手作業した結果、誰も再現できない環境」を作らないことが最重要。

## 進め方

1. IaCツールを確定し、`docs/tech-stack.md` に記録する(例: AWS CloudFormation / CDK / Terraform)。既存の IaC 資産・手作業で作られたリソースがあれば棚卸しから始める。
2. `docs/infrastructure.md` を作成する。
3. スタックを小さく分割して実装する。各変更は「テンプレート検証 → 差分確認(change set / plan) → 適用」の順で行う。
4. 検証: テンプレートのバリデーション(例: `aws cloudformation validate-template` / cfn-lint / `terraform validate`)と、dev 環境への適用確認。

## docs/infrastructure.md に含める内容

- **IaCツールの選定と理由**
- **スタック構成** — 分割単位(ネットワーク / データ / アプリ等)と依存関係、命名規則
- **環境分離** — dev / stg / prod の分け方と、環境差分の持たせ方(パラメータ / 変数)
- **シークレット管理** — Secrets Manager / SSM Parameter Store 等。テンプレートやリポジトリに秘密情報を置かない
- **IAM方針** — 最小権限、ロール設計、人とCIで権限を分ける
- **状態・ドリフト管理** — ドリフト検出(CloudFormation drift / terraform state)の運用と、手変更を見つけたときの扱い
- **ロールバック** — 失敗時の切り戻し手順(スタック単位で戻せる設計)
- **コスト** — 概算と、コストに効くリソースの明示

## ルール

- インフラ変更はすべて IaC 経由で行う。コンソールでの手変更は緊急時のみとし、直後に IaC へ反映する。
- 適用前に必ず差分(change set / plan)を確認し、破壊的変更(Replacement / destroy)は明示して合意を取る。
- 本番適用は dev / stg での検証後に行う。
- 秘密情報・アカウントIDのハードコード禁止。パラメータ化する。

## セキュリティ: インフラの必須要件

- IAM は最小権限で設計する。ワイルドカード(`Action: "*"` / `Resource: "*"`)を安易に使わず、人・アプリ・CIでロールを分ける。
- セキュリティグループ / ファイアウォールは deny-by-default で必要なポートのみ開放。`0.0.0.0/0` の開放はレビュー必須。
- 保存データ・通信の暗号化をデフォルトにする(S3 / RDS / EBS の暗号化、TLS)。
- 秘密情報は Secrets Manager / SSM に置き、テンプレート・状態ファイル・出力(Outputs)に露出させない。
- 監査ログ(CloudTrail 等)の有効化をインフラ定義に含める。

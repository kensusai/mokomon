# CI方針

パイプライン本体: `.github/workflows/ci.yml`

## CI基盤の選定と理由

**GitHub Actions**。リポジトリのホスト(GitHub)に合わせる原則どおり。Flutter 公式アクション(`subosito/flutter-action`)による SDK キャッシュが利用でき、追加インフラが不要。

## パイプライン構成

| ジョブ | 内容 | 依存 |
|---|---|---|
| check | `dart format --set-exit-if-changed` → `flutter analyze` → `flutter test` | — |
| build-web | `flutter build web`(リリースビルド検証) | check |
| build-android | `flutter build apk --release` + APKを成果物 `mokomon-apk` として保存(保持14日) | check |

- **トリガー**: `main` への push、およびすべての pull request
- コマンドはローカルと完全に同一(`cd app && flutter analyze && flutter test` 等)。CI専用のスクリプトや隠しロジックは置かない
- ビルド2ジョブは check 成功後に並列実行(テスト失敗時のビルド時間を節約)

## 実行環境

- ランナー: `ubuntu-latest`
- Flutter: **3.44.6 / stable に固定**(ワークフローの `FLUTTER_VERSION`)。ローカルのバージョンを上げたら同時にこの値を更新する
- Java: Temurin 17(Android ビルドのみ)
- バージョンマトリクスは組まない(サポート対象は最新 stable のみ)

## キャッシュ戦略

- `subosito/flutter-action` の `cache: true` で Flutter SDK と pub キャッシュを保存
- キーはアクションが Flutter バージョン・プラットフォームから自動生成。`FLUTTER_VERSION` を上げるとキャッシュは自然に無効化される

## シークレット管理

- 使用中のシークレット: `ANDROID_KEYSTORE_BASE64`(CI用署名鍵のbase64)/ `ANDROID_KEYSTORE_PASSWORD`。ワークフローでは環境変数経由でのみ参照し、ログに出力しない
- `GITHUB_TOKEN` は `permissions: contents: read` に最小化済み(release-apk ジョブのみ `contents: write`)
- 追加する場合は GitHub Secrets のみに置く。ワークフローファイル・ログへの平文出力は禁止(`add-mask` を利用)。フォークからの PR には secrets が渡らない GitHub の既定動作を維持する(`pull_request_target` を使わない)
- 将来のストア署名鍵は GitHub Secrets + 環境(environment)保護で扱い、リポジトリには置かない

## 依存の脆弱性・更新

- Dependabot(`.github/dependabot.yml`)で pub と GitHub Actions を週次チェック
- メジャー更新は1つずつ、検証とセットで取り込む(CLAUDE.md の最新化ポリシーに従う)

## ブランチ保護(リモート作成後に設定)

GitHub にリポジトリを作成したら、`main` に以下を設定する:

- Required status checks: `format / analyze / test`、`build (web)`、`build (android debug)`
- Require a pull request before merging(直 push 禁止)

## 実機での動作確認(Android)

**スマホからは Releases 経由が確実**(Artifacts はモバイルアプリ・未ログインではDLできない):

1. スマホのブラウザで https://github.com/kensusai/mokomon/releases/tag/apk-latest を開く
2. Assets の `app-release.apk` をタップしてダウンロード(公開リポジトリなのでログイン不要)
3. Android 側で「提供元不明のアプリのインストール」を許可してインストール

`apk-latest` は main への push ごとに `release-apk` ジョブが自動更新するローリングリリース(prerelease)。PCからは従来どおり Actions の Artifacts(`mokomon-apk`)も使える。

### APKの署名

- CI・ローカルとも **固定のCI用鍵**(`android/key.properties` + `mokomon-ci.jks`、どちらもgitignore)で署名する。鍵は GitHub Secrets(`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD`)から復元される
- 署名が毎回同じなので**端末での上書き更新が可能**。かつてデバッグ鍵(ランナーごとに毎回生成)で署名していた時期のAPKからは署名が変わっているため、一度アンインストールが必要
- `key.properties` が無い環境(フォークPR等)はデバッグ鍵にフォールバックしてビルドだけ検証する
- ストア配布時はこのCI用鍵ではなく、Play App Signing を前提に別途鍵を用意する(`docs/store-release.md`)

## iOS の実機配布について

- CI で未署名 `.ipa` を作ることは可能だが、**署名なしでは iPhone にインストールできない**
- 実機配布は Apple Developer Program(有料)+ TestFlight が現実的。導入時に macOS ランナー(分単価10倍)+ 証明書の Secrets 管理(fastlane match 等)を追加する
- それまでの iOS 動作確認は、ローカル Mac の Xcode から実機に直接 `flutter run` する(無料Apple IDで7日間有効の署名が可能。要 Xcode 15+)

## デプロイトリガー

- 現時点で CD なし。将来は `v*` タグでストア向けビルド(署名付き)を行うジョブを追加する想定(`docs/store-release.md` 参照)

## 失敗時の運用

- フレーキーなテストは再実行でしのがず、その日のうちに決定化する(💨6%抽選の前例: 乱数を注入可能にして解決。`test/helpers.dart` の `NoPuffRandom`/`FixedRandom` を使う)
- インフラ起因(ランナー障害・キャッシュ破損)のみ Re-run jobs を許可
- 常時アニメーションがあるため widget test で `pumpAndSettle` を使わない(docs/frontend.md)

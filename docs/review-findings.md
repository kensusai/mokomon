# コードレビュー指摘一覧

最終レビュー: 2026-07-20 / 対象: app/lib 配下 全体(models/logic/data/screens/widgets/audio)

自動チェックは事前にクリーン(`dart format --set-exit-if-changed .` 差分なし、`flutter analyze` 指摘なし)。以下は手動の2パスレビュー(正しさ→品質)で見つけ、実際のコードを読んで裏取りした指摘のみ。

## 1. 壊れたセーブデータで名簿エントリが1件でも読めないと、全セーブデータが失われる
- 重大度: 高
- 種別: バグ
- 場所: `app/lib/data/save_store.dart:24-27`, `app/lib/models/game_state.dart:225`
- 問題: `SaveStore.load()` は `loadJson()` 全体を1つの `try/catch` で囲んでいる。`loadJson()` 内の名簿(roster)復元は `int.parse(e.key as String)` を素通しで呼んでおり、名簿のキーが1つでも不正だと例外を投げる。その例外は `load()` の catch で握りつぶされ、**コイン・図鑑・所持アイテムを含む保存データ全体が初期状態に巻き戻る**。
- 根拠: 該当コードを実読。`loadJson()` の他フィールド(hunger/happy/xp等)はデフォルト値へのフォールバックがあるが、roster の `int.parse` だけは無防備。
- 提案: roster の各エントリを個別に try/catch し、壊れたエントリだけスキップする(他のフィールドは復元を継続)。
- ステータス: 未対応

## 2. ミュート中にゲームBGMへ切り替えると、後で解除しても音が鳴らなくなる
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/audio/sfx_player.dart:87`(`playOverrideBgm`)、`:145-152`(`syncBgm`)
- 問題: `playOverrideBgm()` は `enabled()` (ミュート判定) のチェック**前**に `_bgmStarted = true` を無条件でセットしている(87行目)。ミュート中にミニゲームへ入る(`home_screen.dart` の `_onPlayPressed` が `playOverrideBgm(Sfx.bgmGame)` を呼ぶ)→ `.play()` はスキップされるが `_bgmStarted` は true のまま → あとでミュート解除(`toggleSound()` → `syncBgm()`)すると `_bgmStarted` が true なので `player.resume()` が呼ばれるが、`_bgm` にはまだ音源がセットされていない → 何も鳴らず、例外は catch で握りつぶされる。
- 根拠: `syncBgm()`(140-160行目)は同じロジックを `if (enabled())` の中でのみ `_bgmStarted = true` にしており、対称性が崩れていることを確認。
- 提案: `playOverrideBgm()` でも `_bgmStarted = true` を `if (enabled())` ブロックの中に移動する。
- ステータス: 未対応

## 3. 端末の時計が巻き戻ると、オフライン減衰で hunger/happy が100を超えて張り付く
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/models/game_state.dart:162-168`(`applyOfflineDecay`)
- 問題: `mins = (now - lastSavedMs) / 60000.0` が負(時計を戻した・NTP補正等)になると、`min(50, mins/3)` は負値をそのまま返し、`hunger - (負値)` で **hunger/happy が増加**する。`max(15, ...)` はあるが上限クランプが無いため、理論上100を大きく超えたまま張り付く。
- 根拠: 該当コードを実読。`decayTick()` 側も `max(0, ...)` のみで上限クランプが無く、一度超過すると自然には戻らない。
- 提案: `mins` を `max(0, mins)` にする、かつ `hunger`/`happy` の代入結果を `.clamp(0, 100)` する。
- ステータス: 未対応

## 4. `loadJson` が復元値を一切クランプしない(あいことば経由の `loadCode` は行っている)
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/models/game_state.dart:199-224`(`loadJson`)
- 問題: `loadCode()` は stage/xp/hunger/happy/species を範囲内にクランプするが、`loadJson()`(通常のセーブ復元)は同じフィールドを無条件に信頼する。指摘3のバグと組み合わさると、一度壊れた値が通常のセーブ/ロードを通じて永続化され続ける。
- 根拠: 両メソッドを読み比べて確認。
- 提案: `loadJson()` でも hunger/happy/xp/coins/stage を同様にクランプする。
- ステータス: 未対応

## 5. おえかき画面で `ui.Image` が dispose されず、繰り返すほどネイティブメモリが漏れる
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/screens/paint_screen.dart:101,113,219,238`(`_baseImage` の代入箇所)、State クラスに `dispose()` オーバーライドが存在しない
- 問題: `_baseImage`(`decodeImageFromList`/`ui.decodeImageFromPixels` で生成される `dart:ui` の `Image`)は、バケツぬりつぶしのたびに古い参照を破棄せず新しいインスタンスで上書きされる(219行目)。`_clear()` でも同様(238行目)。画面を閉じるときに最後の1枚を解放する `dispose()` も無い。`ui.Image` はネイティブ/GPU側のメモリを保持するため、繰り返すほど解放されないバッファが積み上がる。
- 根拠: 該当コードを実読し、`State<PaintScreen>` に `dispose()` オーバーライドが無いことを grep で確認。
- 提案: 代入前に `_baseImage?.dispose()` を呼ぶ。`dispose()` オーバーライドを追加し、最後の `_baseImage` を解放する。
- ステータス: 未対応

## 6. もぐらたたきの種族数がハードコードされ、種族追加時に無言で壊れる
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:297`(`WhackMole(..., speciesIndex: _rng.nextInt(15), ...)`)
- 問題: `minigames.dart` は `species.dart` を import しておらず、`15` は `speciesList.length` と現状たまたま一致しているだけ。種族は「末尾に追加する」運用(このセッションだけで何度も種族を追加している)なので、次に追加したときコンパイルエラーにならないまま新種族がもぐらたたきに出現しなくなる。
- 根拠: `speciesList` の実データを数え15件であることを確認。`minigames.dart` に `species.dart` の import が無いことも確認。
- 提案: `WhackGame` にコンストラクタ引数で `speciesCount` を渡す(呼び出し側で `speciesList.length` を渡す)。
- ステータス: 未対応

## 7. フルーツキャッチ/ふうせんわり/もぐらたたきの画面が、ほぼ丸ごと重複している
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/screens/catch_screen.dart:28-70`, `app/lib/screens/balloon_screen.dart:28-70`, `app/lib/screens/whack_screen.dart:29-63`
- 問題: `_Phase` enum・State フィールド(`_phase`/`_game`/`_ticker`/`_lastTick`等)・`dispose()`・`_start()`・`_onTick()` の骨格が、ゲーム型名以外ほぼ同一(`diff` でほぼ差分なしを確認)。もぐらたたきは `RenderBox` 取得の有無など既にわずかにドリフトしている。
- 根拠: `diff <(catch_screen.dart) <(balloon_screen.dart)` の該当範囲を実行し、型名以外の差分がほぼ無いことを確認。
- 提案: 「時間制で降下/上昇するアイテムをタップする」共通の土台(mixin または汎用 State クラス)を切り出す。今回の `MistakeGameOverMixin` と同じ発想。
- ステータス: 未対応

## 8. `failed`/`continueAfterFail` が4クラスへ一字一句コピペされている
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:142,176`(`PuzzleGame`)/`350,381`(`OddOneGame`)/`482,501`(`OrderGame`)/`535,567`(`CountGame`)
- 問題: `bool get failed => mistakes >= minigameMaxMistakes;` と `void continueAfterFail() => mistakes = 0;` が4クラスに同一実装でコピペされている(直前のセッションで追加した機能がそのまま重複した状態)。
- 根拠: 4箇所を grep で特定し、実装が完全に同一であることを確認。
- 提案: `mixin MistakeTracker { var mistakes = 0; bool get failed => ...; void continueAfterFail() => ...; }` を切り出し、4クラスに `with` させる。
- ステータス: 未対応

## 9. パズル/ちがうのどっち/かぞえての `_choose()` が3画面で同じ骨格をコピペしている
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/screens/count_screen.dart:45-61`, `app/lib/screens/odd_one_screen.dart:45-61`, `app/lib/screens/puzzle_screen.dart:58-85`(パズルはロック/シェイク演出が追加されているのみ)
- 問題: 「正解→sfx.happy→finishedなら400ms Timer待って`finishMinigame`+`_ended=true`/不正解→sfx.wrong→`_game.failed`なら`failGame()`」という骨格が3画面で同一。指摘8と根は同じで、`MistakeGameOverMixin` が「ゲームオーバー後」の配線しか吸収できておらず、「正誤判定そのもの」の配線は依然コピペされている。
- 根拠: 3ファイルの `_choose` を読み比べ、分岐構造が同一であることを確認。
- 提案: `MistakeGameOverMixin` に `handleGuess(bool correct, {required bool finished, required int reward})` のようなヘルパーを追加し、3画面から呼ぶ形に寄せる。
- ステータス: 未対応

## 10. `home_screen.dart` の `_bgDecor()` が250行の巨大switchで、テーマごとに同じループを再実装している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/home_screen.dart:546-797`(`_bgDecor`)
- 問題: 11テーマ分の `switch` で、よぞら/ゆき/うちゅう/かざん等が `for (final q in const [...]) _dot(...)` という同じイディオムをテーマごとに再実装しており、座標・色以外はほぼ重複。ファイルサイズ(1000行超)の主な要因の一つ。
- 根拠: 該当範囲を実読(直接執筆したコードでもあり、パターンの重複を確認)。
- 提案: テーマごとの座標・色を `List<(double,double,double,Color)>` のデータテーブルにまとめ、共通ループで描画する。挙動を変えない純粋な抽出のみ。
- ステータス: 未対応

## 11. `creature_painter.dart` のめがね系アイテム8種が「2つの図形+橋渡し線」を毎回手書きしている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/creature_painter.dart:413`(glasses),`418`(sunglass),`557`(heartglass),`566`(starglass),`575`(groucho),`596`(monocle),`818`(goggles),`907`(rainbowglass)
- 問題: `(112,150)`/`(188,150)` を中心にした左右の図形+橋渡し線、という同じ構造を8ケースが個別に描画している。`monocle` のように意図的に片目だけのケースもあり、流し読みでは気づきにくい。
- 根拠: 8ケースを実読し、座標・構造が共通していることを確認。
- 提案: 必須ではないが、`_drawEyewear(canvas, {leftEye, rightEye, bridgeColor})` のような小さなヘルパーで橋渡し線部分だけでも共通化すると重複が減る。優先度は低い(挙動に影響なし・アイテム追加のたびに触る箇所でもない)。
- ステータス: 未対応

## 12. `sound_synth.dart` の `_victoryTuneTones()` が `_megaFanfareTones()` のローカル `chord()` ヘルパーを再実装している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/audio/sound_synth.dart:363-367`(`chord()` はこの関数内のローカル関数)、`_victoryTuneTones()` 内の和音生成ループ
- 問題: `chord(freqs, at, dur, vol)` は `_megaFanfareTones()` 内のローカル関数として定義され2回使われているが、同じ「和音=複数周波数に同じ `_Tone` を追加する」処理を `_victoryTuneTones()` は独自の `for` ループで再実装している。BGMトラック群は既に共通の `_song()` ヘルパーを使っており、良い前例がある。
- 根拠: 両関数を実読して比較。
- 提案: `chord()` をトップレベル関数に昇格し、`_victoryTuneTones()` からも呼ぶ。
- ステータス: 未対応

## 13. `trace_screen.dart` だけキャンセルできない `Future.delayed` を使っている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/trace_screen.dart:39`(`_judge()`)
- 問題: 他の全ミニゲーム画面(count/odd_one/puzzle/memory/simon)は `Timer` を `_timers` リストで管理し `dispose()` でキャンセルするパターンに統一されているが、`_judge()` だけ生の `Future.delayed` を使っている。`if (!mounted) return` で守られてはいるため今はクラッシュしないが、パターンが不統一で今後の変更で崩れやすい。
- 根拠: 該当コードと他画面の `dispose()` パターンを比較。
- 提案: `Timer` に置き換え、`dispose()` でキャンセルする(現状 `trace_screen.dart` に `dispose()` オーバーライド自体が無い)。
- ステータス: 未対応

## 14. なまえの10文字トリムがサロゲートペアを分割する可能性がある
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/logic/game_controller.dart:294`(`rename()` 内の `t.substring(0, 10)`)
- 問題: `substring` はUTF-16コード単位で切るため、10文字目が絵文字(サロゲートペア)だと片方だけ切り取られ、不正な文字列になる可能性がある。
- 根拠: 該当行を実読。発生頻度は低い(絵文字がちょうど境界に来る入力が必要)。
- 提案: 優先度は低いが、気になる場合は `characters` パッケージ等で書記素単位のトリムに置き換える。
- ステータス: 未対応

## 15. 「あそぶ」「おえかき」ボタンの連打ガードが無い
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/home_screen.dart:334`(`_onPlayPressed`),`363`(`_onPaintPressed`)
- 問題: どちらも `async` でモーダル→画面遷移を行うが、連打ガードが無いため理論上は連続タップで画面が二重に積まれる可能性がある。
- 根拠: 該当メソッドを実読。子ども向けアプリで実際に踏む可能性は低いが、モーダルが挟まるため実害は限定的。
- 提案: 優先度は低い。気になる場合は `bool _navigating` のようなガードを追加する。
- ステータス: 未対応

## 16. `GameController._commit()` の保存が fire-and-forget で、失敗しても検知できない
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/logic/game_controller.dart:408-411`(`_commit`)
- 問題: `_store.save(state)` の `Future` を await も `catchError` もしていない。`SharedPreferences` の書き込みが失敗した場合、未処理の Future エラーになる。なでなで連打などで `_commit()` が高頻度に呼ばれても書き込みの順序保証やデバウンスも無い。
- 根拠: 該当コードと `SaveStore.save()` を実読。
- 提案: 優先度は低い(実運用でほぼ失敗しない書き込み)。気になる場合はエラーログの追加、あるいは高頻度呼び出しのデバウンスを検討。
- ステータス: 未対応

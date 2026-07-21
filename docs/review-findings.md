# コードレビュー指摘一覧

最終レビュー: 2026-07-21 / 対象: app/lib 配下 全体(models/logic/data/screens/widgets/audio)+ pubspec / analysis_options / テストカバレッジ

自動チェックは事前にクリーン(`dart format --set-exit-if-changed .` 差分なし、`flutter analyze` 指摘なし、`flutter test` 184件全パス)。以下は手動の2パスレビュー(正しさ→品質)で見つけ、実際のコードを読んで裏取りした指摘のみ。

#1〜#16 は 2026-07-20 の初回レビュー、#17〜#42 は 2026-07-21 の第2ラウンド(いずれも全件対応済み)。#43 以降は 2026-07-21 の第3ラウンド(第2ラウンドの修正で入った変更の検証を重点)で追加。

## 1. 壊れたセーブデータで名簿エントリが1件でも読めないと、全セーブデータが失われる
- 重大度: 高
- 種別: バグ
- 場所: `app/lib/data/save_store.dart:24-27`, `app/lib/models/game_state.dart:225`
- 問題: `SaveStore.load()` は `loadJson()` 全体を1つの `try/catch` で囲んでいる。`loadJson()` 内の名簿(roster)復元は `int.parse(e.key as String)` を素通しで呼んでおり、名簿のキーが1つでも不正だと例外を投げる。その例外は `load()` の catch で握りつぶされ、**コイン・図鑑・所持アイテムを含む保存データ全体が初期状態に巻き戻る**。
- 根拠: 該当コードを実読。`loadJson()` の他フィールド(hunger/happy/xp等)はデフォルト値へのフォールバックがあるが、roster の `int.parse` だけは無防備。
- 提案: roster の各エントリを個別に try/catch し、壊れたエントリだけスキップする(他のフィールドは復元を継続)。
- ステータス: 対応済み(roster を1件ずつ try/catch でパースし、壊れたエントリだけスキップするよう変更)

## 2. ミュート中にゲームBGMへ切り替えると、後で解除しても音が鳴らなくなる
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/audio/sfx_player.dart:87`(`playOverrideBgm`)、`:145-152`(`syncBgm`)
- 問題: `playOverrideBgm()` は `enabled()` (ミュート判定) のチェック**前**に `_bgmStarted = true` を無条件でセットしている(87行目)。ミュート中にミニゲームへ入る(`home_screen.dart` の `_onPlayPressed` が `playOverrideBgm(Sfx.bgmGame)` を呼ぶ)→ `.play()` はスキップされるが `_bgmStarted` は true のまま → あとでミュート解除(`toggleSound()` → `syncBgm()`)すると `_bgmStarted` が true なので `player.resume()` が呼ばれるが、`_bgm` にはまだ音源がセットされていない → 何も鳴らず、例外は catch で握りつぶされる。
- 根拠: `syncBgm()`(140-160行目)は同じロジックを `if (enabled())` の中でのみ `_bgmStarted = true` にしており、対称性が崩れていることを確認。
- 提案: `playOverrideBgm()` でも `_bgmStarted = true` を `if (enabled())` ブロックの中に移動する。
- ステータス: 対応済み(stop() 直後に _bgmStarted=false、再生成功時のみ true に戻すよう修正)

## 3. 端末の時計が巻き戻ると、オフライン減衰で hunger/happy が100を超えて張り付く
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/models/game_state.dart:162-168`(`applyOfflineDecay`)
- 問題: `mins = (now - lastSavedMs) / 60000.0` が負(時計を戻した・NTP補正等)になると、`min(50, mins/3)` は負値をそのまま返し、`hunger - (負値)` で **hunger/happy が増加**する。`max(15, ...)` はあるが上限クランプが無いため、理論上100を大きく超えたまま張り付く。
- 根拠: 該当コードを実読。`decayTick()` 側も `max(0, ...)` のみで上限クランプが無く、一度超過すると自然には戻らない。
- 提案: `mins` を `max(0, mins)` にする、かつ `hunger`/`happy` の代入結果を `.clamp(0, 100)` する。
- ステータス: 対応済み(mins を0以上にクランプし、結果も0〜100にクランプ)

## 4. `loadJson` が復元値を一切クランプしない(あいことば経由の `loadCode` は行っている)
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/models/game_state.dart:199-224`(`loadJson`)
- 問題: `loadCode()` は stage/xp/hunger/happy/species を範囲内にクランプするが、`loadJson()`(通常のセーブ復元)は同じフィールドを無条件に信頼する。指摘3のバグと組み合わさると、一度壊れた値が通常のセーブ/ロードを通じて永続化され続ける。
- 根拠: 両メソッドを読み比べて確認。
- 提案: `loadJson()` でも hunger/happy/xp/coins/stage を同様にクランプする。
- ステータス: 対応済み(loadCode と同様のクランプを loadJson にも追加)

## 5. おえかき画面で `ui.Image` が dispose されず、繰り返すほどネイティブメモリが漏れる
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/screens/paint_screen.dart:101,113,219,238`(`_baseImage` の代入箇所)、State クラスに `dispose()` オーバーライドが存在しない
- 問題: `_baseImage`(`decodeImageFromList`/`ui.decodeImageFromPixels` で生成される `dart:ui` の `Image`)は、バケツぬりつぶしのたびに古い参照を破棄せず新しいインスタンスで上書きされる(219行目)。`_clear()` でも同様(238行目)。画面を閉じるときに最後の1枚を解放する `dispose()` も無い。`ui.Image` はネイティブ/GPU側のメモリを保持するため、繰り返すほど解放されないバッファが積み上がる。
- 根拠: 該当コードを実読し、`State<PaintScreen>` に `dispose()` オーバーライドが無いことを grep で確認。
- 提案: 代入前に `_baseImage?.dispose()` を呼ぶ。`dispose()` オーバーライドを追加し、最後の `_baseImage` を解放する。
- ステータス: 対応済み(_setBaseImage() で差し替え前に dispose、State に dispose() を追加)

## 6. もぐらたたきの種族数がハードコードされ、種族追加時に無言で壊れる
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:297`(`WhackMole(..., speciesIndex: _rng.nextInt(15), ...)`)
- 問題: `minigames.dart` は `species.dart` を import しておらず、`15` は `speciesList.length` と現状たまたま一致しているだけ。種族は「末尾に追加する」運用(このセッションだけで何度も種族を追加している)なので、次に追加したときコンパイルエラーにならないまま新種族がもぐらたたきに出現しなくなる。
- 根拠: `speciesList` の実データを数え15件であることを確認。`minigames.dart` に `species.dart` の import が無いことも確認。
- 提案: `WhackGame` にコンストラクタ引数で `speciesCount` を渡す(呼び出し側で `speciesList.length` を渡す)。
- ステータス: 対応済み(speciesCount パラメータ追加、既定値は speciesList.length)

## 7. フルーツキャッチ/ふうせんわり/もぐらたたきの画面が、ほぼ丸ごと重複している
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/screens/catch_screen.dart:28-70`, `app/lib/screens/balloon_screen.dart:28-70`, `app/lib/screens/whack_screen.dart:29-63`
- 問題: `_Phase` enum・State フィールド(`_phase`/`_game`/`_ticker`/`_lastTick`等)・`dispose()`・`_start()`・`_onTick()` の骨格が、ゲーム型名以外ほぼ同一(`diff` でほぼ差分なしを確認)。もぐらたたきは `RenderBox` 取得の有無など既にわずかにドリフトしている。
- 根拠: `diff <(catch_screen.dart) <(balloon_screen.dart)` の該当範囲を実行し、型名以外の差分がほぼ無いことを確認。
- 提案: 「時間制で降下/上昇するアイテムをタップする」共通の土台(mixin または汎用 State クラス)を切り出す。今回の `MistakeGameOverMixin` と同じ発想。
- ステータス: 対応済み(TimedArcadeGameMixin を切り出し3画面に適用。balloon/whackの画面テストも新規追加)

## 8. `failed`/`continueAfterFail` が4クラスへ一字一句コピペされている
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:142,176`(`PuzzleGame`)/`350,381`(`OddOneGame`)/`482,501`(`OrderGame`)/`535,567`(`CountGame`)
- 問題: `bool get failed => mistakes >= minigameMaxMistakes;` と `void continueAfterFail() => mistakes = 0;` が4クラスに同一実装でコピペされている(直前のセッションで追加した機能がそのまま重複した状態)。
- 根拠: 4箇所を grep で特定し、実装が完全に同一であることを確認。
- 提案: `mixin MistakeTracker { var mistakes = 0; bool get failed => ...; void continueAfterFail() => ...; }` を切り出し、4クラスに `with` させる。
- ステータス: 対応済み(MistakeTracker mixin を切り出し4クラスに適用)

## 9. パズル/ちがうのどっち/かぞえての `_choose()` が3画面で同じ骨格をコピペしている
- 重大度: 中
- 種別: リファクタ
- 場所: `app/lib/screens/count_screen.dart:45-61`, `app/lib/screens/odd_one_screen.dart:45-61`, `app/lib/screens/puzzle_screen.dart:58-85`(パズルはロック/シェイク演出が追加されているのみ)
- 問題: 「正解→sfx.happy→finishedなら400ms Timer待って`finishMinigame`+`_ended=true`/不正解→sfx.wrong→`_game.failed`なら`failGame()`」という骨格が3画面で同一。指摘8と根は同じで、`MistakeGameOverMixin` が「ゲームオーバー後」の配線しか吸収できておらず、「正誤判定そのもの」の配線は依然コピペされている。
- 根拠: 3ファイルの `_choose` を読み比べ、分岐構造が同一であることを確認。
- 提案: `MistakeGameOverMixin` に `handleGuess(bool correct, {required bool finished, required int reward})` のようなヘルパーを追加し、3画面から呼ぶ形に寄せる。
- ステータス: 対応済み(count/odd_one は handleGuess() に統一。puzzle はロック/シェイク演出のため意図的に据え置き)

## 10. `home_screen.dart` の `_bgDecor()` が250行の巨大switchで、テーマごとに同じループを再実装している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/home_screen.dart:546-797`(`_bgDecor`)
- 問題: 11テーマ分の `switch` で、よぞら/ゆき/うちゅう/かざん等が `for (final q in const [...]) _dot(...)` という同じイディオムをテーマごとに再実装しており、座標・色以外はほぼ重複。ファイルサイズ(1000行超)の主な要因の一つ。
- 根拠: 該当範囲を実読(直接執筆したコードでもあり、パターンの重複を確認)。
- 提案: テーマごとの座標・色を `List<(double,double,double,Color)>` のデータテーブルにまとめ、共通ループで描画する。挙動を変えない純粋な抽出のみ。
- ステータス: 対応済み(範囲を縮小: umi のバブルループのみ共有の _dot() を再利用。他10テーマは実際にはテーマ固有の装飾でありデータテーブル化の価値が低いと判断し据え置き)

## 11. `creature_painter.dart` のめがね系アイテム8種が「2つの図形+橋渡し線」を毎回手書きしている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/creature_painter.dart:413`(glasses),`418`(sunglass),`557`(heartglass),`566`(starglass),`575`(groucho),`596`(monocle),`818`(goggles),`907`(rainbowglass)
- 問題: `(112,150)`/`(188,150)` を中心にした左右の図形+橋渡し線、という同じ構造を8ケースが個別に描画している。`monocle` のように意図的に片目だけのケースもあり、流し読みでは気づきにくい。
- 根拠: 8ケースを実読し、座標・構造が共通していることを確認。
- 提案: 必須ではないが、`_drawEyewear(canvas, {leftEye, rightEye, bridgeColor})` のような小さなヘルパーで橋渡し線部分だけでも共通化すると重複が減る。優先度は低い(挙動に影響なし・アイテム追加のたびに触る箇所でもない)。
- ステータス: 対応済み(_eyeBridge() ヘルパーを追加し5ケースに適用。あわせて腕/足の描画もループ形式に統一)

## 12. `sound_synth.dart` の `_victoryTuneTones()` が `_megaFanfareTones()` のローカル `chord()` ヘルパーを再実装している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/audio/sound_synth.dart:363-367`(`chord()` はこの関数内のローカル関数)、`_victoryTuneTones()` 内の和音生成ループ
- 問題: `chord(freqs, at, dur, vol)` は `_megaFanfareTones()` 内のローカル関数として定義され2回使われているが、同じ「和音=複数周波数に同じ `_Tone` を追加する」処理を `_victoryTuneTones()` は独自の `for` ループで再実装している。BGMトラック群は既に共通の `_song()` ヘルパーを使っており、良い前例がある。
- 根拠: 両関数を実読して比較。
- 提案: `chord()` をトップレベル関数に昇格し、`_victoryTuneTones()` からも呼ぶ。
- ステータス: 対応済み(_addChord() をトップレベルに昇格し両関数から呼ぶよう変更)

## 13. `trace_screen.dart` だけキャンセルできない `Future.delayed` を使っている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/trace_screen.dart:39`(`_judge()`)
- 問題: 他の全ミニゲーム画面(count/odd_one/puzzle/memory/simon)は `Timer` を `_timers` リストで管理し `dispose()` でキャンセルするパターンに統一されているが、`_judge()` だけ生の `Future.delayed` を使っている。`if (!mounted) return` で守られてはいるため今はクラッシュしないが、パターンが不統一で今後の変更で崩れやすい。
- 根拠: 該当コードと他画面の `dispose()` パターンを比較。
- 提案: `Timer` に置き換え、`dispose()` でキャンセルする(現状 `trace_screen.dart` に `dispose()` オーバーライド自体が無い)。
- ステータス: 対応済み(Timer化+dispose()追加。画面テストが無かったので新規追加)

## 14. なまえの10文字トリムがサロゲートペアを分割する可能性がある
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/logic/game_controller.dart:294`(`rename()` 内の `t.substring(0, 10)`)
- 問題: `substring` はUTF-16コード単位で切るため、10文字目が絵文字(サロゲートペア)だと片方だけ切り取られ、不正な文字列になる可能性がある。
- 根拠: 該当行を実読。発生頻度は低い(絵文字がちょうど境界に来る入力が必要)。
- 提案: 優先度は低いが、気になる場合は `characters` パッケージ等で書記素単位のトリムに置き換える。
- ステータス: 対応済み(依存追加なしで済むよう String.runes でコードポイント単位にトリムするよう変更)

## 15. 「あそぶ」「おえかき」ボタンの連打ガードが無い
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/home_screen.dart:334`(`_onPlayPressed`),`363`(`_onPaintPressed`)
- 問題: どちらも `async` でモーダル→画面遷移を行うが、連打ガードが無いため理論上は連続タップで画面が二重に積まれる可能性がある。
- 根拠: 該当メソッドを実読。子ども向けアプリで実際に踏む可能性は低いが、モーダルが挟まるため実害は限定的。
- 提案: 優先度は低い。気になる場合は `bool _navigating` のようなガードを追加する。
- ステータス: 対応済み(bool _navigating ガードを追加)

## 16. `GameController._commit()` の保存が fire-and-forget で、失敗しても検知できない
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/logic/game_controller.dart:408-411`(`_commit`)
- 問題: `_store.save(state)` の `Future` を await も `catchError` もしていない。`SharedPreferences` の書き込みが失敗した場合、未処理の Future エラーになる。なでなで連打などで `_commit()` が高頻度に呼ばれても書き込みの順序保証やデバウンスも無い。
- 根拠: 該当コードと `SaveStore.save()` を実読。
- 提案: 優先度は低い(実運用でほぼ失敗しない書き込み)。気になる場合はエラーログの追加、あるいは高頻度呼び出しのデバウンスを検討。
- ステータス: 対応済み(catchError でログ出力するよう変更。デバウンスは見送り)

## 17. `loadJson` が species/bg を無検証で受け入れ、壊れ方次第でセーブ全損またはクラッシュループになる
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/models/game_state.dart:207,216,219`(`loadJson`)、`:57-70`(`CreatureSnapshot.fromJson`)
- 問題: #4 の対応で hunger/happy/xp/coins/stage はクランプされたが、`species = j['species'] ?? 0` と `bg = j['bg']` は範囲外インデックスを素通しする。species 範囲外 + `color` 欠落だと `loadJson` 内の `speciesList[species]` が投げ、`SaveStore.load()` の catch で**セーブ全体が初期化**される(#1 と同型の全損経路)。color があっても範囲外 species は `currentSpecies` 等の参照で起動のたび RangeError(クラッシュループ)、範囲外 bg は `bgThemes[effectiveBg]` で毎フレーム RangeError。`CreatureSnapshot.fromJson` も stage/hunger/happy を一切クランプせず、`switchCreature` 経由で範囲外 stage が `emojis[stage]` に到達する。
- 根拠: 該当コードを実読。`loadCode()` は species を `clamp(0, speciesList.length - 1)` しており非対称。`game_state_test.dart` のクランプテストにも species/bg/snapshot は含まれていない。
- 提案: `loadCode` と同様に species をクランプ、bg は範囲外なら null に落とす。snapshot も stage を `clamp(0, 3)`、hunger/happy を `clamp(0, 100)` する(リグレッションテスト追加)。
- ステータス: 対応済み(loadJson の species をクランプ・bg は `_validBg()` で範囲外を null に。`CreatureSnapshot.fromJson` も stage/xp/hunger/happy/bg を正規化。再現テスト3件を追加)

## 18. ホーム画面の模様画像(`_patternImage`)が差し替え時に dispose されず、おえかき保存のたびにネイティブメモリが漏れる
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/screens/home_screen.dart:129,229-233`(`_syncPattern`)、`:167-173`(`dispose`)
- 問題: `_syncPattern()` は `decodeImageFromList` の結果で `_patternImage` を上書きするとき古い `ui.Image` を dispose せず、`p == null` 分岐の null 代入も同様。`dispose()` にも解放が無い。HomeScreen はアプリ生存期間ずっと生きるため、おえかき保存のたびに確実に漏れる。#5 の修正(paint_screen の `_setBaseImage()`)が home_screen 側に適用されておらず非対称。
- 根拠: 該当コードを実読。`dispose()` はリスナーとタイマーのみ解放している。
- 提案: paint_screen と同じ「差し替え前に旧参照を dispose するヘルパー」を導入し、`dispose()` で最後の1枚も解放する(直前フレームで CreatureView が参照している点に注意)。
- ステータス: 対応済み(`_setPatternImage()` で差し替え前に dispose、`dispose()` で最後の1枚を解放、デコード完了時に画面破棄済み/模様変更済みなら即 dispose。`FlutterMemoryAllocations` で ui.Image の生存数を数える再現テストを新規追加)

## 19. おえかきの「できた!」に再入ガードが無く、連打で `Navigator.pop` が二重に走る
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/screens/paint_screen.dart:244-250`(`_save`)
- 問題: `_save()` は `_renderImage()` + PNG エンコードの await 中(複数フレーム)に再タップされると二重実行され、`pop(true)` が2回呼ばれてホーム画面まで pop され得る(pop アニメーション中は `mounted` が true のため `!mounted` ガードをすり抜ける)。
- 根拠: 同ファイルの `_bucketFill` には `_filling` ガードがあるのに `_save` には無いことを実読で確認。#15(ホームの連打ガード)と同種だが paint_screen は対象外だった。
- 提案: `_saving` フラグで早期 return する。
- ステータス: 対応済み(`_saving` ガードを追加。成功時は画面が閉じるので立てたまま、失敗時のみ戻して再試行可能に。連打で保存1回・pop 1回を固定する widget test を追加)

## 20. コイン不足時の「🪙Nコインで つづける」ボタンが、ラベルと逆の「あきらめる」動作をする
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/widgets/game_overlays.dart:134`(`GameOverOverlay`)
- 問題: `onPressed: canAfford ? onContinue : onGiveUp` のため、コイン不足時に半透明表示の「つづける」ボタンをタップすると警告なしで `onGiveUp`(=報酬なしで画面 pop)が実行される。6〜7歳が対象のアプリで、ラベルと実動作が逆。
- 根拠: `mistake_game_over.dart:33` の `onGiveUp: () => Navigator.of(context).pop()` を実読。プロトタイプに続行機能は無く(Flutter 版で追加)、プロトタイプのコイン不足時の既存パターンは「トースト表示 + no-op」(`mokomon.html:872,1167`)であることを確認。
- 提案: 不足時は `onPressed: null`(または トースト+wrong音)にし、終了は「あきらめる」ボタンだけに限定する。
- ステータス: 対応済み(不足時は `IgnorePointer` でタップ無効化し `onGiveUp` フォールバックを削除。終了は「あきらめる」のみに。コイン不足でタップしても画面が閉じないことを固定する widget test を追加)

## 21. あいことばの所持品ビットが Web ビルド(dart2js)で32bitに折り返し、index 32 以降のアイテムが壊れる
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/models/game_state.dart:246-247`(`makeCode` の ownBits)、`:298-301`(`loadCode`)
- 問題: `ownBits |= 1 << i` / `a[8] & (1 << i)` を `shopItems` 全40件に対して行っているが、dart2js ではビット演算・シフトが32bitに切り詰められるため、index 32 以降の8件は `1 << (i - 32)` に折り返す。Web で生成したあいことばは壊れ、ネイティブで生成したコードを Web で読むと所持品が化ける。種族コレクション(colBits)も32種到達時に同じ罠を踏む(現在15種)。
- 根拠: `items.dart` を実数え(40件)。CLAUDE.md が `-d chrome` を実行ターゲットに挙げている。dart2js のビット演算32bit化は言語仕様の文書化された挙動。
- 提案: あいことば v2 として ownBits を30bit単位の複数フィールドに分割する(`a[0]` にバージョンがあるので互換移行可能)。Web を出荷しない判断ならコードコメントで制約を明記する。
- ステータス: 対応済み(v2 移行は不要と判明: ビット列の組み立て/読み出しを BigInt 化。10進文字列のコード形式は不変で既存あいことばと完全互換、ネイティブ生成の v1 コードも Web で正しく読めるようになる。`flutter test --platform chrome` で実際に32bit折り返しを再現→修正後グリーンを確認、リグレッションテスト追加)

## 22. `SfxPlayer` の BGM 状態機械にテストがゼロで、現構造ではテスト不能
- 重大度: 中
- 種別: 設計
- 場所: `app/lib/audio/sfx_player.dart`(全体、特に `:12-13` の `_isFlutterTest` ガード)
- 問題: `_bgmStarted` / `_overrideTrack` / duck タイマー / ミュート同期という非自明な状態機械を持ち、実際に既知バグ(#2)を出した箇所なのにテストがゼロ。モジュールレベルの `_isFlutterTest` ガードにより flutter test 下では全メソッドが no-op になるため、現構造ではテストを書けない。
- 根拠: `grep "SfxPlayer" test/` ヒットなし。`SoundSynth` 側は polish_test.dart で網羅されているのと対照的。
- 提案: AudioPlayer 生成をコンストラクタ注入にして `_isFlutterTest` ガードを外せるようにし、override→clear→toggle の状態遷移をユニットテストで固定する。
- ステータス: 対応済み(選択肢A/B/Cを提示しユーザーが案A=ファクトリ注入を選択。`playerFactory` を追加し、注入時のみ `_isFlutterTest` ガードをバイパス。FakeAudioPlayer で #2 回帰含む状態遷移4ケースを test/sfx_player_test.dart に固定。既存 widget test は無変更)

## 23. かぞえて/ちがうのどっちで、最終ラウンド正解後の勝利待ち400ms中にタップすると不正解音が鳴る
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/screens/count_screen.dart:35-44`, `app/lib/screens/odd_one_screen.dart:35-44`, `app/lib/screens/mistake_game_over.dart:40-61`(`handleGuess`)
- 問題: `_choose` のガードは `_ended || gameOver` のみで、`_ended` は 400ms 後にしか立たない。その間のタップは `guess()` が `if (finished) return false` で false を返し、`handleGuess` の不正解パスが `Sfx.wrong` を鳴らす(ミス加算は無く実害は音のみ)。全問正解直後にブブー音が鳴るのは子ども向けとして体験が悪い。puzzle_screen は `_locked` で同じ窓を塞いでいる。
- 根拠: 3ファイルの該当コードと `minigames.dart:377,551` の `guess()` を実読。
- 提案: `handleGuess` の正解&finished パスで mixin にロックフラグ(例: `finishing`)を立て、`_choose` 冒頭で見る。
- ステータス: 対応済み(`MistakeGameOverMixin` に `finishing` フラグを追加し、count/odd_one の `_choose` ガードに組み込み。#22 のファクトリ注入を使い「不正解音が実際に鳴らないこと」を両画面の widget test で固定。あわせて `FakeAudioPlayer` を test/helpers.dart へ共有化し、`GameController` に sfx 注入引数を追加)

## 24. おえかきの一時 `ui.Image`(probe/layer/保存時 image)が dispose されない
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/screens/paint_screen.dart:208-217`(`_bucketFill`)、`:245`(`_save`)
- 問題: バケツぬりつぶしのたびに生成される `probe` / `layer` と保存時の `image` が `toByteData` 後に dispose されず GC 任せになり、ネイティブ側バッファの解放が遅れる。#5 は `_baseImage` のみの対応だった。
- 根拠: 該当コードを実読。3箇所とも `dispose()` 呼び出し無し。
- 提案: バイト列取得後に `probe.dispose(); layer.dispose();`、`_save` でも `image.dispose()` を呼ぶ。
- ステータス: 対応済み(probe/layer/保存時 image に加え `_maskBytes` の一時イメージも dispose。#18 と同じ FlutterMemoryAllocations 観測テストで「ぬりつぶし後・保存後は _baseImage の1枚だけ生存、画面破棄でゼロ」を固定。修正前は4枚生存していた)

## 25. なまえ変更ダイアログの `TextEditingController` が dispose されない
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/widgets/rename_dialog.dart:8`
- 問題: `showRenameDialog()` が関数スコープで `TextEditingController` を生成し、誰も dispose しない。ダイアログを開くたびに ChangeNotifier が未破棄で残る。
- 根拠: 同種の `code_dialog.dart` は StatefulWidget 化して `dispose()` で解放しており、パターンが不統一であることを実読で確認。
- 提案: code_dialog と同様に State を持つボディに変えて dispose する(実害は小さいがパターン統一の意味が大きい)。
- ステータス: 対応済み(code_dialog と同型の `_RenameDialogBody`(StatefulWidget)に変換し State が dispose。FlutterMemoryAllocations で TextEditingController の破棄を検証するテストを追加)

## 26. パズル/ちがうのどっち/かぞえての `guess()` 本体が3クラスに同型コピペされている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:172-182`(`PuzzleGame.guess`)、`:377-387`(`OddOneGame.guess`)、`:551-561`(`CountGame.guess`)
- 問題: 「finished なら false → 不正解なら mistakes++ → reward += X → round++ → 未終了なら `_newRound()`」の骨格が3クラスで同一(三度目の法則)。#8/#9 は failed/画面側のみの対応で、`guess()` 本体は未対応だった。
- 根拠: 3メソッドを読み比べ、報酬定数とラウンド生成以外が同一であることを確認。
- 提案: `MistakeTracker` を拡張して共通実装に寄せる(round/reward/`_newRound` をフックで渡す)。
- ステータス: 対応済み(`RoundGuessGame` mixin を新設し round/reward/finished/採点処理を共通化。3クラスの `guess()` は正誤判定1行のみに。既存テスト全パスで挙動保存を確認)

## 27. 時間制3ゲームのカウントダウン骨格(`timeLeft`/`_timerAcc`/`speedFactor`)がロジック側で三重化している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:60-79`(CatchGame)、`:274-291`(WhackGame)、`:425-439`(BalloonGame)
- 問題: 「`_timerAcc += dt; >= 1 で timeLeft--`」の1秒カウントダウンと `speedFactor` 加速式が3クラスに同型で存在する。画面側は #7 で `TimedArcadeGameMixin` に統合済みだが、ロジック側は未統合。
- 根拠: grep + 実読で3クラスの該当コードが定数(制限時間・加速係数)以外同一であることを確認。
- 提案: `mixin CountdownGame` のような小さな共通 mixin に集約する。
- ステータス: 対応済み(`CountdownGame` mixin を新設し timeLeft/_timerAcc/finished/speedFactor/1秒tickを共通化。各ゲームは durationSec と加速増分 accel のみ持つ。既存テスト全パスで挙動保存を確認)

## 28. 時間制3画面の build 側オーバーレイ3点セット(カウントダウン/開始/終了)がコピペのまま
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/catch_screen.dart:106-122`, `app/lib/screens/balloon_screen.dart:111-127`, `app/lib/screens/whack_screen.dart:109-125`
- 問題: #7 で Ticker/フェーズは mixin 化されたが、「countdown → `GameCountdown` / intro → `GameStartOverlay` / ended → `GameEndOverlay('+${score} コイン げっと!')`」の3点セットはタイトル・説明文以外一字一句同一のまま3画面に残っている。
- 根拠: 3ファイルの該当ブロックを読み比べて確認。
- 提案: `TimedArcadeGameMixin` に `buildArcadeOverlays({required String title, required String desc})` のようなヘルパーを足す。
- ステータス: 対応済み(提案どおり `buildArcadeOverlays()` を mixin に追加し、3画面はタイトル・説明文を渡して spread するだけに。timed_arcade_screens_test / minigame_screens_test の既存テストが3画面のオーバーレイフローを固定済みで、全パスにより挙動保存を確認)

## 29. `TimerBagMixin` の発火済み Timer がリストから除去されず、常駐する HomeScreen で伸び続ける
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/timer_bag.dart:18-23`(`later`)
- 問題: `later()` は `_timers.add(...)` のみで削除パスが無い。短命なミニゲーム画面では無害だが、アプリ生存期間ずっと生きる HomeScreen も同 mixin を使い、ごはん・進化チェック等のたびに `later()` を呼ぶため、発火済み Timer の参照が無制限に溜まる。
- 根拠: mixin 実装と `home_screen.dart:141,144,211,455` の呼び出しを実読。
- 提案: コールバック実行時に自分自身を `_timers` から remove する。
- ステータス: 対応済み(発火時に自身をリストから remove。`@visibleForTesting` の `pendingTimers` を追加し、発火後にゼロへ戻ること・dispose でキャンセルされることを test/timer_bag_test.dart で固定)

## 30. `creature_painter.dart` の `_paintItem` 40ケース580行 switch がファイルの6割を占める
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/creature_painter.dart:335-914`(`_paintItem` + アイテム用ヘルパー)
- 問題: 969行のうち約620行がきせかえアイテム描画で、体・種族アクセサリ・王冠・きせかえの関心が1ファイルに同居している。顔は既に `creature_faces.dart` へ分離済みという前例があり、アイテム追加のたびにこの巨大ファイルを触ることになる。
- 根拠: 全文実読。`_paintItem` はインスタンス状態(bodyColor/stage 等)を参照しておらず(canvas と key のみ)、そのまま関数として切り出せることを確認。
- 提案: `creature_faces.dart` と同型で `creature_items.dart` にトップレベル関数として抽出する(挙動不変の移動のみ)。
- ステータス: 対応済み(`paintEquipItem()` + アイテム用ヘルパー(_eyeBridge/_star/_heart)を `creature_items.dart`(630行)へ移動。creature_painter.dart は 969→349行に。全アイテムを描画する render_preview_test 含め全テストパスで挙動保存を確認)

## 31. ゲームオーバーレイのグレー二次ボタンとスクリム骨格が3重複している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/game_overlays.dart:45-58,146-159`、`app/lib/widgets/ui_kit.dart:155-178`(`ModalCloseButton`)
- 問題: 「もどる」「あきらめる」の `TextButton.styleFrom(backgroundColor: fieldGray, ...)` + 同一 TextStyle が一字一句同一でコピペされ、`ModalCloseButton` が同じ見た目の3つ目の実装(Material+InkWell 版)。さらに白スクリム+中央 Column の骨格が GameStart/GameEnd/GameOver の3クラスで重複。
- 根拠: 3箇所を実読・grep で確認。
- 提案: グレーボタンは `ModalCloseButton` に統一(または共通ウィジェット化)、スクリムは小さな共通ウィジェットに抽出する。
- ステータス: 対応済み(`_OverlayScrim` と `_GrayButton` を game_overlays.dart 内に抽出し3オーバーレイへ適用。`ModalCloseButton` への統一は余白が異なり見た目が変わるため見送り、理由をコメントに明記。既存テスト全パスで挙動保存を確認)

## 32. π が手書きリテラル(3.14159 / 3.14159265)で13箇所に散布されている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/creature_painter.dart:127,340,514,762,797,933`、`app/lib/widgets/creature_faces.dart:172,254,450,452,497,499` ほか
- 問題: `dart:math` の `pi` を使わず精度の違う2種類のリテラルが混在。creature_view / evolution_overlay は正しく `pi` を使っており、同ディレクトリ内で不統一。
- 根拠: grep で widgets/ 配下13箇所を確認。creature_painter は `dart:math` import 済み。
- 提案: 全箇所を `pi` に置換する(挙動不変)。
- ステータス: 対応済み(lib 配下の 3.14159/3.14159265 全13箇所を `dart:math` の `pi` に置換。#30 の分割で一部は creature_items.dart 側での置換になった。角度差は最大1e-8ラジアンで描画結果への影響なし、全テストパス)

## 33. 金色種族のインデックスが2画面でマジックナンバー `3` のまま
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/whack_screen.dart:150`(`mole.golden ? 3 : ...`)、`app/lib/screens/home_screen.dart:425`(`if (sp == 3)`)
- 問題: `data/species.dart:120` に `secretSpeciesIndex = 3` が定義され `game_state.dart` では一貫使用されているのに、screens/ の2箇所だけ生リテラル。種族の並びに関わる前提が散っている。
- 根拠: grep で定数と生リテラルの使用箇所を確認。
- 提案: 両箇所を `secretSpeciesIndex` に置き換える。
- ステータス: 対応済み(両画面に species.dart の import を追加し、生リテラル `3` を `secretSpeciesIndex` に置換。全テストパス)

## 34. `_bgmTones()` だけが共通ヘルパー `_song()` を使わず同一ロジックを手書きしている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/audio/sound_synth.dart:500-525`(`_bgmTones`)
- 問題: 他の BGM 5曲はすべて `_song()` を使うが、`_bgmTones()` だけ同一ロジック(0=休符スキップ、dur=beat×0.9、ベース配置)を手書きで再実装している。
- 根拠: 実読比較。`_song(melodyBeat: _beat, melodyWave: triangle, melodyVol: 0.045, bassBeat: _beat * 4, bassVol: 0.05)` と出力が完全一致することを確認(bass の dur `_beat*3.6 = (4*_beat)*0.9`)。
- 提案: `_song()` 呼び出しに書き換える(挙動不変)。
- ステータス: 対応済み(`_song(bassBeat: _beat * 4)` 呼び出しに置換。リファクタ前後で生成WAVのバイト長・ハッシュが完全一致することを確認済み)

## 35. WAV 再生秒数の計算式がマジックナンバー(44バイト/22050Hz)ごと2箇所にコピペされている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/audio/sfx_player.dart:67,98`、`app/lib/audio/sound_synth.dart:527`(`_sampleRate`)
- 問題: `(length - 44) / 2 / 22050` が2箇所に重複し、`_sampleRate` が private のため数値がハードコードされている。サンプルレート変更時にジングル復帰・override 解除のタイマーが無言でずれる。
- 根拠: grep で3箇所(定数1+式2)を確認。
- 提案: `SoundSynth` に `Duration durationFor(Sfx)` を公開して2箇所から呼ぶ。
- ステータス: 対応済み(`durationFor()` を追加し `_sampleRate` 定数を参照。playJingle/playOverrideBgm の手計算2箇所を置換し、wav長との一致テストを追加)

## 36. `Sfx.coo` / `Sfx.giggle` がどこからも再生されないデッドコード
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/audio/sound_synth.dart:17-18,97-106`(enum 値とレシピ)、`:5`(doc コメント)
- 問題: なでなでの鳴き声は `playBabble()`(種族別)に置き換わっており、`Sfx.coo` / `Sfx.giggle` は lib 全体でどこからも再生されていない。enum の doc コメントも現状と矛盾した説明のまま。
- 根拠: `grep -rn "Sfx.coo\|Sfx.giggle" lib/` で audio 層外の使用ゼロを確認。
- 提案: 2つの enum 値とレシピを削除し、doc コメントを更新する(履歴は VCS にある)。
- ステータス: 対応済み(enum 値2つとレシピを削除、enum の doc コメントを現状(babble が鳴き声を担う)に更新。docs/game-design.md §10 の coo/giggle 記載も同時に修正。全テストパス)

## 37. `evolution_overlay.dart` の `_silhouette(dynamic s)` / `_revealCreature(dynamic s)` が型安全を捨てている
- 重大度: 低
- 種別: 設計
- 場所: `app/lib/widgets/evolution_overlay.dart:185,214`
- 問題: 引数は実際には `GameState` なのに `dynamic` 宣言のため、`s.species` 等のタイポがコンパイル時に検出されない。プロジェクトの型安全重視原則に反する。
- 根拠: 両メソッドと呼び出し箇所を実読。`models/game_state.dart` の import を足せば済む。
- 提案: import を追加して `GameState s` に変更する。
- ステータス: 対応済み(ユーザー承認のうえ `GameState` 型に変更、import 追加。analyze/全テストパス)

## 38. 「hunger≧98 は給餌不可」ルールが UI 層でしか強制されていない
- 重大度: 低
- 種別: 設計
- 場所: `app/lib/logic/game_controller.dart:133,136-146`(`isFull` / `feed`)
- 問題: `isFull` getter が定義されているのに `feed()` 自身は検査せず、強制は `home_screen.dart:324` のみ。ユースケース層でルールが強制されておらず、新しい呼び出し口が満腹制限を素通りできる。
- 根拠: `feed()` 実装と grep(`isFull` の使用は home_screen のみ)で確認。
- 提案: `feed()` 冒頭で `if (isFull) return false;` を追加し、UI 側チェックは表示用に残す。
- ステータス: 対応済み(ユーザー承認のうえ提案どおり実装。満腹時に state が一切変化しないことをテストで固定。UI 側の isFull チェック(ヒント表示)は据え置き)

## 39. analyzer の strict モードが未設定で、型安全重視原則と乖離している
- 重大度: 低
- 種別: 設計
- 場所: `app/analysis_options.yaml:1-5`
- 問題: `strict-casts` / `strict-inference` / `strict-raw-types` が未設定(flutter_lints include + `prefer_single_quotes` のみ)。CLAUDE.md の「言語が提供する最も厳格な型チェックを使う」原則に対して緩い。#37 のような `dynamic` の混入を機械検出できない。
- 根拠: ファイル全文を実読。
- 提案: `analyzer: language:` ブロックで3フラグを有効化し、出た指摘を解消する。
- ステータス: 対応済み(ユーザー承認のうえ3フラグを有効化。出た21件はすべて JSON 境界の暗黙 dynamic(save_store/game_state)と MaterialPageRoute の型引数省略で、明示キャスト・型引数を付けて解消。analyze クリーン・全テストパス)

## 40. `flutter_lints` がメジャー1つ遅れ(^5.0.0 → 6.x)
- 重大度: 低
- 種別: リファクタ
- 場所: `app/pubspec.yaml:18`
- 問題: dev 依存の `flutter_lints` が最新メジャーから1つ遅れ。CLAUDE.md「リポジトリを古いまま放置しない」方針に該当。direct 依存(shared_preferences / audioplayers)は最新であることを確認済み。
- 根拠: `flutter pub outdated` を実行して確認。
- 提案: `^6.0.0` へ更新し、新規 lint 指摘の解消とセットで1コミットにする。
- ステータス: 対応済み(`^6.0.0` へ更新、flutter_lints/lints とも 6.0.0 に解決。新規 lint 指摘はゼロ(#39 の strict 化を先に済ませていたため)。analyze クリーン・全テストパス)

## 41. `PuzzleGame` の doc コメントがミス制導入前の記述のまま実装と矛盾している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:141`
- 問題: 「不正解ペナルティなし(再挑戦可)」と書いているが、実装は `MistakeTracker` により3ミスでゲームオーバー。コードと矛盾するドキュメントは修正する原則に該当。
- 根拠: コメントと `finished` / `mistakes++` の実装を突き合わせて確認。
- 提案: 「不正解はミス+1、3ミスでゲームオーバー(コインで続行可)」に更新する。
- ステータス: 対応済み(minigames.dart のクラスコメントに加え、同じ矛盾が残っていた puzzle_screen.dart:15 と docs/game-design.md の「ペナルティなし」2箇所(パズル/かぞえて)もまとめて現状に更新)

## 42. `MemoryScreen` の doc コメントが「3×4=6ペア」のままで実装(4×5=10ペア)と矛盾している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/memory_screen.dart:12`
- 問題: 実装と仕様(game-design.md「4×5=20枚(10ペア)」)は10ペアだが、コメントが増量前の記述のまま。
- 根拠: `memoryEmoji` 10種(minigames.dart)と grid 実装、仕様書を突き合わせて確認。
- 提案: コメントを「4×5=10ペア」に修正する。
- ステータス: 対応済み(「4×5=10ペア(こどもFBで増量)」に更新)

## 43. セーブ由来の `pattern`(base64 PNG)が無検証で、壊れているとホーム/おえかきが起動のたびにクラッシュする
- 重大度: 中
- 種別: バグ
- 場所: `app/lib/screens/home_screen.dart:230-231`(`_syncPattern`)、`app/lib/screens/paint_screen.dart:113`(`initState`)、`app/lib/models/game_state.dart:228`(`loadJson` の pattern 素通し)
- 問題: #17 で species/bg は境界で正規化されたが、`pattern` は `as String?` の素通しのまま。不正な base64 だと `base64Decode(p)` が**同期的に** FormatException を投げ、`initState` 経由なので起動のたびに例外(クラッシュループ)。base64 として正しいが PNG として壊れている場合は `decodeImageFromList(...).then(...)` に onError が無く未処理の非同期例外になる。
- 根拠: 両画面のデコード経路と `loadJson` を実読。既存テスト(home_pattern_image_test)は正常な PNG のみ。
- 提案: 「パースは境界で」原則どおり `loadJson` で base64 検証し不正なら null に落とす。加えて両画面のデコードを try/catch + onError で包み、失敗時は模様なしにフォールバック(壊れた pattern のリグレッションテスト追加)。
- ステータス: 対応済み(`_validPattern()` を追加し loadJson / fromJson の両境界で検証、不正 base64 は null に。両画面のデコードにも catchError を追加し「base64 は正しいが PNG として壊れている」場合は模様なしにフォールバック。再現テスト3件追加。既存の roundtrip テストのフィクスチャ 'abc' は不正 base64 だったため正しい base64 に更新)

## 44. `home_pattern_image_test` が固定50msの実時間待ちでデコード完了を仮定しており、CI でフレークし得る
- 重大度: 中
- 種別: リファクタ
- 場所: `app/test/home_pattern_image_test.dart:55,62,74`
- 問題: `runAsync(() => Future.delayed(50ms))` 一発で `decodeImageFromList` の完了を仮定している。負荷の高いCIで50msを超えると `expect(live.length, 1)` が落ちる。既存テスト群(collection_flows ほか)は「最大20回×50msのポーリング」パターンを確立しており、この新規テストだけが弱い形。
- 根拠: 両ファイルの該当箇所を実読・比較。
- 提案: 既存と同じポーリング形式(条件は live 集合の状態)に揃える。
- ステータス: 対応済み(waitFor ヘルパー(最大40回×50msのポーリング)に置換し、差し替え検証は「旧イメージが集合から消えたこと」を条件に。3回連続実行で安定を確認)

## 45. おえかき `_save()` の `_saving` ガードが例外パスで戻らず、ボタンが永久に無反応になり得る
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/screens/paint_screen.dart:249-263`(`_save`)
- 問題: #19 で追加した `_saving` ガードに try/finally が無く、`_renderImage()` / `toByteData()` が例外を投げるとフラグが true のまま残り、「できた!」が以後無反応になる。同ファイルの `_bucketFill` は `_filling` を try/finally で守っており非対称。
- 根拠: 両メソッドを読み比べて確認。
- 提案: try/finally 化する(成功して pop した場合のみ立てたままにする)。
- ステータス: 対応済み(`popped` フラグ+try/finally で「pop 成功時のみ立てたまま、それ以外は必ず戻す」構造に。例外の注入にはテスト専用シームが必要で過剰なため再現テストは無し — #19 の連打テストが成功経路の semantics を担保し、例外経路は `_bucketFill` と対称の構造で保証)

## 46. ぬりつぶし完了前に画面を閉じると `newLayer` が dispose されない
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/screens/paint_screen.dart:237-238`(`_bucketFill`)
- 問題: `final newLayer = await completer.future; if (!mounted) return;` の早期 return で、生成済みの `ui.Image` が dispose されず漏れる。#24 の対応(probe/layer/保存時 image)から漏れた経路。`initState` のデコード経路は `!mounted` 時に dispose しており非対称。
- 根拠: 該当2行と initState を実読。
- 提案: `if (!mounted) { newLayer.dispose(); return; }` に変更(観測テストにケース追加)。
- ステータス: 対応済み(提案どおり修正。fill 開始直後に画面を破棄する観測テストを追加 — 修正前は 300×300 のレイヤーが1枚残留することを確認)

## 47. ぬりつぶしの await 中にふで・スタンプ・「ぜんぶけす」を受け付け、完了時に黙って巻き戻す
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/screens/paint_screen.dart:206-247`(`_bucketFill`)、`:139`(`_onPanStart`)、`:265`(`_clear`)
- 問題: `_filling` はバケツの再入だけを防ぎ、fill の複数 await の間に描いたストロークは完了時の `_ops.clear()` で黙って消える。「ぜんぶけす」した場合は消したはずの絵が fill 結果ごと復活し、保存状態(`clearPattern()` 済み)とも不整合になる。
- 根拠: `_onPanStart` / `_clear` に `_filling` チェックが無いこと、`_bucketFill` が終了時に無条件で `_ops.clear()` することを実読で確認。
- 提案: `_filling` 中は `_onPanStart` / `_clear` / `_save` も早期 return する。
- ステータス: 対応済み(提案どおり3箇所にガードを追加。「fill 中の ぜんぶけす で保存済み pattern が消える」経路を再現テストで固定 — 修正前は pattern が null に巻き戻ることを確認)

## 48. `kingSparkle` / `eggTaps` だけが復元時のクランプから漏れている
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/models/game_state.dart:232`(`loadJson`)、`:78`(`fromJson`)、`:215`・`:68`(eggTaps)
- 問題: #4/#17 のクランプ方針から2フィールドだけ漏れている。負の大きい `kingSparkle` はおみやげを実質封印し、100超は次の1タップで即発生。負の `eggTaps` は孵化に必要なタップ数が増える。表示側(StatMeter)はクランプするため画面では気づけない。
- 根拠: 同メソッド内の他フィールドはクランプ済みであること、クランプテストに2フィールドが無いことを確認。
- 提案: `kingSparkle` を `.clamp(0, 100)`、`eggTaps` を `max(0, ...)` に(両メソッド、テスト追加)。
- ステータス: 対応済み(提案どおり loadJson / fromJson の両方をクランプ。範囲外値の素通しを再現するテスト2件を追加してから修正)

## 49. BGM の `play()` 失敗時に `_bgmStarted` が true のまま残り、無音が固定化する(#2 の失敗経路が未修正)
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/audio/sfx_player.dart:100-104`(`playOverrideBgm`)、`:159-163`(`syncBgm`)
- 問題: インラインコメントは「再生に失敗した場合に備えて false にする」と説明しているが、実装は `_bgmStarted = true` を `await play(...)` の**前**に立てている。`play()` が投げると true のまま catch に落ち、以降 `syncBgm()` は音源の無いプレイヤーを `resume()` し続けて無音が固定化する。#2 はミュート経路のみの修正だった。
- 根拠: 両メソッドを実読。sfx_player_test の #2 回帰テストはミュート経路のみ。
- 提案: `_bgmStarted = true` を `play()` 成功後に移す(2箇所)。FakeAudioPlayer に「play が投げるモード」を足して回帰テスト化。
- ステータス: 対応済み(提案どおり2箇所とも成功後に移動し、コメントも実装と一致する記述に更新。FakeAudioPlayer に throwOnPlay を追加し「失敗後の次の同期で resume ではなく play で載せ直す」回帰テストを追加 — 修正前は resume が選ばれることを確認)

## 50. ミニゲームから戻ると勝利曲が途中で切られるが、コメントは「曲側が戻す」と主張している
- 重大度: 低
- 種別: バグ
- 場所: `app/lib/screens/home_screen.dart:369`、`app/lib/audio/sfx_player.dart:118-126`(`clearOverrideBgm`)
- 問題: `// ホームBGMへ戻す(勝利曲中なら曲側が戻す)` というコメントに反し、`clearOverrideBgm()` は非ループの勝利曲(約6.9秒)再生中でも無条件に stop→ホームBGM再生する。ハイスコア(20コイン以上)直後に「もどる」を押すと勝利曲が数秒で切られる。
- 根拠: victoryTune 経路(game_controller)と `_overrideTimer` の予約(sfx_player)を実読。
- 提案: 非ループのオーバーライド再生中(`_overrideTimer` 生存中)はスキップしてタイマーに任せる(evolution_overlay の意図的な切断への影響を確認)、またはコメントを実挙動に合わせる。
- ステータス: 対応済み(前者を採用: `_overrideTimer` 生存中の clear はスキップし自動復帰に任せる。evolution_overlay の dispose も「勝利曲を最後まで流してからホームBGMへ」となり演出意図と整合、タイマー発火時の自己呼び出しは isActive=false のため正常動作。実時間で自動復帰まで検証する回帰テストを追加)

## 51. おうさまのおみやげのお祝いが、ミニゲーム画面の上に被さって出ることがある
- 重大度: 低
- 種別: 設計
- 場所: `app/lib/screens/home_screen.dart:190-206`(`_maybeShowGift`)
- 問題: HomeScreen はミニゲーム中もスタック下で生きて listener が動くため、`finishMinigame` の sparkle+30 でゲージが満タンになると、ゲーム終了オーバーレイの上に「おうさまの おみやげ!」ダイアログが重なる(spin 演出は見えない画面に空振り)。
- 根拠: `_addSparkle` の呼び出し箇所、`takePendingGift()` の消費タイミング、`showDialog` の積まれ先を実読。
- 提案: `ModalRoute.of(context)?.isCurrent != true` の間は消費を遅らせ、ホーム復帰後に受け取る。
- ステータス: 対応済み(ユーザー承認のうえ提案どおり実装: isCurrent ガード+あそぶ/おえかき復帰時に `_maybeShowGift()` を明示呼び出し。「別画面が上にある間は出ず、復帰後に受け取れる」widget test を追加 — 修正前はゲーム画面の上にダイアログが出ることを確認)

## 52. `feed()` の false が「満腹」と「コイン不足」を区別できず、food_sheet が誤メッセージを出す構造
- 重大度: 低
- 種別: 設計
- 場所: `app/lib/logic/game_controller.dart:142-147`(`feed`)、`app/lib/widgets/food_sheet.dart:45-46`
- 問題: #38 のガード追加で false が2つの失敗理由を持つようになったが、food_sheet は false を常に「コインが たりないよ!」と表示する。現状は UI ゲートで到達不能だが、同クラスの `tapShopItem` 等は enum で失敗理由を返しており「判別可能な enum でモデル化」原則と不整合。
- 根拠: 呼び出し経路(home の isFull ゲート)を実読し現状は到達不能であることも確認。
- 提案: `FeedOutcome { fed, full, notEnoughCoins }` を返すよう変更し、food_sheet で分岐する(既存テストの期待値も更新)。
- ステータス: 対応済み(ユーザー承認のうえ提案どおり enum 化。food_sheet は網羅的 switch で分岐し満腹時は専用トースト(ホームのヒントと同文言)。既存テスト3件の期待値を enum に更新してから実装)

## 53. 汎用部品 `StartButton` が celebrate_overlay.dart に同居し、ボタン目的だけの import を生んでいる
- 重大度: 低
- 種別: 設計
- 場所: `app/lib/widgets/celebrate_overlay.dart:101-122`(定義)、`game_overlays.dart:5`・`evolution_overlay.dart:9`(import)
- 問題: 「共通利用」とコメントされた汎用ボタンが、共通部品置き場と明文化された ui_kit.dart ではなくお祝いオーバーレイのファイルにある。game_overlays は celebrate_overlay から StartButton 以外何も使っていない。
- 根拠: grep で使用状況を確認。
- 提案: `StartButton` を ui_kit.dart へ移動(挙動不変の移動のみ)。
- ステータス: 対応済み(ユーザー承認のうえ ui_kit.dart へ移設。game_overlays / evolution_overlay の celebrate_overlay import を除去(evolution は ui_kit import を追加)。全テストパスで挙動保存を確認)

## 54. `sfx_player_test` が今回タイマー計算を変えた2経路(ジングルのダック復帰・非ループ曲の自動復帰)を未カバー
- 重大度: 低
- 種別: 設計
- 場所: `app/test/sfx_player_test.dart`(全体)、`lib/audio/sfx_player.dart:73-82,104-109`
- 問題: #35 で `durationFor()` ベースに書き換えた「ジングル後の `syncBgm` 復帰」「非ループ曲終了で `clearOverrideBgm`」が、注入基盤(#22)で検証可能になったのにテストが無い。`playBabble` / `dispose` も未カバー。
- 根拠: テスト5件と実装を突き合わせ。
- 提案: 仮想時間でタイマー発火を検証する2ケースを追加(#49 の失敗経路テストとセットで)。
- ステータス: 対応済み(ユーザー承認のうえ「ジングルのダック→復帰」「playBabble のバリエーション再生」「dispose の全プレイヤー破棄」の3ケースを追加。非ループ自動復帰は #50、失敗経路は #49 のテストで既にカバー済み。短い音源+実時間待ちで3回連続実行の安定を確認)

## 55. 時間制3画面の「⏰/スコア」StatPill ヘッダ行がコピペのまま
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/screens/catch_screen.dart:93-104`、`balloon_screen.dart:98-108`、`whack_screen.dart:80-86`
- 問題: #28 のオーバーレイ抽出の対象外だったヘッダ行(スコア絵文字以外同一)が3画面に残っている(三度目の法則)。
- 根拠: 3ファイルを読み比べ。
- 提案: `TimedArcadeGameMixin` に `buildScoreHeader(String scoreEmoji)` を足す(挙動不変)。
- ステータス: 対応済み(提案どおり `buildScoreHeader()` を追加(mixin に `gameTimeLeft` getter を新設)。3画面はスコア絵文字を渡す1行に。timed_arcade 系の既存テストが timeLeft/スコア表示を固定しており全パスで挙動保存を確認)

## 56. スポーンタイマーの骨格が時間制3ゲームに同型で残っている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/logic/minigames.dart:121,133-135`(Catch)、`:318,338-340`(Whack)、`:457,468-470`(Balloon)
- 問題: `_spawnT -= dt; if (_spawnT <= 0) { _spawnT = (base + jitter*rng) / speedFactor; …spawn }` が3クラスで同型(#27 のカウントダウン抽出の対象外だった)。差分は基準値・ジッタ幅と whack の同時数上限のみ。
- 根拠: 3箇所を grep+実読で比較。
- 提案: `CountdownGame` にスポーン判定の小ヘルパーを足して3クラスから呼ぶ(挙動不変)。
- ステータス: 対応済み(`spawnDue(dt, rng, base:, jitter:, allowed:)` を mixin に追加し3クラスへ適用。whack の同時数上限は allowed 引数で表現。乱数の消費順を原実装と同一に保ち、シード付きの既存テスト全パスで挙動保存を確認)

## 57. `Species.secret` フィールドが書き込み専用のデッドコード
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/data/species.dart:13,20,48`
- 問題: pika に `secret: true` が設定されているが読み取り箇所がゼロ。判定はすべて `secretSpeciesIndex` 経由(#33 で統一された結果の取り残し)。
- 根拠: grep で使用ゼロを確認。
- 提案: フィールドと設定を削除する。
- ステータス: 対応済み(`secret` フィールドと pika の `secret: true` を削除。判定は従来どおり `secretSpeciesIndex` に一本化。analyze/全テストパス)

## 58. かぼちゃぼうしの円弧角だけ `1.57` / `3.14` のリテラルが残っている
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/creature_items.dart:328-329`
- 問題: #32 は `3.14159` 系を grep して置換したため、短い表記のこの1箇所(π/2 と π)だけ検出されず残った。lib 配下の唯一の残存。
- 根拠: grep で確認。
- 提案: `pi / 2, pi` に置換(描画影響なし)。
- ステータス: 対応済み(提案どおり置換。lib 配下の π 系リテラルは grep で残存ゼロを確認)

## 59. コイン不足トーストの文言が3箇所に同一コピペ
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/shop_sheet.dart:163,239`、`food_sheet.dart:46`
- 問題: `'コインが たりないよ! 「あそぶ」で あつめよう🎮'` が一字一句同一で3箇所(三度目の法則)。文言調整時に同期が必要。
- 根拠: grep で確認。
- 提案: toast.dart に共有ヘルパー/定数を置き3箇所から呼ぶ。
- ステータス: 対応済み(`showNotEnoughCoinsToast()` を toast.dart に追加し3箇所を置換。文言は toast.dart の1箇所のみに。既存のトースト表示テスト含む全テストパス)

## 60. アクセント緑 `Color(0xFF34C98E)` がトークン化されず7箇所に散布
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/book_sheet.dart:171,191`、`shop_sheet.dart:32,153,229`、`code_dialog.dart:113`、`rename_dialog.dart:60`、`game_overlays.dart:284`
- 問題: ui_kit.dart のデザイントークン群に「選択中/アクセント」を示す緑だけ定義が無く、生リテラルが散っている(`greenGradient` 先頭色と同値)。
- 根拠: grep で使用箇所を確認(creature_items 内の2箇所は描画色でありリテラルのままで妥当)。
- 提案: `accentGreen` を ui_kit に追加して意味的に該当する箇所を置換。
- ステータス: 対応済み(`accentGreen` トークンを追加し `greenGradient` もこれを参照。指摘の7箇所に加え、同じ「選択中」の意味だった paint_screen の選択枠2箇所も置換。パレット定義・テーマシード・描画色のリテラルは色データそのものなので据え置き。全テストパス)

## 61. book_sheet.dart だけ自ディレクトリを `../widgets/` 経由で import している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/lib/widgets/book_sheet.dart:6`
- 問題: widgets/ 内から `import '../widgets/creature_painter.dart';` と参照しており、他ファイルの相互 import と不統一。
- 根拠: grep で唯一の該当であることを確認。
- 提案: `import 'creature_painter.dart';` に修正。
- ステータス: 対応済み(修正し、widgets/ 内の `../widgets/` 経由 import が残存ゼロであることを確認)

## 62. テスト足場(pumpScreen / FakeAudioPlayer 組み立て / controller ヘルパー)が複数ファイルに同型コピペ
- 重大度: 低
- 種別: リファクタ
- 場所: `pumpScreen` ×4(count_simon/game_over/timed_arcade/trace の各テスト)、FakeAudioPlayer+created+SfxPlayer 組み立て ×3(sfx_player/count_simon/game_over)、`GameController(GameState()..stage=1, SaveStore())` ローカルヘルパー ×5
- 問題: いずれも3回以上の同型重複(三度目の法則)。特に SfxPlayer 注入の組み立ては #22/#23 対応で3箇所目になった。
- 根拠: grep+実読で確認。
- 提案: helpers.dart に `pumpScreen()` と「記録用 SfxPlayer を作って返す」ヘルパーを追加。
- ステータス: 対応済み(helpers.dart に `pumpScreen()` / `stage1Controller()` / `RecordingSfx` を追加し、pumpScreen×5・stage1コントローラ×5・SfxPlayer組み立て×3 の重複を解消。fresh() 系はファイル固有の形(rng/coins/必須state)が異なるため据え置き。全テストパス・analyze クリーン)

## 63. `pumpAndSettle` が4箇所で使われ「使わない」規約と矛盾している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/test/game_over_screens_test.dart:82,105`、`trace_screen_test.dart:55`、`collection_flows_test.dart:332`
- 問題: CLAUDE.md / docs/frontend.md の規約は固定時間の pump。現状はアニメーションの無い局面なので通るが、対象画面に常時アニメーションを足した瞬間にタイムアウトする地雷。helpers.dart 自身が規約を明記しているのと不整合。
- 根拠: 4箇所を実読(いずれも固定 pump で置換可能)。
- 提案: 固定時間の `pump` に置き換える。
- ステータス: 対応済み(4箇所すべて固定時間の pump に置換(pop 遷移は 400ms×2、画面破棄後は 1秒)。test/ から pumpAndSettle の使用が消え、規約(helpers.dart / docs/frontend.md)と整合。全テストパス)

## 64. #23 回帰テストの `pump(5s)` がジングル種別の閾値(`bigScoreCoins`)に暗黙依存している
- 重大度: 低
- 種別: リファクタ
- 場所: `app/test/count_simon_screens_test.dart:83-84`、`game_over_screens_test.dart:169-170`
- 問題: 現在の報酬(count=18/odd=16 < 20)は rewardJingle 経路(タイマー約1.2秒)なので5秒で足りるが、報酬バランスを変えて `bigScoreCoins` を超えると victoryTune 経路(約7.1秒)になり、「A Timer is still pending」という原因の分かりにくい失敗になる。
- 根拠: 閾値・曲長・pump 合計を突き合わせ。
- 提案: 流す時間を `SoundSynth().durationFor(...) + マージン` から導出する。
- ステータス: 対応済み(helpers.dart に `drainRewardJingle()` を追加 — 最長の victoryTune 実長+1秒の仮想時間を流すため、報酬バランスが bigScoreCoins を跨いでも壊れない。2テストを置換、全テストパス)

## 65. `environment: sdk ^3.5.0` が実態と乖離(flutter_lints ^6.0.0 は Dart ^3.8.0 要求)
- 重大度: 低
- 種別: リファクタ
- 場所: `app/pubspec.yaml:7`、CLAUDE.md の技術スタック記載
- 問題: #40 の flutter_lints 更新で下限宣言が嘘になった(3.5〜3.7 のツールチェーンでは resolve 不能)。CLAUDE.md の「SDK ^3.5.0」も同様に古い。
- 根拠: pubspec / pubspec.lock / pub cache 内の flutter_lints 6.0.0 の environment を確認。
- 提案: `environment: sdk` を実際の下限(最低 ^3.8.0)へ上げ、CLAUDE.md も同じ変更で更新する。
- ステータス: 未対応

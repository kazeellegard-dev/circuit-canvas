# pin-wiring-hardening ゲート修正 handoff — 2026-09-21

## 変更したファイル一覧

- `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift`
- `CircuitCanvas/docs/qa/pin-wiring-hardening-gate-fix-handoff-2026-09-21.md`（本書）

既存の同日 handoff と QA 証跡を保全するため、今回の修正記録は別名で新規作成した。

## 変更内容と失敗の原因

`testPressingWireToolAgainClearsStartPin` は配線端点を文字列として比較していた。実際の accessibilityValue は `695.000000,250.000000,45.000000,390.000000` で、期待値 `695.0,250.0,45.0,390.0` と数値は一致するが、小数点以下の桁数が異なるため失敗した。

既存の `coordinates` ヘルパーで Double 配列に変換し、期待座標 `[695, 250, 45, 390]` と比較するよう修正した。座標や端点順序が違う場合は引き続き失敗する。

回帰 UI テスト `testResetStartPinCanBeReusedAsEndWithMatchingWireCoordinates` を追加した。始点を解除して CAN 右ピンを新しい始点に選び、旧始点の Temperature 右ピンを終点にする。追加配線の座標を固定の期待数値と実際の両ピン座標の両方に照合し、書式に依存せず正しい接続を検証する。

アプリ実装の変更はない。ドラッグしきい値、倍率範囲、ピンチ・パンの追従計算も変更していない。

## QA 担当（Claude Code）向け確認手順・期待結果

対象は iPad Pro 11-inch (M5) / iOS 26.5 シミュレーター。

1. `testPressingWireToolAgainClearsStartPin` を実行する。始点解除後の CAN 右 → Temperature 左の端点が数値として `[695, 250, 45, 390]` と一致し、配線数が4になり成功すること。小数末尾のゼロによる失敗が出ないこと。
2. 追加テスト `testResetStartPinCanBeReusedAsEndWithMatchingWireCoordinates` を実行する。新始点選択時に旧始点の強調が消え、配線はまだ増えないこと。旧始点を終点としてタップすると配線が1本増え、端点が `[695, 250, 195, 390]` および両ピンの座標に一致し、配線数が4になること。
3. 以下の全体ゲートを実行する。重複防止・移動追従・削除を含めて既存テストと追加テストがすべて成功すること。

```sh
xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5'
```

ズーム・パンを含む探索テストと仕様未定項目の観察は、既存 `pin-wiring-hardening-handoff-2026-09-21.md` の手順を引き続き使用する。

## 自分で確認した範囲・未確認の範囲

- 確認済み: 前回ゲートログとコードの照合、`git diff --check`、generic iOS Simulator 向け `xcodebuild build-for-testing`（終了コード0、`TEST BUILD SUCCEEDED`）。追加 UI テストを含むテストターゲットのコンパイル成功。
- ビルドログ: `/tmp/circuit-canvas-pin-wiring-format-build.log`。
- 対象の2テストを指定して `xcodebuild test` を試行したが、CoreSimulatorService への接続拒否で対象デバイスが見つからず終了コード70。実行ログ: `/tmp/circuit-canvas-pin-wiring-format-test.log`。
- 未確認: 修正後の UI テスト実行結果、全体ゲート、ズーム・パンなどの画面操作。ループ側で要確認。実機は対象外。

コミット操作、既存 QA 証跡の変更、`docs/qa/loop/` 配下の変更は行っていない。

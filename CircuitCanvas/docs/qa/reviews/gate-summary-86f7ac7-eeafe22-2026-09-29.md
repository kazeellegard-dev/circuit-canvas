# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 2 件（成功 2 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 32 秒（ビルドを含む全体: 33 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 14.6 | `CircuitCanvasUITests/testOnboardingStartsOnFirstLaunchAndNextWalksEveryStepToTheQuestion()` |
| 12.3 | `CircuitCanvasUITests/testSettingsReplaysTheTourFromTheFirstStep()` |

UI テストの所要時間の合計: 27 秒（2 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 14.6 | `CircuitCanvasUITests/testOnboardingStartsOnFirstLaunchAndNextWalksEveryStepToTheQuestion()` |
| Passed | 12.3 | `CircuitCanvasUITests/testSettingsReplaysTheTourFromTheFirstStep()` |

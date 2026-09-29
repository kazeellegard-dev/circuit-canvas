# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 8 件（成功 8 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 154 秒（ビルドを含む全体: 155 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 58.1 | `CircuitCanvasUITests/testOnboardingStartsOnFirstLaunchAndNextWalksEveryStepToTheQuestion()` |
| 19.9 | `CircuitCanvasUITests/testDontShowAgainSurvivesARelaunchAndShowAgainDoesNot()` |
| 13.2 | `CircuitCanvasUITests/testSettingsResetCancelledLeavesTheCanvasUntouched()` |
| 11.7 | `CircuitCanvasUITests/testSettingsReplaysTheTourFromTheFirstStep()` |
| 10.8 | `CircuitCanvasUITests/testOnboardingSkipAlsoAsksTheQuestion()` |
| 10.1 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| 7.3 | `CircuitCanvasUITests/testLaunchStartsWithABlankCanvasCenteredInTheViewport()` |
| 6.0 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |

UI テストの所要時間の合計: 137 秒（8 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 19.9 | `CircuitCanvasUITests/testDontShowAgainSurvivesARelaunchAndShowAgainDoesNot()` |
| Passed | 6.0 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| Passed | 7.3 | `CircuitCanvasUITests/testLaunchStartsWithABlankCanvasCenteredInTheViewport()` |
| Passed | 10.8 | `CircuitCanvasUITests/testOnboardingSkipAlsoAsksTheQuestion()` |
| Passed | 58.1 | `CircuitCanvasUITests/testOnboardingStartsOnFirstLaunchAndNextWalksEveryStepToTheQuestion()` |
| Passed | 10.1 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| Passed | 11.7 | `CircuitCanvasUITests/testSettingsReplaysTheTourFromTheFirstStep()` |
| Passed | 13.2 | `CircuitCanvasUITests/testSettingsResetCancelledLeavesTheCanvasUntouched()` |

# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 5 件（成功 5 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 57 秒（ビルドを含む全体: 59 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 19.7 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| 10.7 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |
| 10.0 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| 8.9 | `CircuitCanvasUITests/testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning()` |
| 4.8 | `CircuitCanvasUITests/testTwoFingerPanRecognizerAttachesToTheWindow()` |

UI テストの所要時間の合計: 54 秒（5 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 19.7 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| Passed | 8.9 | `CircuitCanvasUITests/testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning()` |
| Passed | 10.0 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| Passed | 10.7 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |
| Passed | 4.8 | `CircuitCanvasUITests/testTwoFingerPanRecognizerAttachesToTheWindow()` |

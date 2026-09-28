# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 9 件（成功 9 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 150 秒（ビルドを含む全体: 152 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 46.8 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| 26.1 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 15.6 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| 10.6 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |
| 9.9 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| 8.7 | `CircuitCanvasUITests/testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning()` |
| 5.9 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| 5.5 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| 4.7 | `CircuitCanvasUITests/testOneFingerDragOnBlankCanvasDoesNothingOutsidePanMode()` |

UI テストの所要時間の合計: 134 秒（9 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 5.5 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| Passed | 46.8 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| Passed | 26.1 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 5.9 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| Passed | 4.7 | `CircuitCanvasUITests/testOneFingerDragOnBlankCanvasDoesNothingOutsidePanMode()` |
| Passed | 15.6 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| Passed | 8.7 | `CircuitCanvasUITests/testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning()` |
| Passed | 9.9 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| Passed | 10.6 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |

# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 7 件（成功 7 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 97 秒（ビルドを含む全体: 98 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 20.7 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| 20.5 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| 19.5 | `CircuitCanvasUITests/testZoomMenuKeepsTheViewportCenterEvenWhenAlreadyPannedNearTheEdge()` |
| 8.9 | `CircuitCanvasUITests/testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning()` |
| 8.2 | `CircuitCanvasUITests/testEditModeBlocksPlacingASymbolFromTheLibrary()` |
| 5.8 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| 4.6 | `CircuitCanvasUITests/testOneFingerDragOnBlankCanvasDoesNothingOutsidePanMode()` |

UI テストの所要時間の合計: 88 秒（7 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 5.8 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| Passed | 8.2 | `CircuitCanvasUITests/testEditModeBlocksPlacingASymbolFromTheLibrary()` |
| Passed | 20.7 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| Passed | 4.6 | `CircuitCanvasUITests/testOneFingerDragOnBlankCanvasDoesNothingOutsidePanMode()` |
| Passed | 20.5 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| Passed | 8.9 | `CircuitCanvasUITests/testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning()` |
| Passed | 19.5 | `CircuitCanvasUITests/testZoomMenuKeepsTheViewportCenterEvenWhenAlreadyPannedNearTheEdge()` |

# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 10 件（成功 10 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 55 秒（ビルドを含む全体: 56 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 20.2 | `CircuitCanvasUITests/testZoomSliderKeepsTheViewportCenterEvenWhenAlreadyPannedNearTheEdge()` |
| 13.8 | `CircuitCanvasUITests/testZoomSliderAdjustsToAnyScaleBetweenTheLimits()` |
| 7.9 | `CircuitCanvasUITests/testZoomResetLandsExactlyOn100AfterAPinch()` |
| 6.3 | `CircuitCanvasUITests/testZoomResetLandsExactlyOn100FromAnInjectedStartingScale()` |
| 0.0 | `CanvasZoomTests/aPinchIsDamped()` |
| 0.0 | `CanvasZoomTests/theSliderLandsOnWholePercentsAndRoundTrips()` |
| 0.0 | `CanvasZoomTests/aPinchZoomsAroundTheFingers()` |
| 0.0 | `CanvasZoomTests/aPinchNearTheEdgeKeepsThePointUnderTheFingers()` |
| 0.0 | `CanvasZoomTests/theSliderSpansTheRangeLogarithmically()` |
| 0.0 | `CanvasZoomTests/aPinchStaysWithinTheRange()` |

UI テストの所要時間の合計: 48 秒（4 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 0.0 | `CanvasZoomTests/aPinchIsDamped()` |
| Passed | 0.0 | `CanvasZoomTests/aPinchNearTheEdgeKeepsThePointUnderTheFingers()` |
| Passed | 0.0 | `CanvasZoomTests/aPinchStaysWithinTheRange()` |
| Passed | 0.0 | `CanvasZoomTests/aPinchZoomsAroundTheFingers()` |
| Passed | 0.0 | `CanvasZoomTests/theSliderLandsOnWholePercentsAndRoundTrips()` |
| Passed | 0.0 | `CanvasZoomTests/theSliderSpansTheRangeLogarithmically()` |
| Passed | 7.9 | `CircuitCanvasUITests/testZoomResetLandsExactlyOn100AfterAPinch()` |
| Passed | 6.3 | `CircuitCanvasUITests/testZoomResetLandsExactlyOn100FromAnInjectedStartingScale()` |
| Passed | 13.8 | `CircuitCanvasUITests/testZoomSliderAdjustsToAnyScaleBetweenTheLimits()` |
| Passed | 20.2 | `CircuitCanvasUITests/testZoomSliderKeepsTheViewportCenterEvenWhenAlreadyPannedNearTheEdge()` |

# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 6 件（成功 6 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 117 秒（ビルドを含む全体: 128 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 29.8 | `CircuitCanvasUITests/testUndoRedoOnAddingASymbolANoteAndAWire()` |
| 20.8 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| 17.0 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| 16.2 | `CircuitCanvasUITests/testEditModeDeletesATextItemWithConfirmation()` |
| 13.1 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |
| 13.0 | `CircuitCanvasUITests/testPlacingATextItemClearsAPreviouslySelectedSymbol()` |

UI テストの所要時間の合計: 110 秒（6 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 16.2 | `CircuitCanvasUITests/testEditModeDeletesATextItemWithConfirmation()` |
| Passed | 20.8 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| Passed | 13.0 | `CircuitCanvasUITests/testPlacingATextItemClearsAPreviouslySelectedSymbol()` |
| Passed | 17.0 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| Passed | 29.8 | `CircuitCanvasUITests/testUndoRedoOnAddingASymbolANoteAndAWire()` |
| Passed | 13.1 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |

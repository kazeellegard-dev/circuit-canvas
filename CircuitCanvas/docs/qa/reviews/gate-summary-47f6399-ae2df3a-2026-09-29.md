# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 8 件（成功 8 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 136 秒（ビルドを含む全体: 148 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 29.8 | `CircuitCanvasUITests/testUndoRedoOnAddingASymbolANoteAndAWire()` |
| 20.7 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| 16.8 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| 14.7 | `CircuitCanvasUITests/testEditModeDeletesATextItemWithConfirmation()` |
| 13.1 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |
| 7.6 | `CircuitCanvasUITests/testNewNoteDefaultsToMemoTypeAndIcon()` |
| 6.4 | `CircuitCanvasUITests/testAddSymbolButtonSwitchesLibraryTabToTheSelectedCategory()` |
| 6.1 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |

UI テストの所要時間の合計: 115 秒（8 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 6.4 | `CircuitCanvasUITests/testAddSymbolButtonSwitchesLibraryTabToTheSelectedCategory()` |
| Passed | 14.7 | `CircuitCanvasUITests/testEditModeDeletesATextItemWithConfirmation()` |
| Passed | 20.7 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| Passed | 6.1 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| Passed | 7.6 | `CircuitCanvasUITests/testNewNoteDefaultsToMemoTypeAndIcon()` |
| Passed | 16.8 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| Passed | 29.8 | `CircuitCanvasUITests/testUndoRedoOnAddingASymbolANoteAndAWire()` |
| Passed | 13.1 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |

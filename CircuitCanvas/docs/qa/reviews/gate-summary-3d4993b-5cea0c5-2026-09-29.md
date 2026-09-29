# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 13 件（成功 13 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 258 秒（ビルドを含む全体: 270 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 36.1 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| 34.9 | `CircuitCanvasUITests/testInspectorRenameAndAnIndependentActionAreSeparateUndoSteps()` |
| 23.5 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| 18.6 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| 18.6 | `CircuitCanvasUITests/testLiveEditingANoteBodyBlocksDraggingItAndSavesOnDone()` |
| 14.9 | `CircuitCanvasUITests/testLiveEditingASymbolNameClosesInspectorBlocksOtherElementsUpdatesLiveAndReturnsOnDone()` |
| 14.5 | `CircuitCanvasUITests/testNoteBodyAcceptsMultilineText()` |
| 14.3 | `CircuitCanvasUITests/testLiveEditInputCardNeverOverlapsATallExpandedNoteWhileEditingItsBody()` |
| 13.0 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |
| 12.8 | `CircuitCanvasUITests/testLiveEditingATextItemHoleGrowsWithLongerContent()` |

UI テストの所要時間の合計: 232 秒（13 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 9.5 | `CircuitCanvasUITests/testEditModeToggleIsDisabledWhileLiveEditing()` |
| Passed | 23.5 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| Passed | 34.9 | `CircuitCanvasUITests/testInspectorRenameAndAnIndependentActionAreSeparateUndoSteps()` |
| Passed | 14.3 | `CircuitCanvasUITests/testLiveEditInputCardNeverOverlapsATallExpandedNoteWhileEditingItsBody()` |
| Passed | 18.6 | `CircuitCanvasUITests/testLiveEditingANoteBodyBlocksDraggingItAndSavesOnDone()` |
| Passed | 11.1 | `CircuitCanvasUITests/testLiveEditingARotatedNonBlockSymbolNameHoleIncludesItsLabel()` |
| Passed | 14.9 | `CircuitCanvasUITests/testLiveEditingASymbolNameClosesInspectorBlocksOtherElementsUpdatesLiveAndReturnsOnDone()` |
| Passed | 12.8 | `CircuitCanvasUITests/testLiveEditingATextItemHoleGrowsWithLongerContent()` |
| Passed | 14.5 | `CircuitCanvasUITests/testNoteBodyAcceptsMultilineText()` |
| Passed | 36.1 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| Passed | 18.6 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| Passed | 10.5 | `CircuitCanvasUITests/testUndoIsDisabledWhileLiveEditingAFreshlyAddedItem()` |
| Passed | 13.0 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |

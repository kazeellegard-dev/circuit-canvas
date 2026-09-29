# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 15 件（成功 15 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 309 秒（ビルドを含む全体: 316 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 36.8 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| 35.0 | `CircuitCanvasUITests/testInspectorRenameAndAnIndependentActionAreSeparateUndoSteps()` |
| 30.9 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 23.1 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| 19.0 | `CircuitCanvasUITests/testLiveEditingANoteBodyBlocksDraggingItAndSavesOnDone()` |
| 18.8 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| 18.5 | `CircuitCanvasUITests/testLiveEditingRemainsOperableForAMaxSizedNoteAtMaximumZoom()` |
| 16.3 | `CircuitCanvasUITests/testLiveEditInputCardNeverOverlapsATallExpandedNoteWhileEditingItsBody()` |
| 15.0 | `CircuitCanvasUITests/testLiveEditingASymbolNameClosesInspectorBlocksOtherElementsUpdatesLiveAndReturnsOnDone()` |
| 14.6 | `CircuitCanvasUITests/testNoteBodyAcceptsMultilineText()` |

UI テストの所要時間の合計: 285 秒（15 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 30.9 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 9.2 | `CircuitCanvasUITests/testEditModeToggleIsDisabledWhileLiveEditing()` |
| Passed | 23.1 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| Passed | 35.0 | `CircuitCanvasUITests/testInspectorRenameAndAnIndependentActionAreSeparateUndoSteps()` |
| Passed | 16.3 | `CircuitCanvasUITests/testLiveEditInputCardNeverOverlapsATallExpandedNoteWhileEditingItsBody()` |
| Passed | 19.0 | `CircuitCanvasUITests/testLiveEditingANoteBodyBlocksDraggingItAndSavesOnDone()` |
| Passed | 11.2 | `CircuitCanvasUITests/testLiveEditingARotatedNonBlockSymbolNameHoleIncludesItsLabel()` |
| Passed | 15.0 | `CircuitCanvasUITests/testLiveEditingASymbolNameClosesInspectorBlocksOtherElementsUpdatesLiveAndReturnsOnDone()` |
| Passed | 13.1 | `CircuitCanvasUITests/testLiveEditingATextItemHoleGrowsWithLongerContent()` |
| Passed | 18.5 | `CircuitCanvasUITests/testLiveEditingRemainsOperableForAMaxSizedNoteAtMaximumZoom()` |
| Passed | 14.6 | `CircuitCanvasUITests/testNoteBodyAcceptsMultilineText()` |
| Passed | 36.8 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| Passed | 18.8 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| Passed | 10.6 | `CircuitCanvasUITests/testUndoIsDisabledWhileLiveEditingAFreshlyAddedItem()` |
| Passed | 13.0 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |

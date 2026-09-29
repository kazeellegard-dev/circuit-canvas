# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 14 件（成功 14 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 237 秒（ビルドを含む全体: 244 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 31.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 22.7 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| 20.7 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| 18.8 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| 18.4 | `CircuitCanvasUITests/testNoteInspectorIsRenamedHasAMemoTypeAndAnIconPicker()` |
| 17.3 | `CircuitCanvasUITests/testGroupingAnItemAlreadyInAGroupWidensItInsteadOfNesting()` |
| 16.5 | `CircuitCanvasUITests/testEditModeOnlyDeletesTheWholeGroupNotIndividualMembers()` |
| 14.9 | `CircuitCanvasUITests/testUngroupingRestoresIndividualSelectionAndEditing()` |
| 13.7 | `CircuitCanvasUITests/testUndoRedoOnGroupingAndUngrouping()` |
| 13.2 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |

UI テストの所要時間の合計: 226 秒（14 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 31.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 10.0 | `CircuitCanvasUITests/testDraggingOneGroupedSymbolMovesTheOtherAndKeepsTheConnectingWireAttached()` |
| Passed | 20.7 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| Passed | 16.5 | `CircuitCanvasUITests/testEditModeOnlyDeletesTheWholeGroupNotIndividualMembers()` |
| Passed | 22.7 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| Passed | 17.3 | `CircuitCanvasUITests/testGroupingAnItemAlreadyInAGroupWidensItInsteadOfNesting()` |
| Passed | 11.4 | `CircuitCanvasUITests/testGroupingViaMarqueeMergesPartiallyOverlappingItemsAndSelectingHidesIndividualEditingUI()` |
| Passed | 18.4 | `CircuitCanvasUITests/testNoteInspectorIsRenamedHasAMemoTypeAndAnIconPicker()` |
| Passed | 4.8 | `CircuitCanvasUITests/testOneFingerDragOnBlankCanvasDoesNothingOutsidePanMode()` |
| Passed | 12.9 | `CircuitCanvasUITests/testPlacingATextItemClearsAPreviouslySelectedSymbol()` |
| Passed | 18.8 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| Passed | 13.2 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |
| Passed | 13.7 | `CircuitCanvasUITests/testUndoRedoOnGroupingAndUngrouping()` |
| Passed | 14.9 | `CircuitCanvasUITests/testUngroupingRestoresIndividualSelectionAndEditing()` |

# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 16 件（成功 16 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 271 秒（ビルドを含む全体: 279 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 31.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 28.8 | `CircuitCanvasUITests/testUndoRedoOnGroupingUngroupingMovingAndDeletingAGroup()` |
| 23.3 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| 19.5 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| 18.6 | `CircuitCanvasUITests/testNoteInspectorIsRenamedHasAMemoTypeAndAnIconPicker()` |
| 17.5 | `CircuitCanvasUITests/testGroupingAnItemAlreadyInAGroupWidensItInsteadOfNesting()` |
| 16.8 | `CircuitCanvasUITests/testMixedGroupMovesAllMemberTypesTogetherAndKeepsAnExternalWireAttachedWhileTheOtherEndStaysPut()` |
| 16.7 | `CircuitCanvasUITests/testEditModeOnlyDeletesTheWholeGroupNotIndividualMembers()` |
| 15.2 | `CircuitCanvasUITests/testUngroupingRestoresIndividualSelectionAndEditing()` |
| 13.3 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |

UI テストの所要時間の合計: 261 秒（16 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 31.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 10.3 | `CircuitCanvasUITests/testDraggingOneGroupedSymbolMovesTheOtherAndKeepsTheConnectingWireAttached()` |
| Passed | 16.7 | `CircuitCanvasUITests/testEditModeOnlyDeletesTheWholeGroupNotIndividualMembers()` |
| Passed | 23.3 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| Passed | 9.6 | `CircuitCanvasUITests/testGroupSelectionMarqueeCanStartOnTopOfAnItem()` |
| Passed | 17.5 | `CircuitCanvasUITests/testGroupingAnItemAlreadyInAGroupWidensItInsteadOfNesting()` |
| Passed | 11.5 | `CircuitCanvasUITests/testGroupingViaMarqueeMergesPartiallyOverlappingItemsAndSelectingHidesIndividualEditingUI()` |
| Passed | 16.8 | `CircuitCanvasUITests/testMixedGroupMovesAllMemberTypesTogetherAndKeepsAnExternalWireAttachedWhileTheOtherEndStaysPut()` |
| Passed | 18.6 | `CircuitCanvasUITests/testNoteInspectorIsRenamedHasAMemoTypeAndAnIconPicker()` |
| Passed | 4.9 | `CircuitCanvasUITests/testOneFingerDragOnBlankCanvasDoesNothingOutsidePanMode()` |
| Passed | 13.3 | `CircuitCanvasUITests/testPlacingATextItemClearsAPreviouslySelectedSymbol()` |
| Passed | 19.5 | `CircuitCanvasUITests/testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector()` |
| Passed | 13.3 | `CircuitCanvasUITests/testUndoRedoOnAddingAndDeletingATextItem()` |
| Passed | 28.8 | `CircuitCanvasUITests/testUndoRedoOnGroupingUngroupingMovingAndDeletingAGroup()` |
| Passed | 15.2 | `CircuitCanvasUITests/testUngroupingRestoresIndividualSelectionAndEditing()` |
| Passed | 10.9 | `CircuitCanvasUITests/testWirePinOnAGroupedSymbolCannotBeReconnectedDirectlyOrViaANearbyBackgroundTap()` |

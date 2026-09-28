# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 5 件（成功 5 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 51 秒（ビルドを含む全体: 53 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 14.9 | `CircuitCanvasUITests/testSettingsResetConfirmedClearsSymbolsWiresAndNotes()` |
| 8.9 | `CircuitCanvasUITests/testNoteBodyAcceptsMultilineText()` |
| 8.0 | `CircuitCanvasUITests/testNoteEditButtonOpensTheInspectorDirectly()` |
| 7.8 | `CircuitCanvasUITests/testAddSymbolButtonSwitchesLibraryTabToTheSelectedCategory()` |
| 7.5 | `CircuitCanvasUITests/testNewNoteDefaultsToMemoTypeAndIcon()` |

UI テストの所要時間の合計: 47 秒（5 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 7.8 | `CircuitCanvasUITests/testAddSymbolButtonSwitchesLibraryTabToTheSelectedCategory()` |
| Passed | 7.5 | `CircuitCanvasUITests/testNewNoteDefaultsToMemoTypeAndIcon()` |
| Passed | 8.9 | `CircuitCanvasUITests/testNoteBodyAcceptsMultilineText()` |
| Passed | 8.0 | `CircuitCanvasUITests/testNoteEditButtonOpensTheInspectorDirectly()` |
| Passed | 14.9 | `CircuitCanvasUITests/testSettingsResetConfirmedClearsSymbolsWiresAndNotes()` |

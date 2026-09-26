# circuit-symbols QA handoff — 2026-09-26

## 変更したファイル
- `CircuitCanvas/CircuitCanvas/ContentView.swift`
- `CircuitCanvas/CircuitCanvas/CircuitSymbol.swift`（新規）
- `CircuitCanvas/CircuitCanvasTests/CircuitSymbolTests.swift`（新規）
- `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift`
- `CircuitCanvas/docs/qa/circuit-symbols-handoff-2026-09-26.md`（本ファイル）

## 変更内容
前回の QA 失敗の指定なし。23 種類の回路記号を追加し、抵抗と GND を記号型に置換。
`SymbolKind` に名称・カテゴリ・ピン数・ブロック用アイコンを集約。初期4シンボルと既存5種類のブロックは従来型を維持。
`CircuitSymbolShape` の Path で記号と引き出し線を一体描画し、ライブラリでも同じ図形を縮小表示する。ダイオードの三角は輪郭線、電解コンデンサは＋印、VCC は縦棒の表現を採用。
記号型は通常時の外枠なし、下部の名称、選択時のみ薄いアクセント枠。端子軸は中央 y=32、左端から本体まで連続描画。
カテゴリを6つ設け、項目選択→キャンバスタップの操作を維持。
GND/VCC は左の1端子。共通のピン取得経由で接続・削除・移動・最近傍判定に反映。配線経路計算の本体矩形は150×64のまま。
既存 accessibilityIdentifier を維持し、シンボルの value に `kind=<種類>, style=block/circuit` を追加。名称変更でも種類は保持。

## QA 手順と期待結果
1. 起動直後の4シンボル・3配線を確認：配置座標・ブロック外枠・ピン±75pt・経路は従来どおり（K8）。既存UIテストも実行。
2. 6カテゴリを切り替え、依頼表の23記号と5ブロックを各1回配置：名称で選べ、プレビューにも記号があり、valueのkindが一致する（K1/K2/K8）。
3. 全記号を目視：抵抗のジグザグ、コイルの4山、電池の2セル、極性、LEDの外向き矢印、フォトダイオードの内向き矢印、ツェナーの折れ線、各計器の文字を確認（K10）。左アノード・右カソード。直流電源・電池の＋側は左。
4. 未選択／選択の記号を確認：通常の外枠なし、選択時のみ薄い枠。名称は下。左ピンから本体、2端子なら本体から右ピンまで線が連続する（K3）。
5. GND/VCC はpin-0のみ。その他はpin-0/1の2つ（K4）。
6. 抵抗→LEDを配線し抵抗を移動：端点が追従し全本体矩形を避ける。同じ記号の左右ピン、GNDの同じピンを2回タップしても配線が増えない（K5/K6）。
7. GNDへ抵抗とLEDから接続：未接続→接続ありに変化、左端子へ入る配線の共通経路に分岐黒丸。線分ドラッグ・交差弧も既存操作と同様（K5）。
8. インスペクタで未接続／接続あり、図面シンボル数を確認。GNDを名称変更しても1端子のまま。削除するとGNDへの2配線のみ削除（K7）。
9. 50/100/175/250%・パン後・ダークモードで全記号と引き出し線が一緒に変換され、欠け・ずれ・不可視化がない（K9）。

## 自己検証
検証結果は下記に追記。

- 指定の iPad Pro 11-inch (M5) / iOS 26.5（839D27C2-04D6-43AF-BEAD-924C3E61401A）で実行。
- `CircuitCanvasTests`：既存経路テストと新規記号テストを含む13テスト成功。
- `testCircuitCataloguePlacementKindsAndTerminals`：28項目の配置・種類・端子数をすべて確認して成功。
- 新規配線UIテストの初回は、インスペクタのLabeledContentを独立したStaticTextとして検索し失敗。表示へ `symbol-connection-status` 識別子と接続状態valueを付与し、検索を修正。
- 修正後の `testCircuitWiringSelfRejectionMovementAndGroundDeletion` 成功（自己接続拒否、端点追従、追加記号を含む矩形回避、GND複数接続、名称変更、削除後4配線）。
- 同じ再実行で、既存の `testVisiblePinCentersMatchWireEndpointOffsets`、`testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps`、`testShortHorizontalDiagonalDragAndReturnRecomputesCrossings` も成功。4件0失敗、`TEST SUCCEEDED`。
- 実行コマンドは `xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas -destination 'platform=iOS Simulator,id=839D27C2-04D6-43AF-BEAD-924C3E61401A' -parallel-testing-enabled NO` に上記 `-only-testing:` を指定。
- 初回の並列起動はシミュレーター起動待ちで停滞したため中断し、明示的に起動後、並列を無効にして実行した。
- スクリーンショットで初期ブロック図と受動部品カテゴリのプレビューを確認。`git diff --check` 成功。
- 未確認：既存UIテスト全件の一括実行、全23記号の配置後の詳細目視、50/175/250%とパン後の全記号目視、ダークモード、記号を使った線分ドラッグ・交差弧の目視。これらは上の手順でQA確認を依頼。
- 要確認の仕様事項なし。回転・反転は実装していない。コミット／gitの書き込み操作、既存QA証跡とloop配下の編集は行っていない。

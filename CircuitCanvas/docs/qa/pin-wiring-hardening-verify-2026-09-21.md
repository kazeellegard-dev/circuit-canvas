# pin-wiring-hardening 検証レポート（2026-09-21）

- 検証対象コミット: 08904db
- 環境: iPad Pro 11-inch (M5) / iOS 26.5 シミュレーター（**実機は未確認**）
- 判定: **blocked**（失敗 0 件、成功 5 件、確認不能 4 件）
- 前回レポート（c925cf7 時点、Codex が何も実施できず blocked）は、このレポートで置き換えた。

## 実施したこと

1. `xcodebuild test`（iPad Pro 11-inch (M5) / OS 26.5、全テスト）を自分で実行した。結果は `** TEST SUCCEEDED **`。
   - 成功したテスト: 既存の `testWireToolConnectsTwoSymbolPins`、`testDeletingSymbolRemovesAttachedWires`、`testDeletingNoteDoesNotCrash`、`testExperimentNoteCanBeDragged`、`testLaunchPerformance`、`CircuitCanvasTests/example`、`testLaunch`。
   - 今回追加された 6 テスト: `testDuplicateWireIsRejectedInBothDirections`、`testPressingWireToolAgainClearsStartPin`、`testResetStartPinCanBeReusedAsEndWithMatchingWireCoordinates`、`testAddedWireEndpointsFollowBothDraggedSymbols`、`testDeletingSymbolRemovesNewlyAddedWire`、`testVisiblePinCentersMatchWireEndpointOffsets`。
   - 実行ログに、並列クローンの 1 つで `xctrunner` の起動が一度拒否されたエラー行があった。テストは全件実行され、成功で終了している。
2. 追加テストの中身を読み、受け入れ条件を実際に検証しているか確認した（下表）。
3. アプリをインストール・起動してスクリーンショットを取った: `CircuitCanvas/docs/qa/pin-wiring-hardening-launch-08904db-2026-09-21.png`。
   - 倍率 100%。ピンの緑の輪が、各シンボルの左右の端点位置（配線の端点）に重なっている。修正前の位置ずれ（表示ピンが中心±59pt、配線端点が±75pt）は見えない。
4. コードは変更していない。

## 画面操作について

この環境には `idb` / `axe` / `cliclick` がなく、`simctl` にタップ・スワイプ・ピンチのコマンドがない。よって、私自身がタップ・ドラッグ・ピンチ・パンを行うことはできない。UIテスト（XCUITest）で実行される操作だけは、シミュレーター上で実際に動いた結果として確認した。

## 項目別の結果

| # | 結果 | 根拠・備考 |
|---|---|---|
| 1 | 確認不能 | UIテストで、ピンを個別にタップでき、始点ピンだけが `isSelected` になり、ヒント「終点のピンをタップ（直交で自動配線）」が出ることは確認した（`testPressingWireToolAgainClearsStartPin`）。ただし、アクセントカラーでの強調は色を観察できず未確認。 |
| 2 | 成功 | `testWireToolConnectsTwoSymbolPins` と追加テストの `connectTemperatureToCAN` で、Temperature 右 → CAN 左の 2 タップで配線 `wire-3` が追加され、ヒントが消え、インスペクタの配線数が 3→4 になる。選択ツールへの復帰は、ヒントが消えることまでは確認（ツールの見た目は未観察）。 |
| 3 | 成功 | UIテストで、追加配線の端点座標が両ピンの座標と一致すること（`testAddedWireEndpointsFollowBothDraggedSymbols`、`testResetStartPin…`）と、画面上のピン中心がシンボル中心±75pt であること（`testVisiblePinCentersMatchWireEndpointOffsets`）を確認した。起動直後のスクリーンショットでも、ピンと配線端点が重なっている。倍率 100%・パンなしの範囲。接続後のスクリーンショットは撮っていない。 |
| 4 | 成功 | `testDuplicateWireIsRejectedInBothDirections`：同順・逆順の再接続のどちらも、配線数が 4 のまま。重複が許されれば 5 になるので、テストとして意味がある。 |
| 5 | 成功 | `testPressingWireToolAgainClearsStartPin`：配線ボタン再押下で強調が消え、ヒントが「始点のピンをタップ」に戻る。次のタップは新しい始点になり（配線数は増えない）、その後の 2 タップ目で配線が追加される（端点 `[695, 250, 45, 390]`）。 |
| 6 | 成功 | `testAddedWireEndpointsFollowBothDraggedSymbols`：Temperature、CAN の順にドラッグし、端点が各ピンの座標に追従し、ピンの画面上の移動量とも一致。反対側の端点は変化しない。ドラッグ中の見た目は未観察（終了後の状態のみ）。 |
| 7 | 成功 | `testDeletingSymbolRemovesNewlyAddedWire`：新規配線後に Temperature をインスペクタから削除すると、`wire-3` が消え、配線数が 2 になる（初期の Temperature→MCU の配線と追加配線が消えた）。孤立した線の目視確認はしていない。 |
| 8 | 確認不能 | 倍率 50/100/175/250% とパン後のピンタップは、ピンチ・パン操作が必要で、操作手段がない。UIテスト化も対象外。 |
| 9 | 確認不能 | ピンタップでシンボル・キャンバスが動かないことは、タップ操作の観察が必要で未確認。ドラッグのテストは、シンボル本体のドラッグのみを扱っている。 |

## 既存挙動の維持（コード差分を読んだ範囲）

- 差分は、`ContentView.swift` のピン表示位置（`HStack` を `offset(x: ±75)` に変更）と、アクセシビリティ情報の追加のみ。
- ドラッグしきい値 4pt、倍率 50–250%、ピンチ・パンの計算に関わる行は変更されていない。ただし、実際の動作としての 1:1 追従は操作できず未確認。

## notes（仕様未定の挙動。失敗にしない）

いずれも、実際には操作していないため観察できていない。コードを読んだ見え方は前回レポートと同じ（`ContentView.swift` の `selectWirePin`、`nearestPin`）。

- 始点と同じピンの再タップ: 未観察（コード上は無視する）。
- 空白キャンバスのタップ: 未観察（コード上は 70pt 以内のピンが選ばれる）。
- 同一シンボルの左右ピン接続: 未観察（コード上は配線が追加される）。
- シンボル本体のタップで近い方のピンが選ばれる範囲: 未観察。
- 今回のピン表示位置の変更（±75pt）で、上の最近傍ピンの判定範囲の見え方が変わった可能性がある。

## 未確認

- 項目 1 のアクセントカラー、項目 8、項目 9。
- 仕様未定の 4 挙動の実観察。
- ドラッグ中の見た目、削除後の孤立した線の目視。
- 実機。

## 次にやること

- 項目 1（強調色）・8・9 と、仕様未定 4 挙動は、人が iPad シミュレーターで確認する。または、`idb` などの操作手段を用意する。

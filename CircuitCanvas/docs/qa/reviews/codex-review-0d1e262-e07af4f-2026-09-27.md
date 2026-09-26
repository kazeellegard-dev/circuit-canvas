# Codex レビュー（0d1e262..e07af4f）

- 判定: **要修正**（blocker 0 / major 1 / minor 1 / 提案 0）
- レビュー担当: Codex（読み取り専用）。実装とテストの修正は Claude、テストの実行はスクリプト。

## 所見

配線の直線化と検査追加は概ね妥当です。ただし、ブロック配線への固定余白の適用により、狭い配置で線分ドラッグが動かなくなる回帰があります。実行済みゲートは59件すべて成功しています。

## 実装

### [major] 狭い配置のブロック配線がドラッグ不能になる（不具合）
- 場所: `CircuitCanvas/CircuitCanvas/ContentView.swift:582`
- 内容: 今回、ブロック同士の配線にも minimumTerminalLead > 0 が渡されるため、WireRouting.swift:254–264 の全内部線分に対する固定12pt余白検査が有効になります。一方、routingBounds は狭い隙間で余白を半分まで縮めます。例えば20ptの隙間を通る内部線分は本体から10ptであり、生成時には正当でもドラッグ時には不正になります。その線分を変更しない別の内部線分をドラッグしても全候補が拒否され、元の位置から動けません。これはコード上の判定に基づく指摘で、実行再現はしていません。既存の closeBodiesUseHalfGapForLeadsAndClearance と testCloseSymbolsRetainMaximumAvailableLead は生成した経路だけを検査しており、その後のドラッグを検査していません。
- 提案: ドラッグの余白も周囲の隙間に応じて縮め、開始時に有効な経路を固定12ptの検査だけで拒否しないようにしてください。20pt以下の隙間を経由するブロック配線で、離れた内部線分を動かせることと、本体内部への侵入を防ぐことを回帰テストに追加してください。

## テストの内容

### [minor] 追加UIテストの配列参照を件数検査で保護する（改善提案）
- 場所: `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift:902`
- 内容: testDraggingOneSideOfAStepStraightensTheWire は XCTAssertEqual(before.count,6) の後で before[3]、直線化後の件数検査の後で straight[2]、移動後に moved.first! を参照します。XCTAssert は失敗しても処理を継続するため、経路取得失敗や頂点数の回帰時にテストプロセスがクラッシュし、原因の診断が難しくなります。
- 提案: 添字参照前の件数検査を guard と XCTFail にし、first は XCTUnwrap で取り出してください。

## 確認して問題がなかった点

- ゲート要約は59件成功・失敗0・再試行成功0、実行時間436秒。
- 直線化の13pt境界、頂点の統合、本体を飛び越えないことの単体検査が追加されている。
- 変更された既存検査は新しいスナップ・停止位置を具体値で検証し、端点追従の検査も維持している。
- 既存のリサイズUIテストは90×30、30pt刻み、反対角固定、サイズ上限・下限、配線追従を検査している。

## 確認できなかった点

- 指示に従いビルド・テストは実行していない。結果は提供されたgate-summary.mdによる。
- R8の実画面での文字・アイコンの収まりとダークモード表示。
- レビュー範囲以前に実装されたリサイズ機能全体の再監査。

## 参考: テスト結果の要約

`CircuitCanvas/docs/qa/loop/runs/20260927-084803-review/gate-summary.md` を参照。

# pin-wiring-hardening handoff — 2026-09-21

## 変更したファイル

- `CircuitCanvas/CircuitCanvas/ContentView.swift`
- `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift`
- `CircuitCanvas/docs/qa/pin-wiring-hardening-handoff-2026-09-21.md`

## 変更内容・原因

コード確認で、表示ピンと配線端点の座標に16ptの差を発見した。配線モデルは中心±75pt、従来の表示は幅150ptのHStack内に幅32ptのボタンを置くため中心±59ptとなる。表示ピンを中心±75ptに配置し、端点に一致させた。

Canvasの描画に使用する配線座標をaccessibilityChildrenへ公開し、各ピンに座標値と始点選択のselected traitを追加した。配線の選択・削除などの機能は追加していない。重複判定、始点リセット、移動追従、シンボル削除は既存実装を維持。ドラッグしきい値4pt、倍率50–250%、ピンチ・パンの計算には変更なし。

既存QAレポートはblocked（動作失敗の指摘なし、テスト未追加）だった。次のUIテストを追加した。

- `testDuplicateWireIsRejectedInBothDirections`: 新規配線後、同順・逆順の再接続をそれぞれ初期状態から試し、インスペクタが4本のまま。
- `testPressingWireToolAgainClearsStartPin`: 始点選択とヒントを確認し、配線ボタン再押下で解除。別ピンの次タップでまだ線が増えず、新しい始点から接続される。
- `testAddedWireEndpointsFollowBothDraggedSymbols`: 新規配線の両シンボルを順にドラッグ。描画に使用する端点がピン座標と一致し、画面上のピンの移動量とも一致。反対側の端点は不変。
- `testDeletingSymbolRemovesNewlyAddedWire`: 新規配線後Temperatureをインスペクタから削除。初期配線1本と追加配線1本が消えて2本になる。
- `testVisiblePinCentersMatchWireEndpointOffsets`: 今回の位置修正の回帰テスト。100%でピンの画面上の中心がシンボル中心±75pt、追加配線座標が所定の値である。

## QA担当（Claude Code）向け確認手順と期待結果

対象: iPad Pro 11-inch (M5) / iOS 26.5。各独立ケースは再起動して初期状態に戻す。

1. UIテスト全体を実行する。既存テストと上記5テストが成功すること。
2. 条件1・2・3: 配線→Temperature右ピン→CAN左ピン。最初のタップで右ピンだけアクセントカラー、ヒントが「終点のピンをタップ（直交で自動配線）」になる。2回目で直交配線1本が増え、ヒントが消え、シンボル本体を選択できる。両端は目視でもピンの中心に一致する。未選択状態のインスペクタでは4本。
3. 条件4: 同じ2ピンを同順、逆順で再接続。どちらも4本のまま。
4. 条件5: 始点を選択して配線ボタン再押下。強調解除と始点ヒントを確認し、CAN右を押す。この時点では線が増えず、CAN右のみが始点。Temperature左を押すとその2ピン間に線が追加される。
5. 条件6: 新規配線のTemperatureとCANをそれぞれドラッグ。移動中・終了後とも端点が各ピンに追従し、反対側は動かない。
6. 条件7: 新規配線後Temperature本体を選択→確認→シンボルを削除。Temperatureとそこから出る2本が消え、残り2本。シートを閉じて孤立した線がないことも目視確認する。
7. 条件8: 50% / 100% / 175% / 250%で左右ピンを狙ってタップ。見える位置へパンした後も繰り返す。狙ったピンのみが始点になり、終点も一致する。高倍率で画面外のピンにはパンして移動する。隣のピンの誤選択がないこと。倍率上下限と、ピンチ・パンが操作量に1:1で追従することも確認する。
8. 条件9: 各倍率・パン後にピンをタップし、シンボル位置とキャンバス位置が変わらないこと。

実行例（リポジトリルート）:

```sh
xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5' -only-testing:CircuitCanvasUITests
```

## 確認済み・未確認

- 確認済み: 実装と既存QA記録の読み取り、`git diff --check`、generic iOS Simulator向け`xcodebuild build-for-testing`（アプリ・ユニットテスト・UIテストのコンパイル成功）。DerivedDataは`/tmp/circuit-canvas-pin-wiring-build`、ビルドログは`/tmp/circuit-canvas-pin-wiring-build.log`。
- `xcodebuild test`を指定シミュレーターで試したが、サンドボックス内でCoreSimulatorService接続が拒否され、シミュレーターを利用できない。テスト成功とは扱わない。実行はループ側ゲートで要確認。
- 未確認: 追加UIテストの実行結果、画面上での配線一致と強調色、ズーム・パンを含む探索操作、既存操作の実行時回帰。実機は対象外。
- 要確認（仕様未定、失敗扱いにしない）: 同じ始点の再タップ、空白キャンバスのタップ、同一シンボルの左右接続、本体タップで近いピンが選ばれる範囲。今回は変更せず、QAの実観察をnotes / unverifiedへ記載すること。

コミット操作はしていない。既存QA証跡と`docs/qa/loop/`は編集していない。

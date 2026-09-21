# wire-routing-and-hints 線分判定修正 handoff — 2026-09-21

## 変更したファイル一覧

- `CircuitCanvas/CircuitCanvas/ContentView.swift`
- `CircuitCanvas/CircuitCanvas/WireRouting.swift`
- `CircuitCanvas/CircuitCanvasTests/WireRoutingTests.swift`
- `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift`
- `CircuitCanvas/docs/qa/wire-routing-and-hints-hit-resolution-handoff-2026-09-21.md`（本書）

## 変更内容と原因

対象は iter2 GATE の次の2件。

- `testShortHorizontalSegmentDragDoesNotSelectAdjacentVerticalSegment`
- `testCrossingMetadataAppearsAndDisappearsWithoutChangingEndpoints`

いずれも初期 wire-2 の短い横線を上97ptドラッグした後、yが302のままで、期待値205にならなかった。保存済みxcresultの合成イベントを読み取り、前者は画面座標 (269,440) → (269,343) の入力であることを確認した。対象の横線中央からの入力は送られている。

従来はジェスチャを受信した透明ビューの線分番号と方向をそのまま移動対象にしていた。長さ12ptの横線の両側には縦線が6ptの距離にあり、近接ターゲットへのタッチ配送に依存する作りだった。前回の領域縮小だけでは失敗が解消しなかった。隣接縦線への配送が原因と考えられるが、SwiftUIが実際に配送した線分番号はQA記録からは確定できない。

今回、線分ビューがドラッグを受信した時点で、開始座標を論理座標に変換し、全配線の中間線分から実際の線までの距離が最小のものを選ぶよう変更した。対象の配線ID・線分番号・元の経路は開始時に保持し、途中で他の線分へ切り替わらない。移動方向も選んだ線分から決める。透明ビューの配送先が隣接線分でも、横線中央から始めた操作は横線を移動する。

既存の開始しきい値4pt、倍率換算、端点値、経路・交差計算、線分ターゲットの配置順とサイズは維持。背景へジェスチャを追加していない。

追加した回帰テスト:

- 単体 `shortHorizontalTouchChoosesVisibleLineAndMovesOnlyItsY`: 横線中央と左右1ptから横線を選択し、yだけ302→205となることを検査。隣接縦線の選択と、直線1本の配線が移動対象外であることも検査。短い横線の失敗に対応。
- 単体 `shortHorizontalDragCreatesAndRemovesCrossingOnOtherWire`: 配線をまたいだ対象判定から移動し、(269,205)、半径7の交差が出現、戻すと消滅することを検査。交差メタデータの失敗に対応。
- UI `testShortHorizontalDiagonalDragAndReturnRecomputesCrossings`: 斜めドラッグでも横線のyだけ動き、交差が出現し、戻すと消えることを検査。端点・シンボル位置・viewport・配線数の維持も検査。
- 失敗した既存2件は期待値を緩めず維持。

## QA担当（Claude Code）向け確認手順

1. 指定シミュレーターで失敗した既存2件を実行。期待: wire-2の横線yが302→205になり、両テスト成功。交差テストでは縦線を左へ移動すると交差が消える。
2. 新規UIテストを実行。期待: 右18pt・上97ptの斜めドラッグでもxは変化せず、横線両端のyのみ205となる。交差は(269,205)付近に出現。逆方向へ戻すと初期経路に戻り、交差は消滅する。シンボル・viewport・端点・配線数は不変。
3. 手動で同じ短い横線、およびその両側の縦線の中央を個別にドラッグ。期待: 最寄りの線分が垂直方向へ移動し、途中で対象が切り替わらない。50/100/175/250%およびパン後にも位置対応と1:1追従を確認。
4. 全ゲートを実行。期待: 新規単体2件を含む全テストが成功し、ピン操作・シンボルと付箋のドラッグ・背景パンも従来どおり。

```sh
xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5' -derivedDataPath /tmp/circuit-wire-hit-qa CODE_SIGNING_ALLOWED=NO
```

## 自分で確認した範囲と未確認の範囲

- `xcodebuild build-for-testing`（generic/platform=iOS Simulator）成功。変更後のアプリ・単体テスト・UIテストをコンパイルした。
- 実際の `WireRouting.swift` と `WireRoutingTests.swift` を `/tmp` の一時Swiftパッケージへコピーし、macOS上でSwift Testingの6テストを実行、全件成功。iOS上の実行確認ではない。
- `git diff --check` 成功。
- 変更後の `xcodebuild test` を指定シミュレーターで試行したが、CoreSimulatorService接続拒否により実機種のdestinationを取得できず、テスト開始前に終了。
- 要確認: iOS 26.5の実際のタッチ配送を含むUI回帰テスト・全ゲートの成功、各倍率での手動操作と見た目。上記手順でQA側の検証が必要。
- 既存QA証跡・既存handoff・loop配下は変更していない。コミット等のgit書き込み操作は行っていない。

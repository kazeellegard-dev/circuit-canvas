# wire-routing-and-hints GATE修正 handoff — 2026-09-21

## 変更したファイル一覧

- `CircuitCanvas/CircuitCanvas/ContentView.swift`
- `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift`
- `CircuitCanvas/docs/qa/wire-routing-and-hints-gate-fix-handoff-2026-09-21.md`（本書）

## 変更内容と原因

対象: `testCrossingMetadataAppearsAndDisappearsWithoutChangingEndpoints` の交差出現時の XCTAssertFalse 失敗。

初期 wire-2 の中間横線は (263,302) → (275,302)、長さ12pt。中央 (269,302) は、隣接する縦線 segment-3 の幅16ptのヒット領域にも入っていた。segment-3 が後から配置されるため、横線中央からの上方向ドラッグを縦線側が取得し得る。縦線は横方向だけ動くので、期待した交差が作られない。

中間線分のヒット領域を長手方向の両端で縮め、折れ点付近の隣接領域の重複を解消した。片端の縮小量は min(8pt, 線分長/4)。短い線分でも中央の領域を残す。幅16pt、開始しきい値4pt、倍率換算、経路・交差計算、端点メタデータ形式は変更していない。

- 新規UI回帰テスト `testShortHorizontalSegmentDragDoesNotSelectAdjacentVerticalSegment`: 問題の横線中央を上97ptドラッグし、横線両端のyのみ変化、全x・他の点・端点・viewport・配線数が不変であることを検査。
- 既存の交差UIテストに、交差を作る2操作それぞれの移動後座標の検査を追加。交差出現・消滅、端点・本数の検査は維持。

## QA担当（Claude Code）向け確認手順

1. iPad Pro 11-inch (M5) / iOS 26.5 で上記2つのUIテストを実行。期待: 両方成功。横線のyが302から205へ変わり、交差が出現した後、縦線の左移動で交差が消える。
2. 初期wire-2の短い横線中央を上下にドラッグ。期待: 横線だけ上下へ移動し、隣接縦線が伸縮。キャンバスのパンや縦線の横移動にならない。
3. 初期wire-0の中間縦線中央を左6pt、wire-2の短い横線中央を上97ptドラッグ。期待: (269,205) 付近で縦線のジャンプが表示される。wire-0をさらに左30pt動かすと消える。配線数は3、端点は不変。
4. 全ゲートを実行。期待: 既存のピン操作、シンボル・付箋移動、パン、線分ドラッグを含め全テスト成功。

```sh
xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5' -derivedDataPath /tmp/circuit-wire-gate-qa CODE_SIGNING_ALLOWED=NO
```

## 自分で確認した範囲・未確認の範囲

- `xcodebuild build-for-testing` を generic/platform=iOS Simulator で実行し成功。アプリと単体・UIテストのコンパイルを確認。
- 実際の WireRouting.swift を使った standalone Swift の再現で、初期経路と指定の2ドラッグ後の座標を確認。交差計算は (269,205)、半径7ptを返した。これはUI操作の成功を示すものではない。
- `git diff --check` 成功。
- `xcodebuild test` は実行を試みたが、CoreSimulatorService接続拒否により指定シミュレーターを取得できず終了。UI回帰テスト・全ゲートの実行成功、画面表示、各倍率での実操作は未確認。ループ側で確認が必要。
- 既存handoff・QA証跡・loop配下は変更していない。コミットやgit書き込み操作は行っていない。

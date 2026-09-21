# wire-routing-and-hints handoff — 2026-09-21

## 変更したファイル

- `CircuitCanvas/CircuitCanvas/ContentView.swift`
- `CircuitCanvas/CircuitCanvas/WireRouting.swift`（新規）
- `CircuitCanvas/CircuitCanvasTests/WireRoutingTests.swift`（新規）
- `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift`
- `CircuitCanvas/docs/qa/wire-routing-and-hints-handoff-2026-09-21.md`（本書）

コミット、git の書き込み操作、既存 QA 証跡・loop 配下の編集は行っていない。

## 変更内容・原因

- A/H1: ヒントが拡大・平行移動対象の canvasContent に含まれていた。4種類とも editor の左上 overlay に移動。関連付け中は関連付けヒントを優先する。ヒントはヒットテストしない。
- B: 同じシンボルに属する2ピンの接続を無視し、始点選択を維持する。
- C: 中間 x 固定の3線分では障害物・重なりを考慮できなかった。論理座標上の直交グリッドの最短経路探索に変更。150×64 の本体内部を避け、左右ピンから外向きに進む。既存経路と同一直線の重なりを避け、共有ピンの水平な端点線分の重なりだけ許す。追加・削除・シンボル移動時に自動経路を再計算する。
- D: 中間線分だけに16pt幅の透明なヒット領域を配置。シンボル・付箋より背面、選択ツール時だけ有効。開始しきい値4pt、viewport座標のtranslationを倍率で割り、垂直方向だけに適用。本体までの移動を掃引検査し、隣接線分も含め最初の衝突境界で止める。手動経路を保存し、シンボル移動時は端点側を伸縮する。
- E: 異なる経路の縦・横の厳密な内点交差を関数で検出。縦線だけ半径7ptの半円を右側に描く。端点・角での接触は除外。縦線端から7pt未満の交差は半円の代わりに小さな輪郭円を描く。表示だけを変更し、経路・接続・ヒット領域は変更しない。

### QA用 accessibility

- `wire-N`: 従来どおり `始点x,始点y,終点x,終点y`。
- `wire-N-points`: `x,y;x,y;...` の全折れ点（両端を含む）。
- `wire-N-hops`: 縦線上の交差座標 `x,y;x,y;...`。端に近い代替表示の交差も含む。交差なしは空文字。
- `wire-N-segment-K`: points の K → K+1 の中間線分（0始まり）。
- `operation-hint`: viewport固定の操作ヒント。

## Claude Code向け確認手順と期待結果

1. 既存テストと追加テストを iPad Pro 11-inch (M5) / iOS 26.5 で実行する。期待: 既存ピン・配線・付箋・削除テストを含め通過。
2. A: 配線、付箋、シンボル配置、付箋の関連付けをそれぞれ開始し、50/100/175/250%でパンする。期待: ヒントの位置・大きさが固定され、左上から消えない。関連付けは付箋の長押しメニューから開始できる。UI回帰テストは最初の3モードの縮小・パンを確認する。
3. B: Temperature右→Temperature左。期待: 3本のまま、右ピンの始点選択と終点ヒントを保持。その後CAN左を押すと4本になる。
4. C: 初期状態を確認後、S1 Temperature右→CAN左、S2 Temperature右→Main MCU右、S3 24V左→Main MCU左を追加する。期待: 本体内部を通らず、端点は外向き。共有ピンに接する線分以外に重なりがない。Main MCUを右48/下48pt動かしても成立する。追加UIテストは各段階の全経路を検査する。
5. D: 初期wire-0の中間縦線を斜めにドラッグ。期待: xだけ変わり、ピンは不動、キャンバスも不動、配線数3。右へ200pt動かすとx=295の本体境界で止まる。横の中間線分も上下だけ動くことを確認する。50/100/175/250%で指と線分の移動量を比較し1:1を確認する。線分以外ではパン、シンボル・付箋の移動、ピンタップが従来どおり動くことを確認する。
6. D5: 線分を動かした後で接続先シンボルを移動。期待: 手動線分の軸座標を保持し、ピンに追従する端点と隣接線分は直交する。図面インスペクタの配線数は変わらない。
7. E: 初期wire-0の中間縦線を左6pt移動し、wire-2の短い中間横線（初期y=302、x=263〜275）を上97pt移動。期待: wire-0と交差し、縦線が半円で横線をまたぐ。wire-0をさらに左30pt動かすと交差・弧が消える。追加UIテストでもhopsの出現・消滅と端点・配線数不変を確認する。拡大縮小で弧も同率に変化することを目視する。
8. E2: 単体テストで端点・角での接触の除外、端に近い交差の代替表示判定を確認する。見た目はシミュレーターでも確認する。

実行例:

```sh
xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5' -derivedDataPath /tmp/circuit-wire-qa CODE_SIGNING_ALLOWED=NO
```

## 自分で確認した範囲

- `xcodebuild build-for-testing`（generic/platform=iOS Simulator）成功。アプリ・単体テスト・UIテストのコンパイルを確認した。
- WireRoutingTests の4つの検査を同じ実装に対する standalone Swift の assert ハーネスとして実行し、全件成功。初期+S1〜S3、MCU移動後の回避・重なり・外向き、縦横ドラッグと本体境界、手動経路追従、交差の検出・除外・消滅を検査した。これは XCTest/Swift Testing ランナーでの成功を意味しない。
- `git diff --check` 成功。
- `xcodebuild test` は試行したが CoreSimulatorService 接続拒否・simdiskimaged不応答により対象デバイスを取得できず終了。UIテスト実行、画面の目視、4倍率での1:1操作感、既存テストの実行結果は未確認。実機は対象外。

## 要確認（仕様の競合する配置）

- シンボルを重ねてピン自体を他の本体内部へ置く場合など、外向きの端点区間が確保できない配置の扱いは未指定。現在、経路探索不能時は空経路を返す（接続データは保持）。通常の初期配置・指定S1〜S3と移動テストでは発生していない。
- 手動線分の上へシンボル本体を直接移動させた場合の「手動位置保持」と「本体回避」の優先順位は要確認。現在は手動位置を保持する。線分ドラッグ操作自体は本体内部への侵入を防止する。

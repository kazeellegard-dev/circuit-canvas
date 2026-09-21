# wire-lead-out-and-junction-dots handoff — 2026-09-21

## 変更ファイル

- `CircuitCanvas/CircuitCanvas/WireRouting.swift`
- `CircuitCanvas/CircuitCanvas/ContentView.swift`
- `CircuitCanvas/CircuitCanvasTests/WireRoutingTests.swift`
- `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift`
- `CircuitCanvas/docs/qa/wire-lead-out-and-junction-dots-handoff-2026-09-21.md`

## 変更内容・原因

前回の QA 失敗の指定はなし。背景の窮屈な配線は、探索時に本体内部だけを禁止し、外周の余白を禁止領域に含めていなかったことが原因。

- 探索用の本体領域を左右24pt・上下20pt拡張。ピンから外へ出る部分だけは本体の実寸で判定する。
- 向かい合うシンボルのすき間が狭いときは、各辺の余白をすき間の半分まで縮める。最初の引き出しも同じ境界まで出す。
- 手動線分の移動・端点追従は従来どおり。本体の内部への侵入を禁止し、手動位置を保持する。F1/F2の自動余白は自動経路に適用する。
- 共有ピンから2経路をたどり、最初に分かれる点を分岐点として算出。端点、単なる交差、重複位置を除外。逆向きの経路、途中の同一直線上の頂点、ゼロ長線分も考慮。
- 分岐点に直径10ptの主色の塗りつぶし円を描画。キャンバスと同じ拡大縮小を受け、`allowsHitTesting(false)` とする。分岐点にホップは描かない。
- `canvas-junctions` の accessibilityValue は、論理座標 `x,y;x,y;...`（x・y順に整列、分岐なしは空文字）。既存 `wire-N` の端点値は変更なし。
- 既存UIテストの交差位置の期待値を x=269 から265へ更新（引き出し変更により自動の縦線が4pt左へ移動）。検証する性質は維持。

## Claude Code 向け確認手順・期待結果

1. アプリを再起動。初期3本に本体との余白があり、Main MCU左側の `(271,250)` に黒丸が1つある。ピン自体には黒丸を描かず、初期の分岐にホップはない。
2. UIで順に S1 Temperature右→CAN左、S2 Temperature右→Main MCU右、S3 24V左→Main MCU左を接続。全端点は左右の外側へ24pt以上引き出され、本体に沿う非端末線分は12pt以上離れる。S3の24V下側の線は y=212（下端192から20pt）。
3. S1後の分岐値は `259.0,390.0;271.0,250.0;521.0,250.0`。S2・S3後は `259.0,390.0;271.0,250.0;469.0,250.0;469.0,390.0;521.0,250.0`。同じ点に重複せず、ピンを共有する3本以上でも分岐ごとに描画される。
4. Main MCUを右下48pt移動。自動経路と黒丸が追従し、F1/F2と内部侵入・非共有配線の重なり回避を満たす。別途、線分を手動で移動してからシンボルを移動すると、手動線分の座標が保持される。
5. 再起動しCANを左へ70pt移動（MCUとのすき間30pt）。MCU右→CAN右を追加。最初の曲がりまで15ptとなり、狭いすき間を通れる。
6. 再起動しwire-0の縦線を左へ20pt、その後右へ44pt移動。縦線がMCU左端x=295に達すると共通の引き出しがなくなり黒丸は消える。左へ44pt戻すと再出現する。端点・配線数・キャンバス位置は変わらない。
7. 線分ドラッグで交差を作り、戻す。通常のホップは付け外しされ、分岐点にはホップがない。ピンのタップ、線分ドラッグ、空白からのパンが機能する。
8. 空白からピンチして50%、100%、250%で目視。黒丸はピンと同じ直径比で拡大縮小される。ライト・ダーク表示では線と同じ主色。操作ヒントは固定。

## 自己確認・未確認

- 最終版の `xcodebuild test` が **TEST SUCCEEDED**（2026-09-21 22:56 JST）。iPad Pro 11-inch (M5) / iOS 26.5。UI 29件（起動テスト4件を含む）、Swift Testing 11件、すべて成功。
- 実行コマンド: `xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas -destination 'platform=iOS Simulator,id=839D27C2-04D6-43AF-BEAD-924C3E61401A' -parallel-testing-enabled NO`
- 結果バンドル: `/Users/kazeellegard/Library/Developer/Xcode/DerivedData/CircuitCanvas-arerrywdbojgxmeehhvdnwatewer/Logs/Test/Test-CircuitCanvas-2026.09.21_22-51-44-+0900.xcresult`
- 新規UIテストで近接時の15pt引き出し、分岐の初期位置と消失・再出現を確認。既存UIテストを強化し、S1〜S3・シンボル移動後の24pt引き出しと12pt余白、3本共有時の分岐位置と重複排除、分岐とホップの非重複を確認。
- ユニットテストで狭い左右・上下のすき間、複数の分岐、逆向き経路、余分な頂点とゼロ長線分、ピンや単なる交差の除外を確認。
- 既存のヒント固定、同一シンボル接続禁止、重なり回避、線分ドラッグ、手動位置保持、端点と配線数保持のテストも成功。`git diff --check` 成功。
- 50〜250%の黒丸の見た目、ダークモードの目視はQA担当による確認対象。実機は対象外。
- 要確認の仕様事項なし。

# circuit-symbols-resize-and-rotate handoff（2026-09-26）

## 変更したファイル

- CircuitCanvas/CircuitCanvas/CircuitSymbol.swift
- CircuitCanvas/CircuitCanvas/ContentView.swift
- CircuitCanvas/CircuitCanvas/WireRouting.swift
- CircuitCanvas/CircuitCanvasTests/CircuitSymbolTests.swift
- CircuitCanvas/CircuitCanvasTests/WireRoutingTests.swift
- CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift
- CircuitCanvas/docs/qa/circuit-symbols-resize-and-rotate-handoff-2026-09-26.md

## 変更内容

- 回路記号の本体範囲を横 100 × 44pt、縦 44 × 100pt、端子を中心から 50pt に変更。2 端子記号の外部引き出し線は左右 28pt、本体の絵は幅 44pt 内。ピンの丸とタップ領域は維持。
- 0 / 90 / 180 / 270 度の時計回り回転を実装。インスペクタと選択中の記号のそばに操作ボタンを設置。キャンバスのボタンは 32 × 32pt のタップ領域を明示。
- ピン番号を維持して端点を更新。本体範囲と配線を再計算し、回転対象につながる手動配線のみ自動に戻す。選択中の配線始点も追従。
- 端子の外向き方向をモデルから経路計算へ渡し、上下の引き出し・共通幹線・分岐・手動線分の再接続に対応。回路記号を含む線分ドラッグは 24pt の端子引き出しと 12pt の本体余白を保つ。
- 電源・電池・交流・GND は 90 度、VCC は 270 度で初期化。ライブラリも同じ向き。名称、M/V/A、極性の文字は図形とは別に描画して横書きを維持。
- ブロック型の寸法、端子座標、識別子と回転なしの動作は維持。ブロック型固有の既存テストは変更していない。共通経路検証ヘルパーには回路記号の寸法・上下端子の判定を追加した。
- 回転角は symbol-<title>-rotation の value、ボタンは inspector-rotate と symbol-<title>-rotate。ピンの value は回転後のモデル座標。

前回 QA 失敗の指定はなし。実装中のテストで検出して修正した点：
- ブロック同士の狭い間隔にも一律 24pt を適用すると経路が空になるため、既存ブロックの半間隔ルールを維持。
- 縦の余白が 20pt だと経路整理時に引き出しも 20pt に戻るため、縦向き記号の上下余白を 24pt に変更。
- 円形矢印の中央がタップ対象から外れるため、ボタンに矩形の contentShape を指定。
- 右側ラベルが縦向き記号のアクセシビリティ領域を広げていたため、ラベルは別描画にし、本体の選択領域から分離。

## QA（Claude Code）向け確認手順

1. **L1/L3/L4/N1–N4**：各カテゴリの記号を配置。
   - 回路記号の 2 ピンの距離は 100pt。電源・電池・交流は上下、GND は上端子、VCC は下端子。
   - その他は回転 0。初期 4 ブロックと追加のブロックは横 150pt の端子間隔のまま。
2. **L2/L5/N6**：100% で抵抗、LED、電池、GND、VCC とライブラリを目視。
   - 短い引き出し線、抵抗のジグザグ、LED の三角と矢印、電池の長短極板が識別できる。
   - 電源は長い極板と＋が上。GND は上端子から下に 3 本線。VCC は下端子から上に棒。
3. **M1–M3/M7**：抵抗を選択し、両方の回転ボタンをそれぞれ 4 回操作。
   - 0→90→180→270→0、中心不変。pin-0 は左→上→右→下。ピンやパンの操作を妨げない。
   - ブロック型には回転ボタンがない。
4. **M4/M5/M9**：抵抗・電源・GND 間を接続し、回転・移動・改名・削除。
   - 端点が追従し、経路は本体内部を避け、上下の引き出しも 24pt 以上。
   - 接続表示を維持。削除では接続配線のみが消える。
5. **M6/N5**：縦の電源と GND を接続して水平の中間線分を上下にドラッグ。電源の同じ端子から別記号へ分岐を追加。
   - 端点を保って線分だけが移動。電源側の分岐点に黒丸。電源を回転すると横向きとなり手動経路が再計算される。
   - 別の線と交差する位置へ動かしたとき、弧が付き、交点を分岐扱いしないことも目視確認。
6. **M8/L6**：モーター・電圧計・電流計を 4 方向へ回転。50〜250% とダークモードで確認。
   - M/V/A と名前が横書き。名前とピン・引き出し・周辺配線が重ならない。線、文字、丸が一緒に拡大縮小される。

## 自分で確認した範囲・未確認の範囲

- Swift の型チェック、git diff --check を実施。
- 共通 SwiftUI 描画部品の画像出力で全 23 種の基本形と電源の初期方向を確認した。この画像は macOS 上の描画部品の確認であり、iPad 画面操作の証跡ではない。
- iPad Pro 11-inch (M5) / iOS 26.5 の xcodebuild test：最終結果を実行完了後に追記する。
- 実機・iPhone は対象外。50/250%、ダークモードの全記号の目視、およびあらゆる配置でのラベルと他配線の非重複は未確認。上記手順で QA の確認をお願いする。
- git の書き込み操作、既存 QA 証跡、docs/qa/loop 配下の編集は行っていない。

実行コマンド：

```sh
xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj \
  -scheme CircuitCanvas \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5' \
  -parallel-testing-enabled NO
```

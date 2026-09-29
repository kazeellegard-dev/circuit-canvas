# CircuitCanvas — Claude 向けメモ

iPad 向け SwiftUI アプリ（回路図キャンバス）。Claude が実装し、`scripts/review-loop.sh` でテスト（ゲート）を実行してから、Codex がレビューする。

## 読み方のルール（使用量の節約）

- **`ContentView.swift`（約 2,400 行・157KB）と `CircuitCanvasUITests.swift`（約 2,700 行・171KB）は、全体を Read しない。**
  Grep で型・関数・`// MARK:` を探してから、`offset` / `limit` で必要な範囲（前後 100〜200 行程度）だけを読む。
- 一度読んだ範囲は読み直さない。編集の直後に、確認のための再読もしない。
- `CircuitCanvas/docs/qa/` の PNG・`.ips`・過去のレビュー（`reviews/`）・QA 文書は、必要な場合を除いて読まない。
  レビューの指摘は `CircuitCanvas/docs/qa/loop/review.json`（最新の 1 件）だけを読めばよい。
- `docs/*.md`（要件・ロードマップなど）は、タスクに関係する部分だけを Grep で探して読む。

## ファイルの地図

| ファイル | 中身 |
|---|---|
| `CircuitCanvas/CircuitCanvas/ContentView.swift` | 画面のほぼすべて。データ型（`SymbolItem` / `NoteItem` / `TextItem` / `WireItem` / `GroupItem` / `CanvasSnapshot`）、`struct ContentView`、各カード（`SymbolCard` / `NoteCard` / `TextCard`）、`ScrimWithHole`、`Grid`、`TwoFingerPanOverlay`、`IconPickerView` |
| ↳ `// MARK: Grouping (5E)` | グループ化（2 か所にある） |
| ↳ `// MARK: Live editing on the canvas (5D)` | キャンバス上のライブ編集・入力カードの配置 |
| ↳ `// MARK: Undo / Redo (4D)` | Undo / Redo |
| `CircuitCanvas/CircuitCanvas/CircuitSymbol.swift` | シンボルの種類・形状（`SymbolKind` / `CircuitSymbolShape` / `CircuitGlyph`）、`ResizableGeometry` / `CanvasZoom` / `BlockSize` など |
| `CircuitCanvas/CircuitCanvas/WireRouting.swift` | 配線の経路計算（`enum WireRouting`） |
| `CircuitCanvas/CircuitCanvasTests/` | 単体テスト（Swift Testing）: `CircuitSymbolTests` / `WireRoutingTests` |
| `CircuitCanvas/CircuitCanvasUITests/CircuitCanvasUITests.swift` | UI テスト（XCTest）。`// MARK: -` で機能ごとに区切られている |
| `CircuitCanvas/docs/qa/loop/tasks/*.md` | 各機能のタスク（要件・受け入れ条件） |
| `CircuitCanvas/docs/qa/loop/README.md` | ループの説明 |

## 開発の流れ（review-loop）

1. 実装してコミットする。コミットメッセージは件名 1 行（100 文字以内が目安）と、必要なら短い本文。経緯の詳細はレビューの md に残るので、書かない。
2. `scripts/review-loop.sh --task CircuitCanvas/docs/qa/loop/tasks/<task>.md [--only-testing <Target/Class/test>]...`
   - ラウンドの途中は、`--only-testing` で関係するテストだけを実行する。フルスイートは、機能の最後に 1 回だけ実行する。
   - ゲートには約 5 分かかる。**バックグラウンドで実行して、完了の通知を待つ。** 待っている間に、状態の確認を繰り返さない。
3. `CircuitCanvas/docs/qa/loop/review.json` を読み、blocker・major を直す。minor・suggestion は、すぐ直せるものだけ直す。採用しない指摘は、理由を 1 行で書く。
4. 承認されたら、その機能の作業は終わり。次の機能は新しいセッションで始める（または `/clear` する）。

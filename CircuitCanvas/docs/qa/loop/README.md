# Codex ⇄ Claude Code 自動 QA ループ

```
Codex (実装/修正) → xcodebuild test (ゲート) → Claude Code (探索テスト) → verdict.json
      ↑                                                                    │ fail
      └──────────────── failures をプロンプトに載せて再実行 ←──────────────┘
```

## 使い方

1. `task.template.md` を `tasks/<名前>.md` にコピーして、目的・要件・受け入れ条件を書く。
2. 事前に、ステージ済みの無関係な変更を整理する（あると中止する。`--allow-staged` で回避可）。
3. 実行:

```bash
scripts/qa-loop.sh --dry-run CircuitCanvas/docs/qa/loop/tasks/<名前>.md   # 流れの確認だけ
scripts/qa-loop.sh --max-iter 3 CircuitCanvas/docs/qa/loop/tasks/<名前>.md
```

終了コード: `0`=pass / `1`=反復上限（人の判断が必要）/ `2`=事前チェック失敗・blocked・QA がコードを変更した。

## ファイル

| ファイル | 役割 |
|---|---|
| `codex-prompt.md` / `claude-prompt.md` | 各エージェントへの固定指示（編集して育てる） |
| `verdict.schema.json` | Claude Code が書く判定の形式 |
| `verdict.json` | 最新の判定（git 管理外） |
| `runs/<日時>-<タスク>/` | 各回のプロンプト・ログ・判定（git 管理外） |

## 安全装置

- ステージ済みの変更があれば開始しない（Codex のコミットへの巻き込み防止）。
- Claude Code の実行前後でアプリ・テストのコードのハッシュを比較し、変更されていたら中止する。
- 反復上限（既定 3 回）。
- `xcodebuild test` が失敗したら、Claude Code を呼ばずに Codex へ戻す（ログ末尾を failure として渡す）。
- `pass` は Claude Code が `verdict.json` に書いたときだけ。書かれなければ中止。

## 既知の制約

- `claude -p`（CLI）からシミュレーター操作ツール（タップ・スワイプ）が使えるかは未確認。使えない場合、QA はビルド・起動・スクリーンショット・ログ確認までになる。その場合は `blocked` になるので、操作が必要な項目は UI テスト化して、ゲートで検証する。
- `CLAUDE_ARGS` の許可ツール名は環境に合わせて調整する。
- 実機は対象外（シミュレーターのみ）。

---

## 2026-09-26 追加: 役割の入れ替え（Claude が実装、Codex がレビュー）

`qa-loop.sh`（Codex が実装 → Claude が QA）とは別に、次の分担のループを用意した。Codex の利用上限や、`danger-full-access` を毎回ユーザーが付ける手間を避けられる。

| 工程 | 担当 |
|---|---|
| 実装・修正（コミット） | **Claude** |
| テスト（`xcodebuild test`：テスト専用の端末・並列なし・失敗は 1 回だけ再試行） | **スクリプト**（`scripts/review-loop.sh`） |
| 実装のレビュー（改善提案を含む）、テストの内容・結果のレビュー（改善提案を含む） | **Codex**（読み取り専用: `codex exec -s read-only`） |
| 画面の確認（シミュレーターの実操作） | Claude |

```bash
# 例: 直前のレビュー以降の変更を、テストして、Codex にレビューさせる
scripts/review-loop.sh --task CircuitCanvas/docs/qa/loop/tasks/<task>.md
# 範囲を指定 / テストを省略して既存の xcresult を使う
scripts/review-loop.sh --base <SHA> --head <SHA> --skip-gate --gate-xcresult <path>.xcresult
# 材料の作成だけ確認する
scripts/review-loop.sh --dry-run
```

- 出力: `docs/qa/loop/review.json`（最新。Claude が読む。形式は `review.schema.json`）、`docs/qa/reviews/codex-review-*.md`（人が読む）、`docs/qa/reviews/gate-summary-*.md`（テスト結果の要約）。
- Codex への指示: `codex-review-prompt.md`。観点は、実装（要件・正しさ・回帰）、テストの内容（検査の強さ・抜け・不安定さ・重複）、テストの結果（失敗・遅さ・不安定）。
- 終了コード: 0=承認 / 1=要修正（テスト失敗、または blocker・major）/ 2=事前チェック失敗 / 3=Codex の失敗。
- 流れ: Claude が実装してコミット → スクリプトを実行 → Claude が `review.json` の指摘を読み、直す（または、採用しない理由を書く）→ 再実行。

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

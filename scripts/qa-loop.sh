#!/usr/bin/env bash
# Codex (実装) -> xcodebuild test (ゲート) -> Claude Code (QA) -> verdict.json -> 失敗なら Codex へ戻す
#
# 使い方:
#   scripts/qa-loop.sh [--dry-run] [--max-iter N] [--allow-staged] [--keep-verdict] TASK_FILE
#
# 終了コード: 0=pass / 1=反復上限に到達 / 2=事前チェック失敗・blocked・保護違反
#
# 環境変数:
#   CODEX_CMD    Codex の非対話コマンド        (既定: "codex exec -s workspace-write")
#   CLAUDE_CMD   Claude Code の非対話コマンド  (既定: "claude -p")
#   CLAUDE_ARGS  Claude Code に追加する引数     (既定: --allowedTools を最小限に設定)
#   SIM_ID       テスト対象シミュレーターの UDID (既定: iPad Pro 11-inch (M5))
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/CircuitCanvas"
LOOP_DIR="$APP_DIR/docs/qa/loop"
VERDICT="$LOOP_DIR/verdict.json"
PROJECT="$APP_DIR/CircuitCanvas.xcodeproj"
SCHEME="CircuitCanvas"
SIM_ID="${SIM_ID:-839D27C2-04D6-43AF-BEAD-924C3E61401A}"
CODEX_CMD="${CODEX_CMD:-codex exec -s workspace-write}"
CLAUDE_CMD="${CLAUDE_CMD:-claude -p}"
CLAUDE_ARGS="${CLAUDE_ARGS:---allowedTools Bash,Read,Write,Glob,Grep,mcp__Claude_Code_iOS_Simulator__*}"

# Claude Code が触ってはいけないパス（コード）
PROTECTED=(CircuitCanvas/CircuitCanvas CircuitCanvas/CircuitCanvasTests CircuitCanvas/CircuitCanvasUITests)

DRY_RUN=0
MAX_ITER=3
ALLOW_STAGED=0
KEEP_VERDICT=0
TASK_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --max-iter) MAX_ITER="$2"; shift ;;
    --allow-staged) ALLOW_STAGED=1 ;;
    --keep-verdict) KEEP_VERDICT=1 ;; # 前回の verdict.json（fail）を引き継いで再開する
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    -*) echo "不明なオプション: $1" >&2; exit 2 ;;
    *) TASK_FILE="$1" ;;
  esac
  shift
done

die() { echo "ERROR: $*" >&2; exit 2; }
log() { echo "[qa-loop $(date +%H:%M:%S)] $*"; }
notify() {
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"$1\" with title \"CircuitCanvas QA loop\"" >/dev/null 2>&1 || true
}

[[ -n "$TASK_FILE" ]] || die "TASK_FILE を指定してください（雛形: $LOOP_DIR/task.template.md）"
[[ -f "$TASK_FILE" ]] || die "TASK_FILE が見つかりません: $TASK_FILE"
TASK_FILE="$(cd "$(dirname "$TASK_FILE")" && pwd)/$(basename "$TASK_FILE")"
TASK_NAME="$(basename "$TASK_FILE" .md)"
command -v jq >/dev/null || die "jq が必要です"

read -r -a CODEX_ARR <<< "$CODEX_CMD"
read -r -a CLAUDE_ARR <<< "$CLAUDE_CMD"
read -r -a CLAUDE_EXTRA <<< "$CLAUDE_ARGS"

cd "$REPO_ROOT"

# --- 事前チェック -----------------------------------------------------------
if [[ $DRY_RUN -eq 0 ]]; then
  command -v "${CODEX_ARR[0]}" >/dev/null || die "${CODEX_ARR[0]} が PATH にありません（CODEX_CMD で指定可）"
  command -v "${CLAUDE_ARR[0]}" >/dev/null || die "${CLAUDE_ARR[0]} が PATH にありません（CLAUDE_CMD で指定可）"
fi
if [[ $ALLOW_STAGED -eq 0 ]] && ! git diff --quiet; then
  echo "追跡中ファイルに未コミットの変更があります。Codex の変更と区別できないため中止します:" >&2
  git diff --name-only | sed 's/^/  /' >&2
  die "先にコミットするか、--allow-staged を付けてください"
fi
if [[ $ALLOW_STAGED -eq 0 ]] && ! git diff --cached --quiet; then
  echo "ステージ済みの変更があります。Codex のコミットに巻き込まれる恐れがあるため中止します:" >&2
  git diff --cached --name-only | sed 's/^/  /' >&2
  die "整理するか --allow-staged を付けてください"
fi

RUN_DIR="$LOOP_DIR/runs/$(date +%Y%m%d-%H%M%S)-$TASK_NAME"
mkdir -p "$RUN_DIR"
log "run dir: $RUN_DIR  (max-iter=$MAX_ITER, dry-run=$DRY_RUN)"
[[ $KEEP_VERDICT -eq 1 ]] || rm -f "$VERDICT"

run() { # 実行内容を表示し、dry-run では実行しない
  if [[ $DRY_RUN -eq 1 ]]; then echo "  [dry-run] $1 ...（プロンプトは runs/ 配下のファイルを参照）"; return 0; fi
  "$@"
}

snapshot_untracked() { git ls-files -o --exclude-standard | sort; }

# Codex はサンドボックスで .git に書けないため、コミットはループ側で行う。
# Codex が変更・新規作成したパスだけを、パス指定でコミットする（loop/ 配下は除外）。
commit_codex_changes() { # $1=イテレーション番号, $2=変更前の未追跡ファイル一覧
  local changed="$RUN_DIR/iter$1-changed.txt"
  { git ls-files -m; comm -13 "$2" <(snapshot_untracked); } | grep -v '^CircuitCanvas/docs/qa/loop/' | sort -u > "$changed" || true
  if [[ ! -s "$changed" ]]; then
    notify "Codex が何も変更しませんでした"
    die "Codex が何も変更しませんでした（サンドボックスや権限の問題の可能性）。$RUN_DIR/iter$1-codex.log を確認してください"
  fi
  log "Codex の変更をコミット: $(wc -l < "$changed" | tr -d ' ') ファイル"
  git add --pathspec-from-file="$changed"
  git commit -q --pathspec-from-file="$changed" -m "qa-loop: $TASK_NAME (iteration $1, Codex)" \
    -m "Automated commit by scripts/qa-loop.sh of files changed by Codex."
  log "commit $(git rev-parse --short HEAD)"
}

code_fingerprint() { # コード変更のみ（HEAD は含めない）
  { git diff -- "${PROTECTED[@]}"; git ls-files --others --exclude-standard -- "${PROTECTED[@]}"; } | shasum | cut -d' ' -f1
}

write_gate_failure_verdict() { # $1=ログパス
  local tail_txt
  tail_txt="$(tail -n 40 "$1" | tr '\n' ' ' | cut -c1-1500)"
  # 失敗したテストの詳細（アサーション文）を xcresult から取り出す。ビルドエラーなら error: 行を使う。
  local xcr detail
  xcr="$(grep -A1 'Test session results' "$1" | grep -o '/.*\.xcresult' | tail -1 || true)"
  detail=""
  if [[ -n "$xcr" && -d "$xcr" ]]; then
    detail="$(xcrun xcresulttool get test-results summary --path "$xcr" 2>/dev/null \
      | jq -r '[.testFailures[]? | "\(.testIdentifierString): \(.failureText)"] | join(" | ")' 2>/dev/null || true)"
  fi
  [[ -z "$detail" ]] && detail="$(grep -E 'error:' "$1" | head -10 | tr '\n' ' ' | cut -c1-1500 || true)"
  [[ -n "$detail" ]] && tail_txt="$detail"
  jq -n --arg task "$TASK_NAME" --arg commit "$(git rev-parse --short HEAD)" --arg tail "$tail_txt" --arg log "${1#$REPO_ROOT/}" '{
    task:$task, commit:$commit, status:"fail", checked_at:(now|todate),
    environment:"xcodebuild test (gate)", items:[],
    failures:[{id:"GATE", severity:"critical", title:"xcodebuild test が失敗した",
      repro_steps:["xcodebuild test -project CircuitCanvas/CircuitCanvas.xcodeproj -scheme CircuitCanvas を実行"],
      actual:$tail, expected:"ビルドとテストが成功する", evidence:[$log]}],
    unverified:[], report:$log }' > "$VERDICT"
}

build_codex_prompt() {
  cat "$LOOP_DIR/codex-prompt.md"
  printf '\n---\n# タスク（%s）\n\n' "$TASK_NAME"
  cat "$TASK_FILE"
  if [[ -f "$VERDICT" ]] && [[ "$(jq -r .status "$VERDICT")" == "fail" ]]; then
    printf '\n---\n# 前回の QA 失敗（これをすべて修正すること）\n\n'
    jq -r '.failures[] | "## \(.id) [\(.severity)] \(.title)\n再現手順:\n\(.repro_steps | map("- " + .) | join("\n"))\n実際: \(.actual)\n期待: \(.expected)\n証跡: \((.evidence // []) | join(", "))\n"' "$VERDICT"
    printf '詳細レポート: %s\n' "$(jq -r .report "$VERDICT")"
  fi
}

build_claude_prompt() {
  cat "$LOOP_DIR/claude-prompt.md"
  printf '\n---\n# 今回の対象\n\n- タスク名: %s\n- タスクファイル: %s\n- 検証対象コミット: %s\n- handoff: CircuitCanvas/docs/qa/ 配下の最新の *handoff* ファイル（%s に関するもの）\n' \
    "$TASK_NAME" "${TASK_FILE#$REPO_ROOT/}" "$(git rev-parse --short HEAD)" "$TASK_NAME"
}

# --- ループ -----------------------------------------------------------------
for ((i = 1; i <= MAX_ITER; i++)); do
  log "=== iteration $i/$MAX_ITER ==="

  # 1) Codex: 実装／修正
  build_codex_prompt > "$RUN_DIR/iter$i-codex-prompt.md"
  UNTRACKED_BEFORE="$RUN_DIR/iter$i-untracked-before.txt"; snapshot_untracked > "$UNTRACKED_BEFORE"
  log "Codex 実行"
  run "${CODEX_ARR[@]}" "$(cat "$RUN_DIR/iter$i-codex-prompt.md")" 2>&1 | tee "$RUN_DIR/iter$i-codex.log" || \
    { notify "Codex が失敗しました"; die "Codex が異常終了しました（$RUN_DIR/iter$i-codex.log）"; }
  if [[ $DRY_RUN -eq 0 ]]; then commit_codex_changes "$i" "$UNTRACKED_BEFORE"; fi

  # 2) ゲート: xcodebuild test
  log "ゲート: xcodebuild test"
  GATE_LOG="$RUN_DIR/iter$i-gate.log"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] xcodebuild test -project ... -scheme $SCHEME -destination id=$SIM_ID"
  elif ! xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "id=$SIM_ID" > "$GATE_LOG" 2>&1; then
    log "ゲート失敗 → Codex へ戻す"
    write_gate_failure_verdict "$GATE_LOG"
    continue
  fi

  # 3) Claude Code: 探索テスト（コード変更は禁止）
  build_claude_prompt > "$RUN_DIR/iter$i-claude-prompt.md"
  rm -f "$VERDICT"
  BEFORE="$(code_fingerprint)"
  log "Claude Code 実行"
  run "${CLAUDE_ARR[@]}" "$(cat "$RUN_DIR/iter$i-claude-prompt.md")" "${CLAUDE_EXTRA[@]}" 2>&1 | tee "$RUN_DIR/iter$i-claude.log" || \
    { notify "Claude Code が失敗しました"; die "Claude Code が異常終了しました（$RUN_DIR/iter$i-claude.log）"; }
  if [[ $DRY_RUN -eq 0 ]] && [[ "$(code_fingerprint)" != "$BEFORE" ]]; then
    notify "QA がコードを変更しました。中止"
    die "Claude Code がコードを変更しました（禁止）。git diff で確認してください"
  fi

  # 4) 判定
  if [[ $DRY_RUN -eq 1 ]]; then log "dry-run のためここで終了"; exit 0; fi
  [[ -f "$VERDICT" ]] || die "verdict.json が作られていません（$RUN_DIR/iter$i-claude.log を確認）"
  jq -e '.status and (.failures|type=="array") and .report' "$VERDICT" >/dev/null || die "verdict.json の形式が不正です"
  cp "$VERDICT" "$RUN_DIR/iter$i-verdict.json"
  STATUS="$(jq -r .status "$VERDICT")"
  log "verdict: ${STATUS}（失敗 $(jq '.failures|length' "$VERDICT") 件）"

  case "$STATUS" in
    pass) notify "pass（${TASK_NAME}, iter ${i}）"; log "完了: pass"; exit 0 ;;
    blocked) notify "blocked（${TASK_NAME}）"; die "QA が環境要因で検証できません。$(jq -r .report "$VERDICT") を確認してください" ;;
    fail) ;; # 次のイテレーションで Codex に渡す
    *) die "不明な status: $STATUS" ;;
  esac
done

notify "上限（$MAX_ITER 回）に到達: $TASK_NAME"
log "反復上限に到達しました。人の判断が必要です: $VERDICT"
exit 1

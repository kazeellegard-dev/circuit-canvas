#!/usr/bin/env bash
# Claude が実装・修正（コミット） -> このスクリプトがテスト（ゲート） -> Codex（読み取り専用）がレビュー
#
# 使い方:
#   scripts/review-loop.sh [--base REV] [--head REV] [--task TASK_FILE] [--skip-gate]
#                          [--review-on-fail] [--allow-dirty] [--dry-run]
#                          [--only-testing NAME]...
#
#   --base REV         レビュー対象の起点（既定: 前回レビューした HEAD。なければ HEAD~1）
#   --head REV         レビュー対象の終点（既定: HEAD）
#   --task FILE        タスクファイル（要件・受け入れ条件）。指定すると、実装がタスクを満たすかもレビューする
#   --skip-gate        テストを実行しない（直前の結果 --gate-xcresult を使う）
#   --gate-xcresult P  --skip-gate のとき、要約に使う xcresult
#   --review-on-fail   テストが失敗しても、Codex にレビューさせる（既定: 失敗したら、レビューせずに終了）
#   --allow-dirty      未コミットの変更があっても実行する（テストは、作業ツリーに対して動く）
#   --dry-run          テストと Codex を実行しない（材料の作成までを確認する）
#   --only-testing N   xcodebuild の -only-testing:N をそのまま渡す（複数指定可）。指定すると、フルスイート
#                       ではなく、そのテストだけを実行する（時短用。全体の回帰は、最終確認で別途フル実行する）。
#                       ゲートの要約・Codex への材料に「一部のみ実行」である旨を明記する。
#
# 出力:
#   CircuitCanvas/docs/qa/loop/runs/<日時>-review/   材料（diff・要約・プロンプト・review.json など）
#   CircuitCanvas/docs/qa/loop/review.json           最新のレビュー結果（Claude が読む。git 管理外）
#   CircuitCanvas/docs/qa/reviews/codex-review-*.md  人が読むレビュー結果（git 管理）
#
# 終了コード: 0=承認 / 1=要修正（テスト失敗、または blocker・major の指摘）/ 2=事前チェック失敗 / 3=Codex の実行失敗
#
# 環境変数:
#   CODEX_REVIEW_CMD  Codex の非対話コマンド（既定: "codex exec -s read-only --ephemeral"）
#                     レビューは読み取り専用で足りる。danger-full-access は不要。
#   SIM_ID            テスト専用シミュレーターの UDID（既定: iPad Pro 11-inch (M5) TEST）
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/CircuitCanvas"
LOOP_DIR="$APP_DIR/docs/qa/loop"
REVIEWS_DIR="$APP_DIR/docs/qa/reviews"
PROJECT="$APP_DIR/CircuitCanvas.xcodeproj"
SCHEME="CircuitCanvas"
SIM_ID="${SIM_ID:-8E4B0FE5-0E65-456A-9FC7-F399E3C87547}"
CODEX_REVIEW_CMD="${CODEX_REVIEW_CMD:-codex exec -s read-only --ephemeral}"
LAST_HEAD_FILE="$LOOP_DIR/last-review-head"

BASE=""; HEAD_REV="HEAD"; TASK_FILE=""
SKIP_GATE=0; REVIEW_ON_FAIL=0; ALLOW_DIRTY=0; DRY_RUN=0; GATE_XCRESULT=""
ONLY_TESTING=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift ;;
    --head) HEAD_REV="$2"; shift ;;
    --task) TASK_FILE="$2"; shift ;;
    --skip-gate) SKIP_GATE=1 ;;
    --gate-xcresult) GATE_XCRESULT="$2"; shift ;;
    --review-on-fail) REVIEW_ON_FAIL=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --only-testing) ONLY_TESTING+=("$2"); shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "不明なオプション: $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "ERROR: $*" >&2; exit 2; }
log() { echo "[review-loop $(date +%H:%M:%S)] $*"; }
notify() {
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"$1\" with title \"CircuitCanvas review loop\"" >/dev/null 2>&1 || true
}

cd "$REPO_ROOT"
git rev-parse --git-dir >/dev/null 2>&1 || die "git リポジトリではありません"
HEAD_SHA="$(git rev-parse --short "$HEAD_REV")" || die "--head が解決できません: $HEAD_REV"
if [[ -z "$BASE" ]]; then
  if [[ -f "$LAST_HEAD_FILE" ]]; then BASE="$(cat "$LAST_HEAD_FILE")"; else BASE="HEAD~1"; fi
fi
BASE_SHA="$(git rev-parse --short "$BASE")" || die "--base が解決できません: $BASE"
[[ "$BASE_SHA" != "$HEAD_SHA" ]] || die "レビュー対象の差分がありません（base=$BASE_SHA, head=$HEAD_SHA）"
if [[ -n "$TASK_FILE" ]]; then
  [[ -f "$TASK_FILE" ]] || die "TASK_FILE が見つかりません: $TASK_FILE"
  TASK_FILE="$(cd "$(dirname "$TASK_FILE")" && pwd)/$(basename "$TASK_FILE")"
fi
if [[ $ALLOW_DIRTY -eq 0 && $DRY_RUN -eq 0 && -n "$(git status --porcelain --untracked-files=no)" ]]; then
  die "未コミットの変更があります。コミットしてから実行してください（--allow-dirty で無視）"
fi
command -v python3 >/dev/null || die "python3 が必要です"

RUN_DIR="$LOOP_DIR/runs/$(date +%Y%m%d-%H%M%S)-review"
mkdir -p "$RUN_DIR" "$REVIEWS_DIR"
log "レビュー対象: $BASE_SHA..$HEAD_SHA / 出力: ${RUN_DIR#$REPO_ROOT/}"

# ---------- 1. テスト（ゲート） ----------
GATE_MD="$RUN_DIR/gate-summary.md"
GATE_STATUS="skipped"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "  [dry-run] xcodebuild test -project ... -scheme $SCHEME -destination id=$SIM_ID -parallel-testing-enabled NO -retry-tests-on-failure -test-iterations 2" >&2
  echo "# テスト結果の要約（dry-run: 未実行）" > "$GATE_MD"
else
  if [[ $SKIP_GATE -eq 0 ]]; then
    GATE_XCRESULT="$RUN_DIR/gate.xcresult"
    ONLY_TESTING_ARGS=()
    for t in "${ONLY_TESTING[@]:-}"; do
      [[ -n "$t" ]] && ONLY_TESTING_ARGS+=("-only-testing:$t")
    done
    if [[ ${#ONLY_TESTING_ARGS[@]} -gt 0 ]]; then
      log "ゲート: xcodebuild test（一部のみ実行 - 時短。全体の回帰は最終確認で別途）: ${ONLY_TESTING[*]}"
    else
      log "ゲート: xcodebuild test（テスト専用の端末・並列なし・失敗は 1 回だけ再試行）"
    fi
    START=$(date +%s); GATE_EXIT=0
    # 端末を起動しきってから始める。起動直後は、テストランナーの起動が "Busy" で拒否されることがある。
    run_gate() {
      xcrun simctl boot "$SIM_ID" >/dev/null 2>&1 || true
      xcrun simctl bootstatus "$SIM_ID" -b >/dev/null 2>&1 || true
      rm -rf "$GATE_XCRESULT"
      GATE_EXIT=0
      xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "id=$SIM_ID" \
        -parallel-testing-enabled NO -retry-tests-on-failure -test-iterations 2 \
        "${ONLY_TESTING_ARGS[@]}" \
        -resultBundlePath "$GATE_XCRESULT" > "$RUN_DIR/gate.log" 2>&1 || GATE_EXIT=$?
    }
    run_gate
    # ランナーが起動できなかった（テストが 1 件も走っていない）ときだけ、もう 1 回やり直す。
    # ランナーの起動失敗のログがあり、かつ XCTest・Swift Testing どちらの「開始」記録もないときだけ、やり直す。
    # 記録が見当たらない＝実行 0 件、とみなす簡便な判定（xcresult の実行件数そのものは見ていない）。
    # 記録が実際にあれば（一部だけでも実行できていれば）、やり直さず、その結果を残す。
    if [[ $GATE_EXIT -ne 0 ]] && grep -q "Failed to install or launch the test runner" "$RUN_DIR/gate.log" \
        && ! grep -qE "^Test Case '|Test .* started\.$" "$RUN_DIR/gate.log"; then
      log "テストランナーの起動に失敗したため（テストは 0 件）、端末を再起動して、ゲートをやり直します"
      # 1 回目のログと結果は、残しておく。
      mv "$RUN_DIR/gate.log" "$RUN_DIR/gate-attempt1.log"
      [[ -d "$GATE_XCRESULT" ]] && mv "$GATE_XCRESULT" "$RUN_DIR/gate-attempt1.xcresult"
      xcrun simctl shutdown "$SIM_ID" >/dev/null 2>&1 || true
      sleep 5
      run_gate
    fi
    WALL=$(( $(date +%s) - START ))
  else
    [[ -n "$GATE_XCRESULT" && -d "$GATE_XCRESULT" ]] || die "--skip-gate には --gate-xcresult（既存の xcresult）が必要です"
    GATE_EXIT=0; WALL=""
  fi
  [[ -d "$GATE_XCRESULT" ]] || die "xcresult ができていません（ビルドの失敗？）: $RUN_DIR/gate.log を確認してください"
  SUMMARY_LINE="$(python3 "$REPO_ROOT/scripts/lib/gate_summary.py" "$GATE_XCRESULT" "$GATE_MD" \
      --exit-code "$GATE_EXIT" ${WALL:+--wall-seconds "$WALL"})"
  log "ゲートの結果: $SUMMARY_LINE"
  GATE_STATUS="$(sed -E 's/^status=([a-z]+).*/\1/' <<<"$SUMMARY_LINE")"
  if [[ "$GATE_STATUS" != "pass" && $REVIEW_ON_FAIL -eq 0 ]]; then
    log "テストが失敗しました。Claude が直してから、再実行してください: ${GATE_MD#$REPO_ROOT/}"
    notify "テスト失敗（$BASE_SHA..$HEAD_SHA）"
    exit 1
  fi
fi

# ---------- 2. レビュー材料 ----------
git log --stat --format='commit %h %s%n%b---' "$BASE..$HEAD_REV" > "$RUN_DIR/commits.txt"
git diff "$BASE..$HEAD_REV" -- . ':!*.png' ':!*.ips' ':!*.xcresult' > "$RUN_DIR/diff.patch"
git diff "$BASE..$HEAD_REV" -- CircuitCanvas/CircuitCanvasTests CircuitCanvas/CircuitCanvasUITests > "$RUN_DIR/tests-diff.patch"
log "材料: diff $(wc -l < "$RUN_DIR/diff.patch") 行 / テストの diff $(wc -l < "$RUN_DIR/tests-diff.patch") 行"

PROMPT="$RUN_DIR/review-prompt.md"
{
  cat "$LOOP_DIR/codex-review-prompt.md"
  echo
  echo "---"
  echo "# 今回の対象"
  echo
  echo "- リポジトリ: $REPO_ROOT"
  echo "- レビュー範囲: $BASE_SHA..$HEAD_SHA（git のコミット。\`git log\` \`git diff\` で読んでよい）"
  echo "- 材料のディレクトリ: $RUN_DIR"
  echo "  - commits.txt / diff.patch / tests-diff.patch / gate-summary.md"
  echo "- テストの判定: $GATE_STATUS"
  if [[ ${#ONLY_TESTING[@]} -gt 0 ]]; then
    echo "- ゲートの範囲: **一部のみ実行**（時短のため、以下のテストだけ）。それ以外の既存テストは、直近複数回のフル実行で成功しており、今回は実行していない。全体の回帰は、最終確認で別途フル実行する。"
    for t in "${ONLY_TESTING[@]}"; do echo "  - $t"; done
  else
    echo "- ゲートの範囲: フルスイート"
  fi
  if [[ -n "$TASK_FILE" ]]; then
    echo
    echo "# タスク（要件と受け入れ条件）"
    echo
    cat "$TASK_FILE"
  else
    echo "- タスクファイル: なし（要件は、コミットメッセージと差分から読み取る）"
  fi
} > "$PROMPT"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "  [dry-run] $CODEX_REVIEW_CMD -C $REPO_ROOT --output-schema $LOOP_DIR/review.schema.json -o $RUN_DIR/review.json - < ${PROMPT#$REPO_ROOT/}" >&2
  log "dry-run 完了。材料: ${RUN_DIR#$REPO_ROOT/}"
  exit 0
fi

# ---------- 3. Codex のレビュー（読み取り専用） ----------
log "Codex レビュー実行（読み取り専用）"
REVIEW_JSON="$RUN_DIR/review.json"
# shellcheck disable=SC2086
if ! $CODEX_REVIEW_CMD -C "$REPO_ROOT" --output-schema "$LOOP_DIR/review.schema.json" \
      -o "$REVIEW_JSON" - < "$PROMPT" > "$RUN_DIR/codex.log" 2>&1; then
  notify "Codex のレビューが失敗しました"
  echo "ERROR: Codex が異常終了しました（$RUN_DIR/codex.log を確認）" >&2
  tail -5 "$RUN_DIR/codex.log" >&2 || true
  exit 3
fi
[[ -s "$REVIEW_JSON" ]] || { echo "ERROR: review.json が空です（$RUN_DIR/codex.log を確認）" >&2; exit 3; }
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$REVIEW_JSON" 2>/dev/null \
  || { echo "ERROR: review.json が JSON ではありません（$REVIEW_JSON）" >&2; exit 3; }

REPORT="$REVIEWS_DIR/codex-review-${BASE_SHA}-${HEAD_SHA}-$(date +%Y-%m-%d).md"
RESULT_LINE="$(python3 "$REPO_ROOT/scripts/lib/review_to_md.py" "$REVIEW_JSON" "$REPORT" "$BASE_SHA" "$HEAD_SHA" "${GATE_MD#$REPO_ROOT/}")"
cp "$REVIEW_JSON" "$LOOP_DIR/review.json"
cp "$GATE_MD" "$REVIEWS_DIR/gate-summary-${BASE_SHA}-${HEAD_SHA}-$(date +%Y-%m-%d).md"
echo "$HEAD_SHA" > "$LAST_HEAD_FILE"
log "レビュー結果: $RESULT_LINE"
log "レポート: ${REPORT#$REPO_ROOT/}"

if grep -q 'status=approve' <<<"$RESULT_LINE"; then
  notify "承認（$BASE_SHA..$HEAD_SHA）"
  exit 0
fi
notify "要修正（$BASE_SHA..$HEAD_SHA）: $RESULT_LINE"
exit 1

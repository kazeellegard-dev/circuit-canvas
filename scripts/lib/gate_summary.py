#!/usr/bin/env python3
"""xcresult からテスト結果の要約（Markdown）を作る。Codex のレビュー材料であり、Claude も読む。

使い方: gate_summary.py XCRESULT_PATH OUT_MD [--exit-code N] [--wall-seconds S]
標準出力に 1 行: status=pass|fail passed=N failed=N flaky=N
"""
import json
import subprocess
import sys


def xcresult(path, *args):
    out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", *args, "--path", path, "--compact"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit(f"xcresulttool 失敗: {out.stderr.strip()}")
    return json.loads(out.stdout)


def collect(node, suite, rows):
    kind = node.get("nodeType")
    name = node.get("name", "")
    if kind == "Test Case":
        # 再試行された場合、Repetition の子ノードに、各回の結果が入る。
        reps = [c for c in node.get("children", []) if c.get("nodeType") == "Repetition"]
        failed_reps = [r for r in reps if r.get("result") not in ("Passed", "Skipped")]
        flaky = node.get("result") == "Passed" and bool(failed_reps)
        rows.append({
            "suite": suite, "name": name, "result": node.get("result", "?"),
            "seconds": float(node.get("durationInSeconds") or 0), "flaky": flaky,
            "retries": len(reps),
        })
        return
    next_suite = name if kind == "Test Suite" else suite
    for child in node.get("children", []):
        collect(child, next_suite, rows)


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        raise SystemExit(__doc__)
    path, out_md = args[0], args[1]
    exit_code = int(args[args.index("--exit-code") + 1]) if "--exit-code" in args else None
    wall = float(args[args.index("--wall-seconds") + 1]) if "--wall-seconds" in args else None

    summary = xcresult(path, "summary")
    tests = xcresult(path, "tests")
    rows = []
    for node in tests.get("testNodes", []):
        collect(node, "", rows)

    passed = sum(1 for r in rows if r["result"] == "Passed")
    failed = [r for r in rows if r["result"] == "Failed"]
    flaky = [r for r in rows if r["flaky"]]
    total = len(rows)
    status = "pass" if not failed and summary.get("result") == "Passed" else "fail"
    xc_wall = summary.get("finishTime", 0) - summary.get("startTime", 0)
    device = ", ".join(sorted({f'{d["device"]["deviceName"]} ({d["device"]["osVersion"]})'
                               for d in summary.get("devicesAndConfigurations", [])})) or "?"

    lines = ["# テスト結果の要約（ゲート: xcodebuild test）", ""]
    lines.append(f"- 判定: **{'成功' if status == 'pass' else '失敗'}**")
    lines.append(f"- 件数: {total} 件（成功 {passed} / 失敗 {len(failed)} / 再試行で成功した不安定なテスト {len(flaky)}）")
    lines.append(f"- テスト実行の時間: {xc_wall:.0f} 秒" + (f"（ビルドを含む全体: {wall:.0f} 秒）" if wall else ""))
    lines.append(f"- 端末: {device}（並列なし）")
    if exit_code is not None:
        lines.append(f"- xcodebuild の終了コード: {exit_code}")
    lines.append("")

    if failed:
        lines += ["## 失敗したテスト", ""]
        by_name = {}
        for failure in summary.get("testFailures", []):
            by_name.setdefault(failure.get("testName", ""), []).append(failure.get("failureText", ""))
        for r in failed:
            lines.append(f"- `{r['suite']}/{r['name']}` ({r['seconds']:.1f} 秒)")
            for text in by_name.get(r["name"], [])[:2]:
                lines.append(f"  - {text.strip().splitlines()[0][:300] if text.strip() else '(メッセージなし)'}")
        lines.append("")
    if flaky:
        lines += ["## 不安定なテスト（1 回失敗して、再試行で成功）", ""]
        for r in flaky:
            lines.append(f"- `{r['suite']}/{r['name']}`（試行 {r['retries']} 回）")
        lines.append("")

    lines += ["## 遅いテスト（上位 10 件）", "", "| 秒 | テスト |", "|---|---|"]
    for r in sorted(rows, key=lambda r: -r["seconds"])[:10]:
        lines.append(f"| {r['seconds']:.1f} | `{r['suite']}/{r['name']}` |")
    ui = sum(r["seconds"] for r in rows if "UITests" in r["suite"])
    lines += ["", f"UI テストの所要時間の合計: {ui:.0f} 秒（{sum(1 for r in rows if 'UITests' in r['suite'])} 件）。"
              " UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。", ""]

    lines += ["## 全テスト", "", "| 結果 | 秒 | テスト |", "|---|---|---|"]
    for r in sorted(rows, key=lambda r: (r["suite"], r["name"])):
        mark = r["result"] + ("（不安定）" if r["flaky"] else "")
        lines.append(f"| {mark} | {r['seconds']:.1f} | `{r['suite']}/{r['name']}` |")
    lines.append("")

    with open(out_md, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"status={status} passed={passed} failed={len(failed)} flaky={len(flaky)}")


main()

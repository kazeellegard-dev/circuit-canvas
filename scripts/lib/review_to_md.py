#!/usr/bin/env python3
"""Codex のレビュー結果（review.json）を、人が読む Markdown にする。

使い方: review_to_md.py REVIEW_JSON OUT_MD BASE HEAD [GATE_SUMMARY_MD]
標準出力に 1 行: status=... blocker=N major=N minor=N suggestion=N
"""
import json
import sys

AREA = {"implementation": "実装", "test-content": "テストの内容", "test-results": "テストの結果"}
SEVERITY_ORDER = ["blocker", "major", "minor", "suggestion"]
KIND = {"defect": "不具合", "improvement": "改善提案"}


def main():
    if len(sys.argv) < 5:
        raise SystemExit(__doc__)
    review_json, out_md, base, head = sys.argv[1:5]
    gate_md = sys.argv[5] if len(sys.argv) > 5 else None
    with open(review_json, encoding="utf-8") as f:
        data = json.load(f)
    findings = data.get("findings", [])
    counts = {s: sum(1 for x in findings if x["severity"] == s) for s in SEVERITY_ORDER}

    lines = [f"# Codex レビュー（{base}..{head}）", ""]
    lines.append(f"- 判定: **{'承認' if data['status'] == 'approve' else '要修正'}**"
                 f"（blocker {counts['blocker']} / major {counts['major']} / minor {counts['minor']} / 提案 {counts['suggestion']}）")
    lines.append("- レビュー担当: Codex（読み取り専用）。実装とテストの修正は Claude、テストの実行はスクリプト。")
    lines += ["", "## 所見", "", data["summary"].strip(), ""]

    for area, title in AREA.items():
        items = [x for x in findings if x["area"] == area]
        if not items:
            continue
        lines += [f"## {title}", ""]
        for x in sorted(items, key=lambda x: SEVERITY_ORDER.index(x["severity"])):
            where = f"`{x['file']}:{x['line']}`" if x["file"] and x["line"] else (f"`{x['file']}`" if x["file"] else "")
            lines.append(f"### [{x['severity']}] {x['title']}（{KIND[x['kind']]}）")
            if where:
                lines.append(f"- 場所: {where}")
            lines.append(f"- 内容: {x['detail'].strip()}")
            lines.append(f"- 提案: {x['suggestion'].strip()}")
            lines.append("")
    if data.get("verified"):
        lines += ["## 確認して問題がなかった点", ""] + [f"- {v}" for v in data["verified"]] + [""]
    if data.get("not_reviewed"):
        lines += ["## 確認できなかった点", ""] + [f"- {v}" for v in data["not_reviewed"]] + [""]
    if gate_md:
        lines += ["## 参考: テスト結果の要約", "", f"`{gate_md}` を参照。", ""]

    with open(out_md, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"status={data['status']} blocker={counts['blocker']} major={counts['major']} "
          f"minor={counts['minor']} suggestion={counts['suggestion']}")


main()

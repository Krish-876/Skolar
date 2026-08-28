"""
bench/score.py -- score one or more bench/run.py result JSONL files and print
a comparison table.

Metrics: accuracy, macro-F1, parse-failure rate, and total prompt +
completion tokens. Parse failures (prediction is null) are never dropped from
the denominator -- they count against accuracy and macro-F1 like any other
wrong answer, and are additionally reported as their own rate so a bad prompt
can be told apart from a bad model.

Usage:
    python bench/score.py results/a.jsonl results/b.jsonl
"""

import argparse
import json
from pathlib import Path


def load_results(path: Path) -> list[dict]:
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def _f1_for_label(rows: list[dict], label: str) -> float:
    tp = sum(1 for r in rows if r["gold"] == label and r.get("prediction") == label)
    fp = sum(1 for r in rows if r.get("prediction") == label and r["gold"] != label)
    fn = sum(1 for r in rows if r["gold"] == label and r.get("prediction") != label)

    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    if precision + recall == 0:
        return 0.0
    return 2 * precision * recall / (precision + recall)


def compute_metrics(rows: list[dict]) -> dict:
    n = len(rows)
    if n == 0:
        return {
            "n": 0, "accuracy": 0.0, "macro_f1": 0.0,
            "parse_failures": 0, "parse_failure_rate": 0.0,
            "prompt_tokens": 0, "completion_tokens": 0,
        }

    parse_failures = sum(1 for r in rows if r.get("prediction") is None)
    correct = sum(1 for r in rows if r.get("prediction") is not None and r["prediction"] == r["gold"])

    labels = sorted({r["gold"] for r in rows} | {r["prediction"] for r in rows if r.get("prediction") is not None})
    f1_scores = [_f1_for_label(rows, label) for label in labels]
    macro_f1 = sum(f1_scores) / len(f1_scores) if f1_scores else 0.0

    prompt_tokens = sum(r.get("prompt_tokens") or 0 for r in rows)
    completion_tokens = sum(r.get("completion_tokens") or 0 for r in rows)

    return {
        "n": n,
        "accuracy": correct / n,
        "macro_f1": macro_f1,
        "parse_failures": parse_failures,
        "parse_failure_rate": parse_failures / n,
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
    }


def format_table(named_metrics: list[tuple[str, dict]]) -> str:
    headers = ["file", "n", "accuracy", "macro_f1", "parse_fail_rate", "prompt_tok", "completion_tok"]
    rows = [headers]
    for name, m in named_metrics:
        rows.append([
            name,
            str(m["n"]),
            f"{m['accuracy']:.4f}",
            f"{m['macro_f1']:.4f}",
            f"{m['parse_failure_rate']:.4f}",
            str(m["prompt_tokens"]),
            str(m["completion_tokens"]),
        ])

    widths = [max(len(row[col]) for row in rows) for col in range(len(headers))]
    lines = []
    for row_idx, row in enumerate(rows):
        lines.append("  ".join(cell.ljust(widths[col]) for col, cell in enumerate(row)))
        if row_idx == 0:
            lines.append("  ".join("-" * widths[col] for col in range(len(headers))))
    return "\n".join(lines)


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Score bench/run.py result JSONL files.")
    p.add_argument("results", nargs="+", type=Path, help="One or more results JSONL files.")
    return p


def main(argv: list[str] | None = None) -> None:
    args = build_arg_parser().parse_args(argv)

    named_metrics = [(str(path), compute_metrics(load_results(path))) for path in args.results]
    print(format_table(named_metrics))


if __name__ == "__main__":
    main()

"""Unit tests for bench/score.py -- metrics on a synthetic results file."""

import json
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from bench.score import compute_metrics, format_table, load_results  # noqa: E402


def _write_jsonl(path: Path, rows: list[dict]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row) + "\n")


def test_load_results_round_trips(tmp_path):
    rows = [
        {"id": 0, "gold": "positive", "prediction": "positive", "prompt_tokens": 10, "completion_tokens": 1},
        {"id": 1, "gold": "negative", "prediction": "negative", "prompt_tokens": 12, "completion_tokens": 1},
    ]
    path = tmp_path / "results.jsonl"
    _write_jsonl(path, rows)

    assert load_results(path) == rows


def test_compute_metrics_all_correct():
    rows = [
        {"gold": "positive", "prediction": "positive", "prompt_tokens": 10, "completion_tokens": 1},
        {"gold": "negative", "prediction": "negative", "prompt_tokens": 10, "completion_tokens": 1},
    ]
    metrics = compute_metrics(rows)

    assert metrics["n"] == 2
    assert metrics["accuracy"] == 1.0
    assert metrics["macro_f1"] == 1.0
    assert metrics["parse_failures"] == 0
    assert metrics["parse_failure_rate"] == 0.0
    assert metrics["prompt_tokens"] == 20
    assert metrics["completion_tokens"] == 2


def test_compute_metrics_counts_parse_failures_separately_from_wrong_answers():
    rows = [
        {"gold": "positive", "prediction": "negative", "prompt_tokens": 1, "completion_tokens": 1},  # wrong
        {"gold": "positive", "prediction": None, "prompt_tokens": 1, "completion_tokens": 1},         # parse failure
        {"gold": "positive", "prediction": "positive", "prompt_tokens": 1, "completion_tokens": 1},   # correct
    ]
    metrics = compute_metrics(rows)

    assert metrics["n"] == 3
    # Both the wrong answer and the parse failure count against accuracy --
    # neither is silently dropped from the denominator.
    assert metrics["accuracy"] == 1 / 3
    assert metrics["parse_failures"] == 1
    assert metrics["parse_failure_rate"] == 1 / 3


def test_compute_metrics_empty_results():
    metrics = compute_metrics([])
    assert metrics["n"] == 0
    assert metrics["accuracy"] == 0.0
    assert metrics["macro_f1"] == 0.0
    assert metrics["parse_failure_rate"] == 0.0


def test_compute_metrics_macro_f1_penalizes_missing_class():
    # Gold has two classes; predictions only ever guess one of them --
    # macro-F1 should be well below 1.0 even though "positive" accuracy is high.
    rows = [
        {"gold": "positive", "prediction": "positive"},
        {"gold": "positive", "prediction": "positive"},
        {"gold": "negative", "prediction": "positive"},
    ]
    metrics = compute_metrics(rows)

    assert metrics["accuracy"] == 2 / 3
    assert metrics["macro_f1"] < metrics["accuracy"]


def test_format_table_lists_every_file_and_metric_columns():
    named_metrics = [
        ("a.jsonl", compute_metrics([{"gold": "x", "prediction": "x", "prompt_tokens": 5, "completion_tokens": 1}])),
        ("b.jsonl", compute_metrics([{"gold": "x", "prediction": None, "prompt_tokens": 5, "completion_tokens": 1}])),
    ]
    table = format_table(named_metrics)

    assert "a.jsonl" in table
    assert "b.jsonl" in table
    assert "accuracy" in table
    assert "macro_f1" in table
    assert "parse_fail_rate" in table

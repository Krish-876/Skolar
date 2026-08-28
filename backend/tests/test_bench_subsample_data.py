"""Unit tests for bench/subsample_data.py -- stratified train.jsonl subsampling."""

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from bench.subsample_data import stratified_subsample  # noqa: E402


def _records(label_counts: dict) -> list[dict]:
    records = []
    i = 0
    for label, count in label_counts.items():
        for _ in range(count):
            records.append({"idx": i, "sentence": f"s{i}", "label": label})
            i += 1
    return records


def test_under_cap_returned_whole_unchanged():
    records = _records({0: 30, 1: 20})
    result = stratified_subsample(records, cap=100, seed=0)
    assert result == records


def test_over_cap_respects_cap():
    records = _records({0: 4000, 1: 6000})
    result = stratified_subsample(records, cap=1000, seed=0)
    assert len(result) == 1000


def test_over_cap_preserves_label_proportions():
    records = _records({0: 4000, 1: 6000})  # 40/60 split
    result = stratified_subsample(records, cap=1000, seed=0)

    counts = {0: 0, 1: 0}
    for r in result:
        counts[r["label"]] += 1

    assert counts[0] == 400
    assert counts[1] == 600


def test_over_cap_deterministic_given_same_seed():
    records = _records({0: 4000, 1: 6000, "x": 500})
    result_a = stratified_subsample(records, cap=777, seed=0)
    result_b = stratified_subsample(records, cap=777, seed=0)
    assert result_a == result_b


def test_different_seeds_can_select_different_rows():
    records = _records({0: 4000, 1: 6000})
    result_a = stratified_subsample(records, cap=1000, seed=0)
    result_b = stratified_subsample(records, cap=1000, seed=1)
    assert [r["idx"] for r in result_a] != [r["idx"] for r in result_b]


def test_uneven_label_counts_use_largest_remainder_rounding():
    # 3 labels, cap doesn't divide evenly -- exact per-label counts still sum to cap.
    records = _records({"a": 100, "b": 100, "c": 101})
    result = stratified_subsample(records, cap=10, seed=0)
    assert len(result) == 10


def test_output_preserves_original_relative_order():
    records = _records({0: 4000, 1: 6000})
    result = stratified_subsample(records, cap=1000, seed=0)
    indices = [r["idx"] for r in result]
    assert indices == sorted(indices)

"""
bench/subsample_data.py -- the script that produced bench/data/*/train.jsonl.

The retrieval corpus a bench run draws its candidate pool from (see
select.py's pool_multiplier * k, default pool ~50) only ever needs a few
thousand examples to be a generous source -- it doesn't need the full
GLUE/TREC training split. This script subsamples each dataset's train.jsonl
down to at most CAP examples, stratified by label so the class distribution
is preserved, using a fixed numpy RandomState seed so the result is
reproducible and auditable. val.jsonl and test.jsonl are never touched.

Run once, from backend/:
    python bench/subsample_data.py

This is idempotent in the sense that re-running it against an
already-subsampled file (<= CAP rows) is a no-op copy-through; it's meant to
be re-run only against a freshly re-vendored full-size train.jsonl (see
bench/README.md's fetch step).
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from bench.datasets import DATASET_NAMES, DATA_DIR, load_jsonl, raw_label, split_path  # noqa: E402

CAP = 5000
SEED = 0


def stratified_subsample(records: list[dict], cap: int, seed: int) -> list[dict]:
    """Subsamples records to at most `cap` rows, preserving the original
    per-label proportions (largest-remainder rounding so per-label target
    counts sum exactly to min(cap, len(records))). Deterministic given seed.
    Records already at or under the cap are returned unchanged (whole)."""
    n = len(records)
    if n <= cap:
        return list(records)

    groups: dict[object, list[int]] = {}
    for i, r in enumerate(records):
        groups.setdefault(raw_label(r), []).append(i)

    labels = sorted(groups.keys(), key=str)
    counts = {label: len(groups[label]) for label in labels}

    raw_targets = {label: cap * counts[label] / n for label in labels}
    targets = {label: int(np.floor(raw_targets[label])) for label in labels}
    remainder = cap - sum(targets.values())

    # Largest-remainder method: give the leftover slots to the labels with
    # the biggest fractional part, tie-broken by label name for determinism.
    by_fraction = sorted(
        labels, key=lambda label: (-(raw_targets[label] - targets[label]), str(label))
    )
    for label in by_fraction[:remainder]:
        targets[label] += 1

    rng = np.random.RandomState(seed)  # noqa: NPY002 -- fixed-seed reproducible subsampling, not general RNG use
    selected_indices: list[int] = []
    for label in labels:
        pool = groups[label]
        k = min(targets[label], len(pool))
        chosen = rng.choice(pool, size=k, replace=False)
        selected_indices.extend(int(i) for i in chosen)

    selected_indices.sort()
    return [records[i] for i in selected_indices]


def write_jsonl(path: Path, records: list[dict]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")


def subsample_dataset(dataset: str, cap: int, seed: int, data_dir: Path) -> tuple[int, int]:
    path = split_path(dataset, "train", data_dir=data_dir)
    records = load_jsonl(path)
    before = len(records)
    subsampled = stratified_subsample(records, cap, seed)
    write_jsonl(path, subsampled)
    return before, len(subsampled)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cap", type=int, default=CAP)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    args = parser.parse_args(argv)

    print(f"{'dataset':<8} {'before':>8} {'after':>8}")
    for dataset in DATASET_NAMES:
        before, after = subsample_dataset(dataset, args.cap, args.seed, args.data_dir)
        print(f"{dataset:<8} {before:>8} {after:>8}")


if __name__ == "__main__":
    main()

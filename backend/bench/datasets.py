"""
Loading and per-dataset text/label handling for the bench/ harness.

Datasets are the four used by Diverse-ICL (SIGIR'25) -- SST2, COLA, RTE, TREC --
vendored as plain JSONL under bench/data/<DATASET>/{train,val,test}.jsonl.
See bench/README.md for provenance and how to re-fetch them.

We use these datasets and the retrieve-then-rerank *method*, not the paper's
models or hyperparameters -- see bench/README.md.
"""

import json
from pathlib import Path
from typing import Callable

DATA_DIR = Path(__file__).resolve().parent / "data"

DATASET_NAMES: tuple[str, ...] = ("sst2", "cola", "rte", "trec")
SPLIT_NAMES: tuple[str, ...] = ("train", "val", "test")


def _text_sst2(sample: dict) -> str:
    return sample["sentence"]


def _text_cola(sample: dict) -> str:
    return sample["sentence"]


def _text_rte(sample: dict) -> str:
    # Matches Diverse-ICL's extract_text: sentence1 + " " + sentence2, stripped.
    return f"{sample['sentence1']} {sample['sentence2']}".strip()


def _text_trec(sample: dict) -> str:
    return sample["text"]


_TEXT_EXTRACTORS: dict[str, Callable[[dict], str]] = {
    "sst2": _text_sst2,
    "cola": _text_cola,
    "rte": _text_rte,
    "trec": _text_trec,
}

# The id field name differs per dataset file (SST2/COLA/RTE use "idx", TREC uses "index").
_ID_FIELDS: dict[str, str] = {
    "sst2": "idx",
    "cola": "idx",
    "rte": "idx",
    "trec": "index",
}

# Fixed label maps per the task spec. TREC has no fixed map -- its labels are
# already free-text category names, and the valid set is derived from the
# data itself (see trec_label_map) rather than hardcoded here.
_FIXED_LABEL_MAPS: dict[str, dict[int, str]] = {
    "sst2": {0: "negative", 1: "positive"},
    "cola": {0: "unacceptable", 1: "acceptable"},
    "rte": {0: "entailment", 1: "not entailment"},
}


def _dataset_dir(dataset: str) -> str:
    # Vendored folder names are upper-cased (SST2/COLA/RTE/TREC).
    return dataset.upper()


def _check_dataset(dataset: str) -> str:
    dataset = dataset.lower()
    if dataset not in DATASET_NAMES:
        raise ValueError(f"Unknown dataset {dataset!r}. Expected one of {DATASET_NAMES}.")
    return dataset


def load_jsonl(path: Path) -> list[dict]:
    records = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            records.append(json.loads(line))
    return records


def split_path(dataset: str, split: str, data_dir: Path | None = None) -> Path:
    dataset = _check_dataset(dataset)
    if split not in SPLIT_NAMES:
        raise ValueError(f"Unknown split {split!r}. Expected one of {SPLIT_NAMES}.")
    base = data_dir if data_dir is not None else DATA_DIR
    return base / _dataset_dir(dataset) / f"{split}.jsonl"


def load_split(dataset: str, split: str, data_dir: Path | None = None) -> list[dict]:
    path = split_path(dataset, split, data_dir)
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. See backend/bench/README.md for how to fetch/vendor "
            "the Diverse-ICL datasets."
        )
    return load_jsonl(path)


def extract_text(dataset: str, sample: dict) -> str:
    dataset = _check_dataset(dataset)
    return _TEXT_EXTRACTORS[dataset](sample)


def sample_id(dataset: str, sample: dict) -> int:
    dataset = _check_dataset(dataset)
    return int(sample[_ID_FIELDS[dataset]])


def raw_label(sample: dict) -> object:
    # All four datasets store the gold label under "label".
    return sample["label"]


def trec_label_map(records: list[dict]) -> dict[str, str]:
    """TREC's labels are already free-text category names (e.g. 'entity',
    'human'). The valid set is derived from the data itself -- not from
    memory -- so a change to the vendored file is automatically reflected."""
    labels = sorted({r["label"] for r in records})
    return {label: label for label in labels}


def label_map(dataset: str, train_records: list[dict] | None = None) -> dict:
    """Maps a sample's raw `label` value to its human-readable class name.

    train_records is required for TREC (its map is derived from the data);
    ignored for the other three datasets, which have a fixed map.
    """
    dataset = _check_dataset(dataset)
    if dataset in _FIXED_LABEL_MAPS:
        return dict(_FIXED_LABEL_MAPS[dataset])
    if train_records is None:
        raise ValueError("trec's label map must be derived from data -- pass train_records.")
    return trec_label_map(train_records)


def gold_label(dataset: str, sample: dict, label_map_: dict) -> str:
    return label_map_[raw_label(sample)]

"""Unit tests for bench/datasets.py -- jsonl loading and per-dataset text/label handling."""

import json
import sys
from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from bench.datasets import (  # noqa: E402
    extract_text,
    gold_label,
    label_map,
    load_jsonl,
    load_split,
    raw_label,
    sample_id,
    split_path,
    trec_label_map,
)


def _write_jsonl(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")


@pytest.fixture
def synthetic_data_dir(tmp_path):
    sst2 = [
        {"idx": 0, "sentence": "a great movie", "label": 1},
        {"idx": 1, "sentence": "a terrible movie", "label": 0},
    ]
    cola = [
        {"idx": 0, "sentence": "This is grammatical.", "label": 1},
        {"idx": 1, "sentence": "Grammatical is this not.", "label": 0},
    ]
    rte = [
        {"idx": 0, "sentence1": "It rained all day.", "sentence2": "The ground was wet.", "label": 0},
        {"idx": 1, "sentence1": "The cat is black.", "sentence2": "The sky is blue.", "label": 1},
    ]
    trec = [
        {"index": 0, "text": "What is the capital of France?", "label": "location"},
        {"index": 1, "text": "Who wrote Hamlet?", "label": "human"},
        {"index": 2, "text": "How many continents are there?", "label": "numeric"},
    ]

    for name, split, records in [
        ("SST2", "train", sst2), ("SST2", "test", sst2),
        ("COLA", "train", cola), ("COLA", "test", cola),
        ("RTE", "train", rte), ("RTE", "test", rte),
        ("TREC", "train", trec), ("TREC", "test", trec),
    ]:
        _write_jsonl(tmp_path / name / f"{split}.jsonl", records)

    return tmp_path


# ── load_jsonl / load_split ───────────────────────────────────────────────────

def test_load_jsonl_skips_blank_lines(tmp_path):
    path = tmp_path / "sample.jsonl"
    path.write_text('{"a": 1}\n\n{"a": 2}\n', encoding="utf-8")

    records = load_jsonl(path)

    assert records == [{"a": 1}, {"a": 2}]


def test_load_split_reads_vendored_layout(synthetic_data_dir):
    records = load_split("sst2", "train", data_dir=synthetic_data_dir)
    assert records == [
        {"idx": 0, "sentence": "a great movie", "label": 1},
        {"idx": 1, "sentence": "a terrible movie", "label": 0},
    ]


def test_load_split_missing_file_raises_clear_error(tmp_path):
    with pytest.raises(FileNotFoundError, match="bench/README.md"):
        load_split("sst2", "train", data_dir=tmp_path)


def test_split_path_uses_uppercase_dataset_dir(tmp_path):
    path = split_path("sst2", "test", data_dir=tmp_path)
    assert path == tmp_path / "SST2" / "test.jsonl"


def test_load_split_rejects_unknown_dataset(tmp_path):
    with pytest.raises(ValueError, match="Unknown dataset"):
        load_split("not_a_dataset", "train", data_dir=tmp_path)


def test_load_split_rejects_unknown_split(tmp_path):
    with pytest.raises(ValueError, match="Unknown split"):
        load_split("sst2", "not_a_split", data_dir=tmp_path)


# ── extract_text ───────────────────────────────────────────────────────────────

def test_extract_text_sst2():
    assert extract_text("sst2", {"sentence": "hello world"}) == "hello world"


def test_extract_text_cola():
    assert extract_text("cola", {"sentence": "hello world"}) == "hello world"


def test_extract_text_rte_joins_both_sentences():
    sample = {"sentence1": "Premise text.", "sentence2": "Hypothesis text."}
    assert extract_text("rte", sample) == "Premise text. Hypothesis text."


def test_extract_text_trec():
    assert extract_text("trec", {"text": "What is this?"}) == "What is this?"


# ── sample_id ──────────────────────────────────────────────────────────────────

def test_sample_id_uses_idx_for_sst2_cola_rte():
    assert sample_id("sst2", {"idx": 7}) == 7
    assert sample_id("cola", {"idx": 7}) == 7
    assert sample_id("rte", {"idx": 7}) == 7


def test_sample_id_uses_index_for_trec():
    assert sample_id("trec", {"index": 9}) == 9


# ── label_map / gold_label ────────────────────────────────────────────────────

def test_label_map_sst2_fixed():
    assert label_map("sst2") == {0: "negative", 1: "positive"}


def test_label_map_cola_fixed():
    assert label_map("cola") == {0: "unacceptable", 1: "acceptable"}


def test_label_map_rte_fixed():
    assert label_map("rte") == {0: "entailment", 1: "not entailment"}


def test_label_map_trec_requires_train_records():
    with pytest.raises(ValueError, match="train_records"):
        label_map("trec")


def test_trec_label_map_derived_from_data_not_memory():
    # Standard TREC-6 categories are ABBR/ENTY/DESC/HUM/LOC/NUM -- deliberately
    # use different label text here to prove the map comes from the data.
    records = [
        {"index": 0, "text": "q1", "label": "zzz_custom_category"},
        {"index": 1, "text": "q2", "label": "another_category"},
        {"index": 2, "text": "q3", "label": "zzz_custom_category"},
    ]
    assert trec_label_map(records) == {
        "zzz_custom_category": "zzz_custom_category",
        "another_category": "another_category",
    }


def test_gold_label_sst2(synthetic_data_dir):
    train = load_split("sst2", "train", data_dir=synthetic_data_dir)
    lm = label_map("sst2", train)
    assert gold_label("sst2", train[0], lm) == "positive"
    assert gold_label("sst2", train[1], lm) == "negative"


def test_gold_label_trec_from_derived_map(synthetic_data_dir):
    train = load_split("trec", "train", data_dir=synthetic_data_dir)
    lm = label_map("trec", train)
    assert gold_label("trec", train[0], lm) == "location"
    assert gold_label("trec", train[1], lm) == "human"


def test_raw_label_reads_label_field():
    assert raw_label({"label": 1, "sentence": "x"}) == 1
    assert raw_label({"label": "human", "text": "x"}) == "human"

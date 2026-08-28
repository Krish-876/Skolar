"""
Golden-value tests for the pyq.rag refactor (backend/pyq/rag -> core/ingest/llm/store/services).

Expected values in backend/tests/fixtures/golden_values.json were captured by running
the ORIGINAL pre-refactor pipeline.py (git commit d27c0ae, the last commit before
06e2332 "refactor: split pipeline.py into core/ ingest/ llm/ store/ services/") against
the exact same fixed synthetic inputs used below, via a one-off script (not part of the
test suite). This file only reads that fixture and diffs it against the live refactored
modules -- no subprocess, no git, no network, no model download at test time.

No real embedding model is used — a fixed synthetic embedding matrix
(numpy RandomState seed 0) stands in for sentence-transformers output.
"""

import copy
import json
import sys
from pathlib import Path

import numpy as np
import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.core.mmr import cosine_sim, mmr  # noqa: E402
from pyq.rag.ingest.chunking import _deduplicate_questions, _make_chunks  # noqa: E402
from pyq.rag.llm.extraction import guess_exam_type_from_text  # noqa: E402
from pyq.rag.services.generate import _filter_by_exam_type  # noqa: E402

FIXTURE_PATH = Path(__file__).resolve().parent / "fixtures" / "golden_values.json"
GOLDEN = json.loads(FIXTURE_PATH.read_text())

# ── Fixed synthetic embedding matrix ──────────────────────────────────────────
# Must match the RandomState(0)/shape used when golden_values.json was generated.

_rng = np.random.RandomState(0)  # noqa: NPY002 -- deterministic golden fixture, not general RNG use
EMBEDDINGS = _rng.rand(12, 384).astype(np.float32)


# ── cosine_sim ─────────────────────────────────────────────────────────────────

def test_cosine_sim_matches_golden():
    for i in range(1, len(EMBEDDINGS)):
        expected = GOLDEN["cosine_sim_pairs"][i - 1]
        actual = cosine_sim(EMBEDDINGS[0], EMBEDDINGS[i])
        assert actual == pytest.approx(expected)


def test_cosine_sim_self_similarity_matches_golden():
    expected = GOLDEN["cosine_sim_self"]
    actual = cosine_sim(EMBEDDINGS[3], EMBEDDINGS[3])
    assert actual == pytest.approx(expected)
    assert actual == pytest.approx(1.0)


# ── mmr ────────────────────────────────────────────────────────────────────────

def _mmr_candidates() -> list[dict]:
    return [
        {"id": i, "question_text": f"question {i}", "marks": (i % 5) + 1}
        for i in range(len(EMBEDDINGS) - 1)
    ]


def test_mmr_matches_golden_no_seed():
    query = EMBEDDINGS[0]
    candidates = EMBEDDINGS[1:]

    actual = mmr(query, candidates, _mmr_candidates(), k=4, alpha=0.7)

    assert actual == GOLDEN["mmr_no_seed"]


def test_mmr_matches_golden_alpha_half():
    # Formerly "with_seed": mmr() no longer takes a seed (the seed shuffle it
    # used to apply was a no-op -- MMR's greedy argmax is deterministic given
    # a candidate pool, so permuting candidates can't change which one wins).
    # Per-worker variation now lives in services/generate.py's pool subsampling.
    query = EMBEDDINGS[0]
    candidates = EMBEDDINGS[1:]

    actual = mmr(query, candidates, _mmr_candidates(), alpha=0.5, k=3)

    assert actual == GOLDEN["mmr_with_seed"]


def test_mmr_matches_golden_k_larger_than_pool():
    query = EMBEDDINGS[0]
    candidates = EMBEDDINGS[1:5]

    actual = mmr(query, candidates, _mmr_candidates()[:4], alpha=0.7, k=10)

    assert actual == GOLDEN["mmr_k_larger_than_pool"]


# ── _make_chunks ────────────────────────────────────────────────────────────────

CHUNK_TEXT_SHORT = "The quick brown fox jumps over the lazy dog. " * 20
CHUNK_TEXT_LONG = "Exam question paragraph filler text, section marker. " * 500


@pytest.mark.parametrize(
    "case_name,text,size,overlap",
    [
        ("short_default", CHUNK_TEXT_SHORT, 6000, 500),   # defaults, text shorter than one chunk
        ("long_default", CHUNK_TEXT_LONG, 6000, 500),     # defaults, multiple overlapping chunks
        ("long_custom", CHUNK_TEXT_LONG, 1000, 100),      # custom size/overlap
        ("empty", "", 6000, 500),                         # empty text
    ],
)
def test_make_chunks_matches_golden(case_name, text, size, overlap):
    actual = _make_chunks(text, size=size, overlap=overlap)
    assert actual == GOLDEN["make_chunks"][case_name]


def test_make_chunks_matches_golden_default_args():
    actual = _make_chunks(CHUNK_TEXT_LONG)
    assert actual == GOLDEN["make_chunks_default_args"]


# ── _deduplicate_questions ───────────────────────────────────────────────────────

def _dedup_fixture() -> list[dict]:
    return [
        {"question_text": "Explain the working of a binary search tree in detail", "confidence_score": 0.9},
        {"question_text": "Explain the working of a binary search tree in detail here", "confidence_score": 0.95},
        {"question_text": "Describe Dijkstra's shortest path algorithm with an example", "confidence_score": 1.0},
        {"question_text": "What is the time complexity of merge sort?", "confidence_score": 0.6},
        {"question_text": "What is the time complexity of merge sort algorithm?", "confidence_score": 0.4},
        {"question_text": "Totally unrelated question about TCP handshake", "confidence_score": 1.0},
    ]


def test_deduplicate_questions_matches_golden():
    actual = _deduplicate_questions(copy.deepcopy(_dedup_fixture()))
    assert actual == GOLDEN["deduplicate_questions"]


def test_deduplicate_questions_matches_golden_no_duplicates():
    fixture = [
        {"question_text": "unique text one", "confidence_score": 1.0},
        {"question_text": "completely different text two", "confidence_score": 1.0},
    ]
    actual = _deduplicate_questions(copy.deepcopy(fixture))
    assert actual == GOLDEN["deduplicate_questions_no_duplicates"]


# ── _filter_by_exam_type ─────────────────────────────────────────────────────────

def _exam_type_fixture() -> list[dict]:
    exam_types = ["quiz1", "midsem", "quiz2", "compre", "generated", None]
    return [
        {"id": i, "question_text": f"question {i}", "exam_type": exam_types[i % len(exam_types)]}
        for i in range(len(EMBEDDINGS))
    ]


@pytest.mark.parametrize("exam_type", ["quiz1", "midsem", "quiz2", "compre", None, "unknown_type"])
def test_filter_by_exam_type_matches_golden(exam_type):
    questions = _exam_type_fixture()
    embeddings = EMBEDDINGS.copy()

    actual_q, actual_e = _filter_by_exam_type(copy.deepcopy(questions), embeddings.copy(), exam_type)

    key = "__none__" if exam_type is None else exam_type
    golden = GOLDEN["filter_by_exam_type"][key]
    expected_e = EMBEDDINGS[golden["indices"]]

    assert actual_q == golden["questions"]
    assert np.array_equal(actual_e, expected_e)


# ── guess_exam_type_from_text ─────────────────────────────────────────────────────

@pytest.mark.parametrize("text,expected", GOLDEN["guess_exam_type"])
def test_guess_exam_type_from_text_matches_golden(text, expected):
    actual = guess_exam_type_from_text(text)
    assert actual == expected


def test_guess_exam_type_from_text_only_scans_first_2000_chars():
    text = ("x" * 2000) + "compre"
    actual = guess_exam_type_from_text(text)
    assert actual == GOLDEN["guess_exam_type_2000_cutoff"]
    assert actual is None

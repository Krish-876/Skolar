"""
Golden-value tests for the pyq.rag refactor (backend/pyq/rag -> core/ingest/llm/store/services).

For every dependency-free deterministic function under test, this file executes
the ORIGINAL pre-refactor pipeline.py (recovered from git history via `git show
HEAD:backend/pyq/rag/pipeline.py`) to compute expected values, then asserts the
refactored modules produce byte-identical results. This guards against
transcription drift introduced while splitting pipeline.py into submodules.

No real embedding model is used — a fixed synthetic embedding matrix
(numpy RandomState seed 0) stands in for sentence-transformers output.
"""

import copy
import subprocess
import sys
import types
from pathlib import Path

import numpy as np
import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

REPO_ROOT = Path(
    subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=str(BACKEND_DIR), capture_output=True, text=True, check=True,
    ).stdout.strip()
)


def _load_original_pipeline() -> types.ModuleType:
    """Load the pre-refactor pipeline.py straight from git HEAD into a throwaway
    module namespace, so we're comparing against the actual original code rather
    than a hand-transcribed copy of it."""
    source = subprocess.run(
        ["git", "show", "HEAD:backend/pyq/rag/pipeline.py"],
        cwd=str(REPO_ROOT), capture_output=True, text=True, check=True,
    ).stdout

    module = types.ModuleType("_original_pyq_rag_pipeline")
    module.__file__ = "<git HEAD:backend/pyq/rag/pipeline.py>"
    exec(compile(source, module.__file__, "exec"), module.__dict__)  # noqa: S102
    return module


original = _load_original_pipeline()

from pyq.rag.core.mmr import cosine_sim, mmr  # noqa: E402
from pyq.rag.ingest.chunking import _deduplicate_questions, _make_chunks  # noqa: E402
from pyq.rag.llm.extraction import guess_exam_type_from_text  # noqa: E402
from pyq.rag.services.generate import _filter_by_exam_type  # noqa: E402

# ── Fixed synthetic embedding matrix ──────────────────────────────────────────

_rng = np.random.RandomState(0)  # noqa: NPY002 -- deterministic golden fixture, not general RNG use
EMBEDDINGS = _rng.rand(12, 384).astype(np.float32)


# ── cosine_sim ─────────────────────────────────────────────────────────────────

def test_cosine_sim_matches_original():
    for i in range(1, len(EMBEDDINGS)):
        expected = original.cosine_sim(EMBEDDINGS[0], EMBEDDINGS[i])
        actual = cosine_sim(EMBEDDINGS[0], EMBEDDINGS[i])
        assert actual == pytest.approx(expected)


def test_cosine_sim_self_similarity_matches_original():
    expected = original.cosine_sim(EMBEDDINGS[3], EMBEDDINGS[3])
    actual = cosine_sim(EMBEDDINGS[3], EMBEDDINGS[3])
    assert actual == pytest.approx(expected)
    assert actual == pytest.approx(1.0)


# ── mmr ────────────────────────────────────────────────────────────────────────

def _mmr_candidates() -> list[dict]:
    return [
        {"id": i, "question_text": f"question {i}", "marks": (i % 5) + 1}
        for i in range(len(EMBEDDINGS) - 1)
    ]


def test_mmr_matches_original_no_seed():
    query = EMBEDDINGS[0]
    candidates = EMBEDDINGS[1:]

    expected = original.mmr(query, candidates, _mmr_candidates(), k=4, alpha=0.7)
    actual = mmr(query, candidates, _mmr_candidates(), k=4, alpha=0.7)

    assert actual == expected


def test_mmr_matches_original_with_seed():
    query = EMBEDDINGS[0]
    candidates = EMBEDDINGS[1:]

    expected = original.mmr(query, candidates, _mmr_candidates(), k=3, alpha=0.5, seed=42)
    actual = mmr(query, candidates, _mmr_candidates(), k=3, alpha=0.5, seed=42)

    assert actual == expected


def test_mmr_matches_original_k_larger_than_pool():
    query = EMBEDDINGS[0]
    candidates = EMBEDDINGS[1:5]

    expected = original.mmr(query, candidates, _mmr_candidates()[:4], k=10, seed=7)
    actual = mmr(query, candidates, _mmr_candidates()[:4], k=10, seed=7)

    assert actual == expected


# ── _make_chunks ────────────────────────────────────────────────────────────────

CHUNK_TEXT_SHORT = "The quick brown fox jumps over the lazy dog. " * 20
CHUNK_TEXT_LONG = "Exam question paragraph filler text, section marker. " * 500


@pytest.mark.parametrize(
    "text,size,overlap",
    [
        (CHUNK_TEXT_SHORT, 6000, 500),   # defaults, text shorter than one chunk
        (CHUNK_TEXT_LONG, 6000, 500),    # defaults, multiple overlapping chunks
        (CHUNK_TEXT_LONG, 1000, 100),    # custom size/overlap
        ("", 6000, 500),                 # empty text
    ],
)
def test_make_chunks_matches_original(text, size, overlap):
    expected = original._make_chunks(text, size=size, overlap=overlap)
    actual = _make_chunks(text, size=size, overlap=overlap)
    assert actual == expected


def test_make_chunks_matches_original_default_args():
    expected = original._make_chunks(CHUNK_TEXT_LONG)
    actual = _make_chunks(CHUNK_TEXT_LONG)
    assert actual == expected


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


def test_deduplicate_questions_matches_original():
    expected = original._deduplicate_questions(copy.deepcopy(_dedup_fixture()))
    actual = _deduplicate_questions(copy.deepcopy(_dedup_fixture()))
    assert actual == expected


def test_deduplicate_questions_matches_original_no_duplicates():
    fixture = [
        {"question_text": "unique text one", "confidence_score": 1.0},
        {"question_text": "completely different text two", "confidence_score": 1.0},
    ]
    expected = original._deduplicate_questions(copy.deepcopy(fixture))
    actual = _deduplicate_questions(copy.deepcopy(fixture))
    assert actual == expected


# ── _filter_by_exam_type ─────────────────────────────────────────────────────────

def _exam_type_fixture() -> list[dict]:
    exam_types = ["quiz1", "midsem", "quiz2", "compre", "generated", None]
    return [
        {"id": i, "question_text": f"question {i}", "exam_type": exam_types[i % len(exam_types)]}
        for i in range(len(EMBEDDINGS))
    ]


@pytest.mark.parametrize("exam_type", ["quiz1", "midsem", "quiz2", "compre", None, "unknown_type"])
def test_filter_by_exam_type_matches_original(exam_type):
    questions = _exam_type_fixture()
    embeddings = EMBEDDINGS.copy()

    expected_q, expected_e = original._filter_by_exam_type(copy.deepcopy(questions), embeddings.copy(), exam_type)
    actual_q, actual_e = _filter_by_exam_type(copy.deepcopy(questions), embeddings.copy(), exam_type)

    assert actual_q == expected_q
    assert np.array_equal(actual_e, expected_e)


# ── guess_exam_type_from_text ─────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "text",
    [
        "COMPRE EXAMINATION 2023 - Data Structures",
        "Mid-Sem Test - Artificial Intelligence",
        "mid sem examination paper",
        "midsem 2022 question paper",
        "Quiz1 - Operating Systems",
        "quiz-1 short test",
        "Quiz-I evaluation",
        "TEST1 paper for networks",
        "Quiz2 - Databases",
        "quiz-2 exam",
        "Quiz-II paper",
        "TEST2 examination",
        "TEST3 comprehensive paper",
        "test-3 final exam",
        "Randomly formatted document with no exam markers at all",
        "",
    ],
)
def test_guess_exam_type_from_text_matches_original(text):
    expected = original.guess_exam_type_from_text(text)
    actual = guess_exam_type_from_text(text)
    assert actual == expected


def test_guess_exam_type_from_text_only_scans_first_2000_chars():
    text = ("x" * 2000) + "compre"
    expected = original.guess_exam_type_from_text(text)
    actual = guess_exam_type_from_text(text)
    assert actual == expected
    assert actual is None

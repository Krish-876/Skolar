"""
Tests for services/generate.py's cross-worker deduplication and worker-count
configuration -- the fix for independent ThreadPoolExecutor workers producing
near-identical questions (observed: three variants of "which scheduling
algorithm causes starvation" in one batch of 10).
"""

import logging
import math
import sys
import threading
import zlib
from pathlib import Path

import numpy as np
import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import pyq.rag.services.generate as generate_mod  # noqa: E402

LOGGER_NAME = generate_mod.logger.name


# ── _max_workers_for ─────────────────────────────────────────────────────────

def test_max_workers_defaults_when_unset(monkeypatch):
    monkeypatch.delenv("GROQ_MAX_WORKERS", raising=False)
    assert generate_mod._max_workers_for(count=10, max_workers=None) == generate_mod._DEFAULT_MAX_WORKERS


def test_max_workers_reads_env_var(monkeypatch):
    monkeypatch.setenv("GROQ_MAX_WORKERS", "5")
    assert generate_mod._max_workers_for(count=10, max_workers=None) == 5


def test_max_workers_explicit_param_overrides_env(monkeypatch):
    monkeypatch.setenv("GROQ_MAX_WORKERS", "5")
    assert generate_mod._max_workers_for(count=10, max_workers=1) == 1


def test_max_workers_never_exceeds_count():
    assert generate_mod._max_workers_for(count=1, max_workers=10) == 1


def test_max_workers_at_least_one():
    assert generate_mod._max_workers_for(count=10, max_workers=0) == 1


# ── _dedup_generated ─────────────────────────────────────────────────────────

def test_dedup_generated_removes_near_duplicates(caplog):
    results = [
        {"question": "Which scheduling algorithm causes starvation under FCFS?", "marks": 2},
        {"question": "Which scheduling algorithm causes starvation under FCFS scheduling?", "marks": 2},
        {"question": "Explain the dining philosophers problem.", "marks": 3},
    ]
    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        deduped = generate_mod._dedup_generated(results, requested=3, label="test")

    assert len(deduped) == 2
    # Equal confidence_score (both default 1.0) -- _deduplicate_questions keeps
    # whichever it saw first among the near-duplicates.
    assert {r["question"] for r in deduped} == {
        "Which scheduling algorithm causes starvation under FCFS?",
        "Explain the dining philosophers problem.",
    }


def test_dedup_generated_logs_info_when_it_drops_below_requested(caplog):
    results = [
        {"question": "Which scheduling algorithm causes starvation under FCFS?", "marks": 2},
        {"question": "Which scheduling algorithm causes starvation under FCFS scheduling?", "marks": 2},
    ]
    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        deduped = generate_mod._dedup_generated(results, requested=2, label="test")

    assert len(deduped) == 1
    info_records = [r for r in caplog.records if r.levelno == logging.INFO]
    assert any("dedup" in r.message.lower() for r in info_records)


def test_dedup_generated_no_log_when_nothing_removed(caplog):
    results = [
        {"question": "Which scheduling algorithm causes starvation?", "marks": 2},
        {"question": "Explain the dining philosophers problem.", "marks": 3},
    ]
    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        deduped = generate_mod._dedup_generated(results, requested=2, label="test")

    assert len(deduped) == 2
    assert not any("dedup" in r.message.lower() for r in caplog.records)


def test_dedup_generated_preserves_other_keys():
    results = [{"question": "unique question text here", "marks": 4, "subject": "OS"}]
    deduped = generate_mod._dedup_generated(results, requested=1, label="test")
    assert deduped[0]["marks"] == 4
    assert deduped[0]["subject"] == "OS"


# ── _dedup_by_embedding ─────────────────────────────────────────────────────────

def _cosine_vectors(cosine: float) -> tuple[np.ndarray, np.ndarray]:
    """Two 2D unit vectors with an exact known cosine similarity, so tests
    can pin _dedup_by_embedding's threshold comparison precisely."""
    theta = math.acos(cosine)
    a = np.array([1.0, 0.0], dtype=np.float32)
    b = np.array([math.cos(theta), math.sin(theta)], dtype=np.float32)
    return a, b


class _FixedVectorsEmbedModel:
    def __init__(self, vector_by_text: dict):
        self._vector_by_text = vector_by_text

    def encode(self, texts):
        return np.array([self._vector_by_text[t] for t in texts], dtype=np.float32)


# The task's confirmed real-world case: two execve() questions differing only
# in punctuation-affected tokenization. _deduplicate_questions' word-overlap
# metric splits on whitespace without normalising punctuation, so tokens like
# "success?" vs "success" never match -- this pair survives that pass.
_EXECVE_A = "What does execve() do to the process image, its stack, heap, and open file descriptors upon success?"
_EXECVE_B = "What does execve do to the process image its stack heap and open file descriptors upon success"


def test_word_overlap_dedup_misses_the_execve_pair():
    from pyq.rag.ingest.chunking import _deduplicate_questions
    survivors = _deduplicate_questions([
        {"question_text": _EXECVE_A, "confidence_score": 1.0},
        {"question_text": _EXECVE_B, "confidence_score": 1.0},
    ])
    assert len(survivors) == 2  # word-overlap metric doesn't catch this pair


def test_dedup_by_embedding_catches_what_word_overlap_misses(monkeypatch, caplog):
    vec_a, vec_b = _cosine_vectors(0.891)  # the score observed for this exact pair
    monkeypatch.setattr(
        generate_mod, "get_embed_model",
        lambda: _FixedVectorsEmbedModel({_EXECVE_A: vec_a, _EXECVE_B: vec_b}),
    )

    results = [{"question": _EXECVE_A, "marks": 3}, {"question": _EXECVE_B, "marks": 3}]
    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        deduped = generate_mod._dedup_by_embedding(results, label="test")

    assert len(deduped) == 1
    assert deduped[0]["question"] == _EXECVE_A  # first occurrence kept

    log_text = " ".join(r.message for r in caplog.records)
    assert "0.891" in log_text
    assert _EXECVE_A in log_text
    assert _EXECVE_B in log_text


def test_dedup_by_embedding_keeps_pair_below_threshold(monkeypatch):
    vec_a = np.array([1.0, 0.0], dtype=np.float32)
    vec_b = np.array([0.0, 1.0], dtype=np.float32)  # orthogonal -- cosine 0.0
    monkeypatch.setattr(
        generate_mod, "get_embed_model",
        lambda: _FixedVectorsEmbedModel({"text A": vec_a, "text B": vec_b}),
    )

    results = [{"question": "text A"}, {"question": "text B"}]
    deduped = generate_mod._dedup_by_embedding(results, label="test")

    assert len(deduped) == 2


def test_dedup_by_embedding_respects_custom_threshold(monkeypatch):
    vec_a, vec_b = _cosine_vectors(0.891)
    monkeypatch.setattr(
        generate_mod, "get_embed_model",
        lambda: _FixedVectorsEmbedModel({"text A": vec_a, "text B": vec_b}),
    )

    def _results():
        return [{"question": "text A"}, {"question": "text B"}]

    default_result = generate_mod._dedup_by_embedding(_results(), label="test")
    strict_result = generate_mod._dedup_by_embedding(_results(), label="test", threshold=0.95)

    assert len(default_result) == 1   # 0.891 > default 0.85 -- dropped
    assert len(strict_result) == 2    # 0.891 < 0.95 -- kept


def test_dedup_by_embedding_single_item_returns_unchanged():
    assert generate_mod._dedup_by_embedding([{"question": "solo"}], label="test") == [{"question": "solo"}]


def test_dedup_by_embedding_empty_list_returns_unchanged():
    assert generate_mod._dedup_by_embedding([], label="test") == []


# ── _exclude_generated ──────────────────────────────────────────────────────────

def test_exclude_generated_removes_generated_doc_type():
    questions = [
        {"id": 1, "doc_type": "pyq"},
        {"id": 2, "doc_type": "generated"},
        {"id": 3, "doc_type": "pyq"},
    ]
    embeddings = np.arange(3 * 4).reshape(3, 4).astype(np.float32)

    kept_q, kept_e = generate_mod._exclude_generated(questions, embeddings)

    assert [q["id"] for q in kept_q] == [1, 3]
    assert np.array_equal(kept_e[0], embeddings[0])
    assert np.array_equal(kept_e[1], embeddings[2])


def test_exclude_generated_keeps_all_when_none_generated():
    questions = [{"id": 1, "doc_type": "pyq"}, {"id": 2, "doc_type": "solution"}]
    embeddings = np.arange(2 * 4).reshape(2, 4).astype(np.float32)

    kept_q, kept_e = generate_mod._exclude_generated(questions, embeddings)

    assert kept_q == questions
    assert np.array_equal(kept_e, embeddings)


def test_exclude_generated_treats_missing_doc_type_as_not_generated():
    questions = [{"id": 1}]
    embeddings = np.zeros((1, 4), dtype=np.float32)

    kept_q, _kept_e = generate_mod._exclude_generated(questions, embeddings)

    assert kept_q == questions


# ── run_generate_mcq_batch: end-to-end dedup through the real pipeline ────────

_FAKE_EMBED_DIM = 64  # must match _FakeEmbedModel's output dimensionality


def _fake_bank(n: int = 10) -> tuple[list[dict], np.ndarray]:
    rng = np.random.RandomState(0)  # noqa: NPY002 -- deterministic test fixture
    embeddings = rng.rand(n, _FAKE_EMBED_DIM).astype(np.float32)
    questions = [
        {
            "id": i, "question_text": f"bank question {i}", "marks": 3,
            "question_type": "short_answer", "exam_type": "midsem", "topic": "t",
        }
        for i in range(n)
    ]
    return questions, embeddings


class _FakeEmbedModel:
    """Deterministic bag-of-words embedding (feature hashing via zlib.crc32,
    not Python's hash() -- that's randomized per-process by PYTHONHASHSEED).
    Cosine similarity between outputs approximates word overlap, which is
    enough to tell the canned duplicate/distinct test question texts apart
    without loading the real SentenceTransformer model. At 64 dims, the
    _DISTINCT_TEXTS below hash to a max pairwise cosine of ~0.51 (verified),
    comfortably under the 0.85 dedup threshold; an exact-duplicate string
    always hashes to an identical vector (cosine 1.0)."""

    def encode(self, texts):
        vectors = []
        for text in texts:
            vec = np.zeros(_FAKE_EMBED_DIM, dtype=np.float32)
            for word in text.lower().split():
                vec[zlib.crc32(word.encode("utf-8")) % _FAKE_EMBED_DIM] += 1.0
            if not np.any(vec):
                vec[0] = 1.0  # avoid an all-zero vector for empty text
            vectors.append(vec)
        return np.array(vectors, dtype=np.float32)


def _patch_pipeline_deps(monkeypatch, questions, embeddings):
    monkeypatch.setattr(
        generate_mod, "load_bank_and_embeddings",
        lambda college, subject, academic_year=None: (questions, embeddings),
    )
    monkeypatch.setattr(generate_mod, "get_embed_model", lambda: _FakeEmbedModel())


def test_run_generate_mcq_batch_dedups_near_identical_worker_outputs(monkeypatch, caplog):
    questions, embeddings = _fake_bank()
    _patch_pipeline_deps(monkeypatch, questions, embeddings)

    def fake_generate_mcq(subject, examples):
        return {
            "question":      "Which scheduling algorithm causes starvation?",
            "options":       ["FCFS", "SJF", "RR", "Priority"],
            "correct_index": 3,
            "subject":       subject,
            "marks":         2,
        }

    monkeypatch.setattr(generate_mod, "generate_mcq", fake_generate_mcq)

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        result = generate_mod.run_generate_mcq_batch(
            subject="Operating Systems", college="BPHC", count=5, k=2, max_workers=3
        )

    assert len(result) == 1
    assert any("dedup" in r.message.lower() for r in caplog.records)


_DISTINCT_TEXTS = [
    "What is the primary difference between a mutex and a semaphore in operating systems?",
    "Explain how virtual memory paging reduces external fragmentation compared to segmentation.",
    "Describe the dining philosophers problem and one classic solution to avoid deadlock.",
    "How does a round robin scheduler determine the length of its time quantum?",
    "What role does the translation lookaside buffer play in address translation speed?",
]


def test_run_generate_mcq_batch_keeps_genuinely_distinct_worker_outputs(monkeypatch):
    questions, embeddings = _fake_bank()
    _patch_pipeline_deps(monkeypatch, questions, embeddings)

    call_count = [0]
    call_lock = threading.Lock()

    def fake_generate_mcq(subject, examples):
        with call_lock:
            idx = call_count[0]
            call_count[0] += 1
        return {
            "question":      _DISTINCT_TEXTS[idx % len(_DISTINCT_TEXTS)],
            "options":       ["A", "B", "C", "D"],
            "correct_index": 0,
            "subject":       subject,
            "marks":         2,
        }

    monkeypatch.setattr(generate_mod, "generate_mcq", fake_generate_mcq)

    result = generate_mod.run_generate_mcq_batch(
        subject="Operating Systems", college="BPHC", count=5, k=2, max_workers=3
    )

    assert len(result) == 5


def test_run_generate_mcq_batch_never_uses_generated_docs_as_examples(monkeypatch):
    questions, embeddings = _fake_bank(n=3)
    questions[0]["doc_type"] = "pyq"
    questions[1]["doc_type"] = "generated"  # must never be selected as an example
    questions[2]["doc_type"] = "pyq"
    _patch_pipeline_deps(monkeypatch, questions, embeddings)

    seen_example_ids: set[int] = set()

    def fake_generate_mcq(subject, examples):
        seen_example_ids.update(e["id"] for e in examples)
        return {
            "question": f"question about bank row {examples[0]['id']}",
            "options": ["A", "B", "C", "D"], "correct_index": 0,
            "subject": subject, "marks": 2,
        }

    monkeypatch.setattr(generate_mod, "generate_mcq", fake_generate_mcq)

    generate_mod.run_generate_mcq_batch(
        subject="Operating Systems", college="BPHC", count=2, k=2, max_workers=1
    )

    assert 1 not in seen_example_ids
    assert seen_example_ids == {0, 2}


def test_run_generate_mcq_batch_raises_with_underlying_error_on_total_failure(monkeypatch):
    questions, embeddings = _fake_bank()
    _patch_pipeline_deps(monkeypatch, questions, embeddings)

    def failing_generate_mcq(subject, examples):
        raise ValueError("model 'deprecated-model' has been decommissioned")

    monkeypatch.setattr(generate_mod, "generate_mcq", failing_generate_mcq)

    with pytest.raises(RuntimeError, match="decommissioned"):
        generate_mod.run_generate_mcq_batch(
            subject="Operating Systems", college="BPHC", count=3, k=2, max_workers=2
        )


# ── _backfill_shortfall (via run_generate_mcq_batch) ─────────────────────────

def test_run_generate_mcq_batch_backfills_after_dedup_shortfall(monkeypatch, caplog):
    # First 5 calls (the initial batch, one per worker) all return the same
    # duplicate text -- dedup collapses them to 1, leaving a shortfall of 4.
    # Every call after that (backfill attempts) returns a genuinely distinct
    # question, so backfill should top the batch back up to the requested 5.
    questions, embeddings = _fake_bank()
    _patch_pipeline_deps(monkeypatch, questions, embeddings)

    call_count = [0]
    call_lock = threading.Lock()

    def fake_generate_mcq(subject, examples):
        with call_lock:
            idx = call_count[0]
            call_count[0] += 1
        if idx < 5:
            text = "Which scheduling algorithm causes starvation?"
        else:
            text = _DISTINCT_TEXTS[(idx - 5) % len(_DISTINCT_TEXTS)]
        return {
            "question":      text,
            "options":       ["FCFS", "SJF", "RR", "Priority"],
            "correct_index": 3,
            "subject":       subject,
            "marks":         2,
        }

    monkeypatch.setattr(generate_mod, "generate_mcq", fake_generate_mcq)

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        result = generate_mod.run_generate_mcq_batch(
            subject="Operating Systems", college="BPHC", count=5, k=2, max_workers=3
        )

    assert len(result) == 5
    assert len({r["question"] for r in result}) == 5  # all unique
    assert not any(r.levelno == logging.WARNING for r in caplog.records)


def test_run_generate_mcq_batch_logs_warning_when_backfill_cannot_reach_count(monkeypatch, caplog):
    # Every call -- initial and backfill alike -- returns the same duplicate
    # text, so backfill can never make progress. It must give up after 3x
    # the requested count in attempts and log a WARNING with the final count
    # rather than looping forever.
    questions, embeddings = _fake_bank()
    _patch_pipeline_deps(monkeypatch, questions, embeddings)

    def fake_generate_mcq(subject, examples):
        return {
            "question":      "Which scheduling algorithm causes starvation?",
            "options":       ["FCFS", "SJF", "RR", "Priority"],
            "correct_index": 3,
            "subject":       subject,
            "marks":         2,
        }

    monkeypatch.setattr(generate_mod, "generate_mcq", fake_generate_mcq)

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        result = generate_mod.run_generate_mcq_batch(
            subject="Operating Systems", college="BPHC", count=3, k=2, max_workers=2
        )

    assert len(result) == 1
    warnings = [r for r in caplog.records if r.levelno == logging.WARNING]
    assert len(warnings) == 1
    assert "1/3" in warnings[0].message

"""
Unit tests for bench/select.py -- setting behaviour (zero_shot/few_shot/mmr_few_shot).

Uses a small synthetic dot-product Backend (not SbertBackend) so these tests
don't load sentence-transformers or download a model -- select.py itself
still goes through pyq.rag.core.retrieval.retrieve_top_k and pyq.rag.core.mmr.mmr,
which is the thing under test (bench must not reimplement them).
"""

import sys
from pathlib import Path

import numpy as np
import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from bench.selection import select_examples  # noqa: E402


class DotBackend:
    """Minimal Backend: similarity is raw dot product, no fit/encode needed
    for these tests since select_examples takes pre-computed vectors."""

    def fit(self, train_texts):
        return None

    def encode(self, texts):
        return texts

    def similarity(self, a, b):
        return float(np.dot(a, b))


@pytest.fixture
def redundant_pool():
    # query points at [1, 0]. A and B are both near-duplicates of the query
    # and of each other; C is less relevant but points in a different
    # direction -- a diverse alternative to B.
    query = np.array([1.0, 0.0])
    candidate_embeddings = np.array([
        [0.99, 0.01],   # A -- very relevant, near-duplicate of B
        [0.98, 0.02],   # B -- very relevant, near-duplicate of A
        [0.10, 0.90],   # C -- less relevant, diverse from A/B
    ])
    candidate_questions = [{"id": "A"}, {"id": "B"}, {"id": "C"}]
    return query, candidate_embeddings, candidate_questions


# ── zero_shot ──────────────────────────────────────────────────────────────────

def test_zero_shot_returns_no_examples(redundant_pool):
    query, embeddings, questions = redundant_pool
    result = select_examples("zero_shot", query, embeddings, questions, k=2, backend=DotBackend())
    assert result == []


def test_zero_shot_ignores_missing_vectors():
    # zero_shot must not touch query_vec/train_vecs at all.
    result = select_examples("zero_shot", None, None, [{"id": "x"}], k=3, backend=DotBackend())
    assert result == []


# ── few_shot ───────────────────────────────────────────────────────────────────

def test_few_shot_returns_k_examples(redundant_pool):
    query, embeddings, questions = redundant_pool
    result = select_examples("few_shot", query, embeddings, questions, k=2, backend=DotBackend())
    assert len(result) == 2


def test_few_shot_picks_most_relevant_first(redundant_pool):
    query, embeddings, questions = redundant_pool
    result = select_examples("few_shot", query, embeddings, questions, k=2, backend=DotBackend())
    ids = [r["id"] for r in result]
    # Pure relevance ranking picks the two near-duplicates A and B, ignoring
    # that they're redundant with each other.
    assert set(ids) == {"A", "B"}


# ── mmr_few_shot ────────────────────────────────────────────────────────────────

def test_mmr_few_shot_returns_k_examples(redundant_pool):
    query, embeddings, questions = redundant_pool
    result = select_examples(
        "mmr_few_shot", query, embeddings, questions, k=2, alpha=0.3, pool_multiplier=3, backend=DotBackend()
    )
    assert len(result) == 2


def test_mmr_few_shot_differs_from_few_shot_on_redundant_pool(redundant_pool):
    query, embeddings, questions = redundant_pool

    few_shot = select_examples("few_shot", query, embeddings, questions, k=2, backend=DotBackend())
    mmr_few_shot = select_examples(
        "mmr_few_shot", query, embeddings, questions, k=2, alpha=0.3, pool_multiplier=3, backend=DotBackend()
    )

    few_shot_ids = [r["id"] for r in few_shot]
    mmr_ids = [r["id"] for r in mmr_few_shot]

    assert few_shot_ids != mmr_ids
    # MMR should swap out the redundant near-duplicate (B) for the diverse
    # alternative (C), while still leading with the most relevant item (A).
    assert mmr_ids == ["A", "C"]


def test_mmr_few_shot_pool_multiplier_caps_at_corpus_size(redundant_pool):
    query, embeddings, questions = redundant_pool
    # pool_multiplier * k (100) is far larger than the 3-candidate corpus --
    # must not raise/index out of bounds, and must still return k results.
    result = select_examples(
        "mmr_few_shot", query, embeddings, questions, k=2, alpha=0.5, pool_multiplier=50, backend=DotBackend()
    )
    assert len(result) == 2


# ── unknown setting ──────────────────────────────────────────────────────────────

def test_unknown_setting_raises(redundant_pool):
    query, embeddings, questions = redundant_pool
    with pytest.raises(ValueError, match="Unknown setting"):
        select_examples("not_a_setting", query, embeddings, questions, k=2, backend=DotBackend())

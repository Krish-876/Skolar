"""
Tests for the new first-stage retrieval + backend abstraction added alongside
the MMR reranking split: core/features.py (TfidfBackend), core/retrieval.py
(retrieve_top_k), and services/generate.py's pool retrieval/subsampling
helpers (zero-vector filtering, seeded per-worker subsampling).
"""

import sys
from pathlib import Path

import numpy as np
import pytest
from scipy import sparse

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.core.features import TfidfBackend  # noqa: E402
from pyq.rag.core.mmr import mmr  # noqa: E402
from pyq.rag.core.retrieval import retrieve_top_k  # noqa: E402
from pyq.rag.services.generate import _retrieve_candidate_pool, _subsample_pool  # noqa: E402


class InvertedBackend:
    """Test double whose similarity is the exact inverse of raw dot product --
    used to prove a function actually delegates to the given backend instead
    of silently falling back to features.similarity."""

    def fit(self, train_texts):
        return None

    def encode(self, texts):
        return texts

    def similarity(self, a, b):
        return -float(np.dot(a, b))


# ── TfidfBackend.similarity on sparse input ────────────────────────────────────

def test_tfidf_backend_similarity_on_sparse_input():
    backend = TfidfBackend()
    corpus = [
        "cats are great pets",
        "dogs are great pets",
        "the stock market crashed today",
    ]
    backend.fit(corpus)
    vecs = backend.encode(corpus)

    assert sparse.issparse(vecs)

    self_sim = backend.similarity(vecs[0], vecs[0])
    similar = backend.similarity(vecs[0], vecs[1])
    different = backend.similarity(vecs[0], vecs[2])

    assert self_sim == pytest.approx(1.0)
    assert 0.0 <= similar <= 1.0
    assert 0.0 <= different <= 1.0
    assert similar > different


# ── retrieve_top_k ordering ─────────────────────────────────────────────────────

def test_retrieve_top_k_ordering():
    rng = np.random.RandomState(1)  # noqa: NPY002 -- deterministic test fixture
    corpus = rng.rand(20, 16).astype(np.float32)
    query = corpus[3].copy()

    indices, scores = retrieve_top_k(query, corpus, k=5)

    assert len(indices) == 5
    assert len(scores) == 5
    assert indices[0] == 3  # exact match ranks first
    assert scores == sorted(scores, reverse=True)


def test_retrieve_top_k_respects_k():
    rng = np.random.RandomState(4)  # noqa: NPY002 -- deterministic test fixture
    corpus = rng.rand(10, 8).astype(np.float32)
    query = rng.rand(8).astype(np.float32)

    indices, scores = retrieve_top_k(query, corpus, k=3)

    assert len(indices) == 3
    assert len(set(indices)) == 3


def test_retrieve_top_k_uses_given_backend_not_module_similarity():
    # A backend whose ranking is the exact inverse of cosine similarity --
    # if retrieve_top_k used features.similarity directly (ignoring the
    # backend), this would still rank by cosine and the assertion would fail.
    rng = np.random.RandomState(6)  # noqa: NPY002 -- deterministic test fixture
    corpus = rng.rand(8, 6).astype(np.float32)
    query = corpus[2].copy()

    indices, _scores = retrieve_top_k(query, corpus, k=1, backend=InvertedBackend())

    assert indices[0] != 2


def test_mmr_uses_given_backend_not_module_similarity():
    # Mirrors test_retrieve_top_k_uses_given_backend_not_module_similarity:
    # if mmr() used features.similarity directly (ignoring the backend), the
    # inverted-similarity backend would still pick the same top candidate
    # and this assertion would fail.
    rng = np.random.RandomState(8)  # noqa: NPY002 -- deterministic test fixture
    candidate_embeddings = rng.rand(6, 6).astype(np.float32)
    query = candidate_embeddings[2].copy()
    candidate_questions = [{"id": i} for i in range(6)]

    default_selected = mmr(query, candidate_embeddings, candidate_questions, alpha=1.0, k=1)
    inverted_selected = mmr(
        query, candidate_embeddings, candidate_questions, alpha=1.0, k=1, backend=InvertedBackend()
    )

    assert default_selected[0]["id"] != inverted_selected[0]["id"]


# ── zero-vector filtering ─────────────────────────────────────────────────────

def test_retrieve_candidate_pool_filters_zero_vectors():
    rng = np.random.RandomState(2)  # noqa: NPY002 -- deterministic test fixture
    embeddings = rng.rand(6, 8).astype(np.float32)
    embeddings[2] = 0.0
    embeddings[4] = 0.0
    questions = [{"id": i} for i in range(6)]
    query = rng.rand(8).astype(np.float32)

    pool_embeddings, pool_questions = _retrieve_candidate_pool(query, embeddings, questions, pool_size=6)

    assert len(pool_questions) == 4
    assert all(np.any(e) for e in pool_embeddings)
    assert {q["id"] for q in pool_questions} == {0, 1, 3, 5}


# ── seeded pool subsampling ────────────────────────────────────────────────────

def test_subsample_pool_different_seeds_produce_different_pools():
    rng = np.random.RandomState(3)  # noqa: NPY002 -- deterministic test fixture
    pool_embeddings = rng.rand(50, 8).astype(np.float32)
    pool_questions = [{"id": i} for i in range(50)]

    _, questions_a = _subsample_pool(pool_embeddings, pool_questions, k=5, seed=1)
    _, questions_b = _subsample_pool(pool_embeddings, pool_questions, k=5, seed=2)

    ids_a = [q["id"] for q in questions_a]
    ids_b = [q["id"] for q in questions_b]

    assert ids_a != ids_b


def test_subsample_pool_never_shuffles_only_subsamples():
    rng = np.random.RandomState(5)  # noqa: NPY002 -- deterministic test fixture
    pool_embeddings = rng.rand(30, 8).astype(np.float32)
    pool_questions = [{"id": i} for i in range(30)]

    _, questions = _subsample_pool(pool_embeddings, pool_questions, k=5, seed=9)
    ids = [q["id"] for q in questions]

    # a subsample must preserve original relative order (no shuffling)
    assert ids == sorted(ids)

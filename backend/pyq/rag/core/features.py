from typing import Protocol

import numpy as np
from scipy import sparse
from scipy.sparse.linalg import norm as _sparse_norm
from sentence_transformers import SentenceTransformer
from sklearn.feature_extraction.text import TfidfVectorizer

EMBED_MODEL = "all-MiniLM-L6-v2"

# ── Shared resources (loaded once at startup) ─────────────────────────────────

_embed_model = None

def get_embed_model():
    global _embed_model
    if _embed_model is None:
        _embed_model = SentenceTransformer(EMBED_MODEL)
    return _embed_model


def _norm(x) -> float:
    # scipy sparse matrices raise on np.linalg.norm, so route them through
    # scipy.sparse.linalg.norm instead of densifying.
    if sparse.issparse(x):
        return float(_sparse_norm(x))
    return float(np.linalg.norm(x))


def _dot(a, b) -> float:
    if sparse.issparse(a):
        return float(a.multiply(b).sum())
    if sparse.issparse(b):
        return float(b.multiply(a).sum())
    return float(np.dot(np.asarray(a).ravel(), np.asarray(b).ravel()))


def similarity(a, b) -> float:
    """Cosine similarity rescaled to [0, 1] -- works for dense ndarrays and
    scipy sparse rows (e.g. TfidfVectorizer output) alike."""
    cosine = _dot(a, b) / (_norm(a) * _norm(b) + 1e-9)
    return (1.0 + cosine) / 2.0


class Backend(Protocol):
    """Common interface for embedding backends used by the retrieval/MMR pipeline."""

    def fit(self, train_texts: list[str]) -> None: ...
    def encode(self, texts: list[str]) -> np.ndarray: ...
    def similarity(self, a, b) -> float: ...


class SbertBackend:
    """Wraps the existing sentence-transformers model behind the Backend protocol."""

    def fit(self, train_texts: list[str]) -> None:
        # Pretrained model -- nothing to fit.
        return None

    def encode(self, texts: list[str]) -> np.ndarray:
        return get_embed_model().encode(texts)

    def similarity(self, a, b) -> float:
        return similarity(a, b)


class TfidfBackend:
    """TF-IDF + cosine backend. encode() returns a scipy sparse matrix; the
    vectorizer must be fit on a training corpus before encode() is called."""

    def __init__(self):
        self._vectorizer = TfidfVectorizer()

    def fit(self, train_texts: list[str]) -> None:
        self._vectorizer.fit(train_texts)

    def encode(self, texts: list[str]):
        return self._vectorizer.transform(texts)

    def similarity(self, a, b) -> float:
        return similarity(a, b)

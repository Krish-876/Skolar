from typing import Protocol

import numpy as np
from sentence_transformers import SentenceTransformer

EMBED_MODEL = "all-MiniLM-L6-v2"

# ── Shared resources (loaded once at startup) ─────────────────────────────────

_embed_model = None

def get_embed_model():
    global _embed_model
    if _embed_model is None:
        _embed_model = SentenceTransformer(EMBED_MODEL)
    return _embed_model


class Backend(Protocol):
    """Common interface for embedding backends used by the MMR pipeline."""

    def encode(self, texts: list[str]) -> np.ndarray: ...


class SbertBackend:
    """Wraps the existing sentence-transformers model behind the Backend protocol."""

    def encode(self, texts: list[str]) -> np.ndarray:
        return get_embed_model().encode(texts)

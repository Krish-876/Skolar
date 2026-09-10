"""
Example selection settings for the bench/ harness.

This module is intentionally thin: it MUST import retrieve_top_k, mmr, and
the Backend classes from pyq.rag.core rather than reimplementing them, so the
numbers this harness produces describe the retrieval/reranking code Skolar
actually ships (see backend/pyq/rag/core/{retrieval,mmr,features}.py).

Callers should encode the full train corpus and the query once per dataset
(not per sample) and pass the resulting vectors in here -- see bench/run.py.
"""

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.core.features import Backend  # noqa: E402
from pyq.rag.core.mmr import mmr  # noqa: E402
from pyq.rag.core.retrieval import retrieve_top_k  # noqa: E402

SETTING_NAMES: tuple[str, ...] = ("zero_shot", "few_shot", "mmr_few_shot")


def select_examples(
    setting: str,
    query_vec,
    train_vecs,
    train_records: list[dict],
    k: int,
    alpha: float = 0.7,
    pool_multiplier: int = 3,
    backend: Backend | None = None,
) -> list[dict]:
    """
    Return the in-context examples for one test sample under one setting:

    - zero_shot     -- no examples.
    - few_shot      -- the top-k most similar train examples (retrieve_top_k).
    - mmr_few_shot  -- retrieve a pool of pool_multiplier * k candidates, then
                        MMR-rerank that pool down to k for relevance + diversity
                        (this is Diverse-ICL's two-stage method).
    """
    setting = setting.lower()

    if setting == "zero_shot":
        return []

    if setting == "few_shot":
        indices, _scores = retrieve_top_k(query_vec, train_vecs, k, backend=backend)
        return [train_records[i] for i in indices]

    if setting == "mmr_few_shot":
        pool_size = min(pool_multiplier * k, train_vecs.shape[0])
        pool_indices, _scores = retrieve_top_k(query_vec, train_vecs, pool_size, backend=backend)
        pool_vecs = train_vecs[pool_indices]
        pool_records = [train_records[i] for i in pool_indices]
        return mmr(query_vec, pool_vecs, pool_records, alpha=alpha, k=k, backend=backend)

    raise ValueError(f"Unknown setting {setting!r}. Expected one of {SETTING_NAMES}.")

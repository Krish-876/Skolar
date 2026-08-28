import numpy as np
from numpy.linalg import norm

from .features import Backend, SbertBackend

# ── Step 4 — MMR Algorithm ────────────────────────────────────────────────────

def cosine_sim(a: np.ndarray, b: np.ndarray) -> float:
    """Raw cosine similarity. Kept for services/upload.py::match_and_write_solutions,
    whose 0.82 match threshold is calibrated against raw cosine, not MMR's
    rescaled features.similarity."""
    return float(np.dot(a, b) / (norm(a) * norm(b) + 1e-9))

def mmr(
    query_embedding: np.ndarray,
    candidate_embeddings: np.ndarray,
    candidate_questions: list[dict],
    alpha: float,
    k: int,
    backend: Backend | None = None,
) -> list[dict]:
    """
    Rerank a pre-retrieved candidate pool for relevance + diversity.

    candidate_embeddings/candidate_questions are expected to already be a
    narrowed pool (see core.retrieval.retrieve_top_k) -- this is a pure
    reranking stage, not a first-stage retriever. MMR's greedy argmax is
    deterministic given a candidate pool, so there is no seed/shuffle here:
    permuting the candidates cannot change which one wins at each step.
    """
    if backend is None:
        backend = SbertBackend()
    sim = backend.similarity

    query_sims = [sim(query_embedding, e) for e in candidate_embeddings]
    selected, selected_embeddings, remaining = [], [], list(range(len(candidate_questions)))

    for _ in range(min(k, len(remaining))):
        mmr_scores = []
        for i in remaining:
            relevance = query_sims[i]
            diversity = (
                max(sim(candidate_embeddings[i], s) for s in selected_embeddings)
                if selected_embeddings else 0
            )
            score = alpha * relevance - (1 - alpha) * diversity
            mmr_scores.append((i, score))

        best = max(mmr_scores, key=lambda x: x[1])[0]
        selected.append(candidate_questions[best])
        selected_embeddings.append(candidate_embeddings[best])
        remaining.remove(best)

    return selected

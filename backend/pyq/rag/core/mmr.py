import random

import numpy as np
from numpy.linalg import norm

# ── Step 4 — MMR Algorithm ────────────────────────────────────────────────────

def cosine_sim(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (norm(a) * norm(b) + 1e-9))

def mmr(
    query_embedding: np.ndarray,
    candidate_embeddings: np.ndarray,
    candidate_questions: list[dict],
    k: int = 5,
    alpha: float = 0.7,
    seed: int | None = None,
) -> list[dict]:
    rng = random.Random(seed)  # noqa: S311 -- not used for cryptographic purposes
    indices = list(range(len(candidate_questions)))
    if seed is not None:
        rng.shuffle(indices)
        candidate_questions = [candidate_questions[i] for i in indices]
        candidate_embeddings = candidate_embeddings[indices]

    query_sims = [cosine_sim(query_embedding, e) for e in candidate_embeddings]
    selected, selected_embeddings, remaining = [], [], list(range(len(candidate_questions)))

    for _ in range(min(k, len(remaining))):
        mmr_scores = []
        for i in remaining:
            relevance = query_sims[i]
            diversity = (
                max(cosine_sim(candidate_embeddings[i], s) for s in selected_embeddings)
                if selected_embeddings else 0
            )
            score = alpha * relevance - (1 - alpha) * diversity
            mmr_scores.append((i, score))

        best = max(mmr_scores, key=lambda x: x[1])[0]
        selected.append(candidate_questions[best])
        selected_embeddings.append(candidate_embeddings[best])
        remaining.remove(best)

    return selected

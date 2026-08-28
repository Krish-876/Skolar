from .features import Backend, SbertBackend

# ── Step 1 — First-stage retrieval ────────────────────────────────────────────
# Narrows the full corpus down to a candidate pool by the given backend's
# similarity before MMR reranks that pool for diversity.

def retrieve_top_k(
    query_vec,
    corpus_vecs,
    k: int,
    backend: Backend | None = None,
) -> tuple[list[int], list[float]]:
    if backend is None:
        backend = SbertBackend()
    n = corpus_vecs.shape[0]
    scores = [backend.similarity(query_vec, corpus_vecs[i]) for i in range(n)]
    ranked = sorted(range(n), key=lambda i: scores[i], reverse=True)
    top = ranked[:k]
    return top, [scores[i] for i in top]

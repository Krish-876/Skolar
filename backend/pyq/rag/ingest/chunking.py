CHUNK_SIZE   = 6000
CHUNK_OVERLAP = 500   # overlap between chunks to prevent questions being split at page boundaries

# ── Step 1b — Overlapping chunks ─────────────────────────────────────────────
# Prevents questions that span a page break from being truncated.
# Each chunk overlaps with the previous by CHUNK_OVERLAP characters.
# After extraction, near-duplicate questions are deduplicated by text similarity.

def _make_chunks(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    chunks = []
    start = 0
    while start < len(text):
        end = start + size
        chunks.append(text[start:end])
        start += size - overlap
    return chunks

def _deduplicate_questions(questions: list[dict]) -> list[dict]:
    """
    Remove near-duplicate questions that arise from overlapping chunks.
    Two questions are considered duplicates if their texts share more than
    80% of their words. Keeps the one with higher confidence_score.
    """
    def word_overlap(a: str, b: str) -> float:
        wa = set(a.lower().split())
        wb = set(b.lower().split())
        if not wa or not wb:
            return 0.0
        return len(wa & wb) / min(len(wa), len(wb))

    kept = []
    for q in questions:
        is_dup = False
        for i, existing in enumerate(kept):
            if word_overlap(q["question_text"], existing["question_text"]) > 0.8:
                # keep whichever has higher confidence
                if q.get("confidence_score", 1.0) > existing.get("confidence_score", 1.0):
                    kept[i] = q
                is_dup = True
                break
        if not is_dup:
            kept.append(q)
    return kept

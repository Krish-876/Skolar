import logging
import os
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import numpy as np

from ..core.features import Backend, get_embed_model
from ..core.mmr import cosine_sim, mmr
from ..core.retrieval import retrieve_top_k
from ..ingest.chunking import _deduplicate_questions
from ..llm.generation import generate_model_answer, generate_question, generate_mcq
from ..store.supabase import load_bank_and_embeddings

logger = logging.getLogger(__name__)

# Groq's free tier is ~8000 TPM (see llm/client.py's TokenBudgetLimiter), which
# works out to roughly 9 calls/minute at this pipeline's per-call prompt size.
# More concurrent workers than that just pile up blocked on the shared token
# budget rather than improving throughput -- default kept low and configurable.
_DEFAULT_MAX_WORKERS = 2


def _max_workers_for(count: int, max_workers: int | None) -> int:
    if max_workers is None:
        max_workers = int(os.getenv("GROQ_MAX_WORKERS", _DEFAULT_MAX_WORKERS))
    return max(1, min(count, max_workers))


def _dedup_generated(results: list[dict], requested: int, label: str) -> list[dict]:
    """Cross-worker duplication guard: independent workers can't see each
    other's output, so a batch can end up with several near-identical
    questions. _deduplicate_questions expects 'question_text' -- the batch
    functions here key their results as 'question', so alias it rather than
    changing that function (llm/extraction.py depends on its current
    behaviour). Never regenerates to backfill a shortfall -- that would
    multiply token cost -- just logs when dedup itself pushes the count
    below what was requested."""
    for r in results:
        r["question_text"] = r["question"]
    deduped = _deduplicate_questions(results)
    removed = len(results) - len(deduped)
    if removed > 0 and len(deduped) < requested:
        logger.info(
            f"[{label}] dedup removed {removed} near-duplicate question(s): "
            f"{len(results)} -> {len(deduped)} (requested {requested})"
        )
    return deduped


_DEFAULT_EMBEDDING_DEDUP_THRESHOLD = 0.85


def _dedup_by_embedding(
    results: list[dict],
    label: str,
    threshold: float = _DEFAULT_EMBEDDING_DEDUP_THRESHOLD,
) -> list[dict]:
    """Second, embedding-based duplication guard for generated batches.

    _deduplicate_questions' word-overlap metric splits on whitespace without
    normalising punctuation, so it can miss real duplicates -- a confirmed
    duplicate pair ("execve()?" vs "execve()") scored ~0.79 against its 0.8
    threshold and survived, while embedding cosine similarity for the same
    pair was 0.891. This runs after _dedup_generated, on whatever it didn't
    catch. Keeps the first occurrence of each near-duplicate cluster.

    Deliberately separate from _deduplicate_questions rather than folded into
    it or replacing it -- that function is also used by llm/extraction.py
    over hundreds of chunks, where word overlap is the right cheap metric.
    """
    if len(results) < 2:
        return results

    model = get_embed_model()
    texts = [r["question"] for r in results]
    embeddings = model.encode(texts)

    kept: list[dict] = []
    kept_embeddings: list[np.ndarray] = []
    for r, emb, text in zip(results, embeddings, texts):
        is_dup = False
        for kept_r, kept_emb in zip(kept, kept_embeddings):
            score = cosine_sim(emb, kept_emb)
            if score > threshold:
                logger.info(
                    f"[{label}] embedding dedup dropped a near-duplicate "
                    f"(cosine={score:.3f} > {threshold}): "
                    f"kept={kept_r['question']!r} dropped={text!r}"
                )
                is_dup = True
                break
        if not is_dup:
            kept.append(r)
            kept_embeddings.append(emb)

    return kept


def _backfill_shortfall(
    results: list[dict],
    generate_one,
    count: int,
    label: str,
    threshold: float = _DEFAULT_EMBEDDING_DEDUP_THRESHOLD,
) -> list[dict]:
    """Tops up a batch that embedding dedup left short of `count`.

    Generates one replacement at a time -- never in a batch -- so each new
    candidate is checked against the growing kept set (not just the batch it
    was generated alongside) before being accepted, the same guarantee
    _dedup_by_embedding gives the initial batch. Reuses `generate_one` (the
    caller's `_generate_one` closure) with a seed past the ones already used
    for this batch (`count + attempt`) so a backfill draws a fresh pool
    subsample instead of reproducing the near-duplicate that created the
    shortfall in the first place. Bails out after 3x the requested count in
    attempts rather than looping forever against an exhausted example pool.
    """
    if len(results) >= count:
        return results

    model = get_embed_model()
    kept = list(results)
    kept_embeddings = list(model.encode([r["question"] for r in kept])) if kept else []

    max_attempts = 3 * count
    attempt = 0
    while len(kept) < count and attempt < max_attempts:
        attempt += 1
        candidate = generate_one(count + attempt)
        if candidate is None:
            continue

        emb = model.encode([candidate["question"]])[0]
        max_sim = max((cosine_sim(emb, kept_emb) for kept_emb in kept_embeddings), default=0.0)
        if max_sim > threshold:
            continue

        kept.append(candidate)
        kept_embeddings.append(emb)

    if len(kept) < count:
        logger.warning(
            f"[{label}] backfill still short after {attempt} attempt(s): "
            f"{len(kept)}/{count} questions"
        )

    return kept


def _exclude_generated(questions: list[dict], embeddings: np.ndarray) -> tuple[list[dict], np.ndarray]:
    """Example pools must be built from real PYQs, not AI-generated questions
    from earlier batches -- otherwise generated output becomes a few-shot
    example for the next generation, compounding without human review.
    _EXAM_TYPE_ALLOWED alone can't catch this: a generated batch saved with
    exam_type='midsem' still passes the 'midsem' tier's own filter, so this
    checks doc_type directly instead."""
    indices = [i for i, q in enumerate(questions) if q.get("doc_type") != "generated"]
    if len(indices) == len(questions):
        return questions, embeddings
    return [questions[i] for i in indices], embeddings[indices]


# ── Candidate pool retrieval (stage 1, before MMR reranks for diversity) ──────

def _pool_size_for(k: int, pool_size: int | None) -> int:
    return pool_size if pool_size is not None else max(10 * k, 50)


def _retrieve_candidate_pool(
    query_embedding: np.ndarray,
    embeddings: np.ndarray,
    questions: list[dict],
    pool_size: int,
    backend: Backend | None = None,
) -> tuple[np.ndarray, list[dict]]:
    indices, _scores = retrieve_top_k(query_embedding, embeddings, pool_size, backend=backend)
    pool_embeddings = embeddings[indices]
    pool_questions = [questions[i] for i in indices]

    keep = [i for i, e in enumerate(pool_embeddings) if np.any(e)]
    return pool_embeddings[keep], [pool_questions[i] for i in keep]


def _subsample_pool(
    pool_embeddings: np.ndarray,
    pool_questions: list[dict],
    k: int,
    seed: int,
) -> tuple[np.ndarray, list[dict]]:
    """Per-worker variation for batch generation: sample a subset of the
    retrieved pool with a seeded RNG. Subsamples only -- never shuffles --
    since MMR's ranking depends on candidate identity, not list order."""
    pool_len = len(pool_questions)
    sample_size = min(pool_len, max(k, pool_len // 2))
    rng = np.random.default_rng(seed)
    chosen = sorted(rng.choice(pool_len, size=sample_size, replace=False).tolist())
    return pool_embeddings[chosen], [pool_questions[i] for i in chosen]

# ── Step 3 — Embeddings ───────────────────────────────────────────────────────

def embed_questions(questions: list[dict]) -> np.ndarray:
    model = get_embed_model()
    texts = [q["question_text"] for q in questions]
    return model.encode(texts)

# ── Exam type filter ──────────────────────────────────────────────────────────

_EXAM_TYPE_ALLOWED: dict[str, set[str]] = {
    "quiz1":  {"quiz1",  "generated"},
    "midsem": {"midsem", "quiz1",  "generated"},
    "quiz2":  {"quiz2",  "midsem", "quiz1",  "generated"},
    "compre": {"compre", "quiz2",  "midsem", "quiz1", "generated"},
}

def _filter_by_exam_type(
    questions: list[dict],
    embeddings: np.ndarray,
    exam_type: str | None,
) -> tuple[list[dict], np.ndarray]:
    if not exam_type:
        return questions, embeddings
    allowed = _EXAM_TYPE_ALLOWED.get(exam_type.lower())
    if not allowed:
        return questions, embeddings
    indices = [
        i for i, q in enumerate(questions)
        if (q.get("exam_type") or "").lower() in allowed
    ]
    if not indices:
        return questions, embeddings
    return (
        [questions[i] for i in indices],
        embeddings[indices],
    )

# ── Main pipeline entry points ────────────────────────────────────────────────

def run_generate(
    subject: str,
    college: str,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
    academic_year: int | None = None,
    current_topic: str | None = None,
    alpha: float = 0.7,
    pool_size: int | None = None,
    backend: Backend | None = None,
) -> str:
    """
    academic_year — scopes the question bank to this year only.
    current_topic — uses the student's current study topic as the MMR query
                    anchor instead of just the subject name. Dramatically
                    improves relevance when the handout topic_schedule is
                    available and passed by the Flutter app.
    alpha — MMR relevance/diversity tradeoff, forwarded to core.mmr.mmr.
    pool_size — size of the first-stage retrieval pool MMR reranks; defaults
                to max(10 * k, 50).
    backend — similarity backend for both retrieval and MMR reranking;
              defaults to SbertBackend.
    """
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)
    all_questions, embeddings = _exclude_generated(all_questions, embeddings)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("paper_year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    model = get_embed_model()
    # If current_topic is provided, use it as the MMR anchor — much more
    # relevant than the broad subject name.
    query_text = current_topic if current_topic else subject
    query_embedding = model.encode([query_text])[0]

    pool_embeddings, pool_questions = _retrieve_candidate_pool(
        query_embedding, embeddings, all_questions, _pool_size_for(k, pool_size), backend=backend
    )
    examples = mmr(query_embedding, pool_embeddings, pool_questions, alpha=alpha, k=k, backend=backend)
    return generate_question(subject, examples)


def run_generate_mcq_batch(
    subject: str,
    college: str,
    count: int = 5,
    exam_type: str | None = None,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
    academic_year: int | None = None,
    current_topic: str | None = None,
    alpha: float = 0.7,
    pool_size: int | None = None,
    backend: Backend | None = None,
    max_workers: int | None = None,
    dedup_threshold: float = _DEFAULT_EMBEDDING_DEDUP_THRESHOLD,
) -> list[dict]:
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)
    all_questions, embeddings = _exclude_generated(all_questions, embeddings)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("paper_year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    all_questions, embeddings = _filter_by_exam_type(all_questions, embeddings, exam_type)

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    model = get_embed_model()
    query_text = current_topic if current_topic else subject
    query_embedding = model.encode([query_text])[0]

    pool_embeddings, pool_questions = _retrieve_candidate_pool(
        query_embedding, embeddings, all_questions, _pool_size_for(k, pool_size), backend=backend
    )

    errors: list[str] = []
    errors_lock = threading.Lock()

    def _generate_one(worker_idx: int) -> dict | None:
        try:
            worker_embeddings, worker_questions = _subsample_pool(
                pool_embeddings, pool_questions, k, seed=worker_idx
            )
            examples = mmr(query_embedding, worker_embeddings, worker_questions, alpha=alpha, k=k, backend=backend)
            return generate_mcq(subject, examples)
        except Exception as e:
            logger.warning(f"[generate_mcq worker={worker_idx}] failed: {e}")
            with errors_lock:
                errors.append(str(e))
            return None

    results: list[dict] = []
    with ThreadPoolExecutor(max_workers=_max_workers_for(count, max_workers)) as pool:
        futures = [pool.submit(_generate_one, i) for i in range(count)]
        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                results.append(result)

    if not results:
        detail = errors[0] if errors else "no successful generations and no error captured"
        raise RuntimeError(f"All {count} MCQ generation attempts failed: {detail}")

    deduped = _dedup_generated(results, requested=count, label="generate_mcq_batch")
    deduped = _dedup_by_embedding(deduped, label="generate_mcq_batch", threshold=dedup_threshold)
    return _backfill_shortfall(
        deduped, _generate_one, count=count, label="generate_mcq_batch", threshold=dedup_threshold
    )


def run_generate_open_batch(
    subject: str,
    college: str,
    count: int = 5,
    exam_type: str | None = None,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
    with_answers: bool = True,
    academic_year: int | None = None,
    current_topic: str | None = None,
    alpha: float = 0.7,
    pool_size: int | None = None,
    backend: Backend | None = None,
    max_workers: int | None = None,
    dedup_threshold: float = _DEFAULT_EMBEDDING_DEDUP_THRESHOLD,
) -> list[dict]:
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)
    all_questions, embeddings = _exclude_generated(all_questions, embeddings)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("paper_year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    all_questions, embeddings = _filter_by_exam_type(all_questions, embeddings, exam_type)

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    written_indices = [
        i for i, q in enumerate(all_questions)
        if q.get("question_type", "short_answer") != "mcq"
    ]
    if written_indices:
        written_questions = [all_questions[i] for i in written_indices]
        written_embeddings = embeddings[written_indices]
    else:
        written_questions = all_questions
        written_embeddings = embeddings

    model = get_embed_model()
    query_text = current_topic if current_topic else subject
    query_embedding = model.encode([query_text])[0]

    pool_embeddings, pool_questions = _retrieve_candidate_pool(
        query_embedding, written_embeddings, written_questions, _pool_size_for(k, pool_size), backend=backend
    )

    errors: list[str] = []
    errors_lock = threading.Lock()

    def _generate_one(worker_idx: int) -> dict | None:
        try:
            worker_embeddings, worker_questions = _subsample_pool(
                pool_embeddings, pool_questions, k, seed=worker_idx
            )
            examples = mmr(query_embedding, worker_embeddings, worker_questions, alpha=alpha, k=k, backend=backend)
            marks_list = [e.get("marks", 5) for e in examples]
            target_marks = sorted(marks_list)[len(marks_list) // 2]

            question_text = generate_question(subject, examples)
            model_answer = ""
            if with_answers:
                model_answer = generate_model_answer(question_text, subject, target_marks)

            return {
                "question":     question_text,
                "subject":      subject,
                "marks":        target_marks,
                "model_answer": model_answer,
            }
        except Exception as e:
            logger.warning(f"[generate_open worker={worker_idx}] failed: {e}")
            with errors_lock:
                errors.append(str(e))
            return None

    results: list[dict] = []
    with ThreadPoolExecutor(max_workers=_max_workers_for(count, max_workers)) as pool:
        futures = [pool.submit(_generate_one, i) for i in range(count)]
        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                results.append(result)

    if not results:
        detail = errors[0] if errors else "no successful generations and no error captured"
        raise RuntimeError(f"All {count} open-ended generation attempts failed: {detail}")

    deduped = _dedup_generated(results, requested=count, label="generate_open_batch")
    deduped = _dedup_by_embedding(deduped, label="generate_open_batch", threshold=dedup_threshold)
    return _backfill_shortfall(
        deduped, _generate_one, count=count, label="generate_open_batch", threshold=dedup_threshold
    )

import logging
from concurrent.futures import ThreadPoolExecutor, as_completed

import numpy as np

from ..core.features import get_embed_model
from ..core.mmr import mmr
from ..llm.generation import generate_model_answer, generate_question, generate_mcq
from ..store.supabase import load_bank_and_embeddings

logger = logging.getLogger(__name__)

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
) -> str:
    """
    academic_year — scopes the question bank to this year only.
    current_topic — uses the student's current study topic as the MMR query
                    anchor instead of just the subject name. Dramatically
                    improves relevance when the handout topic_schedule is
                    available and passed by the Flutter app.
    """
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)

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
    examples = mmr(query_embedding, embeddings, all_questions, k=k)
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
) -> list[dict]:
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)

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

    def _generate_one(worker_idx: int) -> dict | None:
        try:
            examples = mmr(query_embedding, embeddings, all_questions, k=k, seed=worker_idx)
            return generate_mcq(subject, examples)
        except Exception as e:
            logger.warning(f"[generate_mcq worker={worker_idx}] failed: {e}")
            return None

    results: list[dict] = []
    max_workers = min(count, 3)
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(_generate_one, i) for i in range(count)]
        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                results.append(result)

    return results


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
) -> list[dict]:
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)

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

    written_questions = [
        q for q in all_questions
        if q.get("question_type", "short_answer") != "mcq"
    ]
    if not written_questions:
        written_questions = all_questions

    model = get_embed_model()
    written_texts = [q["question_text"] for q in written_questions]
    written_embeddings = model.encode(written_texts)
    query_text = current_topic if current_topic else subject
    query_embedding = model.encode([query_text])[0]

    def _generate_one(worker_idx: int) -> dict | None:
        try:
            examples = mmr(query_embedding, written_embeddings, written_questions, k=k, seed=worker_idx)
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
            return None

    results: list[dict] = []
    max_workers = min(count, 3)
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(_generate_one, i) for i in range(count)]
        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                results.append(result)

    return results

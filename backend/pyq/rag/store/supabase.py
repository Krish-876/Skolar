import json
import os

import numpy as np
from supabase import Client, create_client

# ── Shared resources (loaded once at startup) ─────────────────────────────────

_supabase: Client = None

def get_supabase() -> Client:
    global _supabase
    if _supabase is None:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_KEY")
        if not url or not key:
            raise RuntimeError("SUPABASE_URL and SUPABASE_KEY must be set in .env")
        _supabase = create_client(url, key)
    return _supabase

# ── I/O Layer — Supabase ──────────────────────────────────────────────────────

def load_bank_and_embeddings(
    college: str,
    subject: str | None = None,
    academic_year: int | None = None,
) -> tuple[list[dict], np.ndarray]:
    """
    Load questions and embeddings from Supabase.

    academic_year — optional filter. When provided, only loads questions from
    that academic year. Prevents first-year students from seeing third-year
    paper questions in their MMR pool, which improves generation relevance.
    """
    sb = get_supabase()
    query = sb.table("questions").select(
        "id, question_text, marks, question_type, subject, paper_year, "
        "exam_type, embedding, topic, academic_year, doc_type"
    ).eq("college", college)

    if subject:
        query = query.eq("subject", subject)

    if academic_year is not None:
        query = query.eq("academic_year", academic_year)

    response = query.execute()
    rows = response.data or []

    if not rows:
        return [], np.empty((0, 384), dtype=np.float32)

    questions = []
    embeddings = []
    for row in rows:
        questions.append({
            "id":            row["id"],
            "question_text": row["question_text"],
            "marks":         row["marks"],
            "question_type": row["question_type"],
            "subject":       row["subject"],
            "paper_year":    row["paper_year"],
            "exam_type":     row["exam_type"],
            "topic":         row.get("topic", ""),
            "academic_year": row.get("academic_year"),
            "doc_type":      row.get("doc_type"),
        })
        emb = row.get("embedding")
        if emb is not None:
            if isinstance(emb, str):
                emb = json.loads(emb)
            embeddings.append(np.array(emb, dtype=np.float32))
        else:
            embeddings.append(np.zeros(384, dtype=np.float32))

    return questions, np.vstack(embeddings)


def save_questions_with_embeddings(
    questions: list[dict],
    embeddings: np.ndarray,
    college: str,
    subject_id: str | None = None,
    campus_id: str | None = None,
    source_pdf_id: str | None = None,
    doc_type: str = "pyq",
) -> int:
    sb = get_supabase()
    rows = []
    for q, emb in zip(questions, embeddings):
        row = {
            "question_text":    q["question_text"],
            "marks":            q["marks"],
            "question_type":    q["question_type"],
            "subject":          q["subject"],       # legacy text — keep
            "college":          college,             # legacy text — keep
            "paper_year":       q["paper_year"],
            "exam_type":        q["exam_type"],
            "embedding":        emb.tolist(),
            "published":        False,
            "doc_type":         doc_type,
            "topic":            q.get("topic", ""),
            "has_diagram":      q.get("has_diagram", False),
            "marks_inferred":   q.get("marks_inferred", False),
            "confidence_score": q.get("confidence_score", 1.0),
            "sub_parts":        q.get("sub_parts", []),
        }
        # MCQ options — only write if present
        if q.get("options"):
            row["options"]        = q["options"]
            row["correct_index"]  = q.get("correct_index")  # may be null if no answer key

        # Only write uuid columns if values were supplied
        if subject_id:
            row["subject_id"] = subject_id
        if campus_id:
            row["campus_id"] = campus_id
        if source_pdf_id:
            row["source_pdf_id"] = source_pdf_id
        rows.append(row)

    if not rows:
        return 0

    batch_size = 50
    inserted = 0
    for i in range(0, len(rows), batch_size):
        batch = rows[i:i + batch_size]
        sb.table("questions").insert(batch).execute()
        inserted += len(batch)

    return inserted

# ── uploaded_pdfs helpers ─────────────────────────────────────────────────────

def _create_pdf_record(
    sb: Client,
    uploaded_by: str | None,
    storage_path: str,
    doc_type: str,
    subject_id: str | None,
    campus_id: str | None,
    exam_type: str | None,
    paper_year: int | None,
) -> str:
    row: dict = {
        "uploaded_as":  "student",
        "storage_path": storage_path,
        "doc_type":     doc_type,
        "status":       "running",
    }
    if uploaded_by:
        row["uploaded_by"] = uploaded_by
    if subject_id:
        row["subject_id"] = subject_id
    if campus_id:
        row["campus_id"] = campus_id
    if exam_type:
        row["exam_type"] = exam_type
    if paper_year:
        row["paper_year"] = paper_year

    response = sb.table("uploaded_pdfs").insert(row).execute()
    return response.data[0]["id"]


def _update_pdf_record(
    sb: Client,
    pdf_id: str,
    status: str,
    questions_extracted: int,
    questions_failed: int,
) -> None:
    sb.table("uploaded_pdfs").update({
        "status":               status,
        "questions_extracted":  questions_extracted,
        "questions_failed":     questions_failed,
    }).eq("id", pdf_id).execute()


def save_generated_test(
    questions: list[dict],
    college: str,
    subject: str,
    exam_type: str,
    published_by: str | None = None,
) -> str:
    sb = get_supabase()

    rows = []
    for q in questions:
        row = {
            "question_text": q.get("question", q.get("question_text", "")),
            "marks":         int(q.get("marks", 0)),
            "question_type": "mcq" if "correct_index" in q else "short_answer",
            "subject":       subject,
            "college":       college,
            "exam_type":     exam_type,
            "published":     True,
            "published_by":  published_by,
            "published_at":  "now()",
            "doc_type":      "generated",
            "topic":         "",
            "sub_parts":     [],
        }
        if q.get("options"):
            row["options"]       = q["options"]
            row["correct_index"] = q.get("correct_index")
        rows.append(row)

    response = sb.table("questions").insert(rows).execute()
    question_ids = [row["id"] for row in response.data]

    test_response = sb.table("published_tests").insert({
        "college":      college,
        "subject":      subject,
        "exam_type":    exam_type,
        "question_ids": question_ids,
        "published_by": published_by,
    }).execute()

    return test_response.data[0]["id"]

import logging

import numpy as np

from ..core.features import get_embed_model
from ..core.mmr import cosine_sim
from ..ingest.extract import extract_raw_text, extract_raw_text_any
from ..llm.extraction import (
    ExamTypeUndeterminedError,
    _extract_answer_blocks,
    extract_questions_from_text,
    guess_exam_type_from_text,
)
from ..store.supabase import (
    _create_pdf_record,
    _update_pdf_record,
    get_supabase,
    load_bank_and_embeddings,
    save_questions_with_embeddings,
)
from .generate import embed_questions

logger = logging.getLogger(__name__)

def match_and_write_solutions(
    pdf_bytes: bytes,
    subject: str,
    college: str,
    subject_id: str | None = None,
    similarity_threshold: float = 0.82,
    filename: str | None = None,
) -> dict:
    """
    Solution sheet pipeline:
    1. Extract answer blocks from the solution file
    2. Load existing questions for this subject from Supabase
    3. For each answer block, embed the question_hint and find the closest
       matching question by cosine similarity
    4. Above threshold, write model_answer and answer_source = 'professor'

    filename — if provided, dispatches through extract_raw_text_any so
    solution sheets uploaded as .docx/.doc/image work too, not just PDF.

    Returns counts of matched and unmatched answers.
    """
    sb = get_supabase()
    model = get_embed_model()

    # Extract answers from the solution sheet
    raw_text = extract_raw_text_any(pdf_bytes, filename) if filename else extract_raw_text(pdf_bytes)
    answer_blocks = _extract_answer_blocks(raw_text, subject)

    if not answer_blocks:
        return {"matched": 0, "unmatched": 0, "total_answers": 0}

    # Load existing questions for this subject
    existing_questions, existing_embeddings = load_bank_and_embeddings(college, subject)

    if not existing_questions:
        logger.warning(f"[match_solutions] no existing questions for subject={subject}, college={college}")
        return {"matched": 0, "unmatched": len(answer_blocks), "total_answers": len(answer_blocks)}

    # Embed the question hints from the solution sheet
    hints = [a.get("question_hint", a.get("answer_text", "")[:200]) for a in answer_blocks]
    hint_embeddings = model.encode(hints)

    matched = 0
    unmatched = 0

    for answer_block, hint_emb in zip(answer_blocks, hint_embeddings):
        # Find best matching question by cosine similarity
        sims = [cosine_sim(hint_emb, ex_emb) for ex_emb in existing_embeddings]
        best_idx = int(np.argmax(sims))
        best_sim = sims[best_idx]

        if best_sim >= similarity_threshold:
            question_id = existing_questions[best_idx]["id"]
            answer_text = answer_block.get("answer_text", "")

            try:
                sb.table("questions").update({
                    "model_answer":  answer_text,
                    "answer_source": "professor",
                }).eq("id", question_id).execute()
                matched += 1
                logger.info(f"[match_solutions] matched answer to question {question_id} (sim={best_sim:.3f})")
            except Exception as e:
                logger.warning(f"[match_solutions] failed to update question {question_id}: {e}")
                unmatched += 1
        else:
            unmatched += 1
            logger.debug(f"[match_solutions] no match found (best_sim={best_sim:.3f})")

    return {
        "matched":       matched,
        "unmatched":     unmatched,
        "total_answers": len(answer_blocks),
    }


def run_upload_pyq(
    pdf_bytes: bytes,
    subject: str,
    paper_year: int,
    exam_type: str | None,
    college: str,
    subject_id: str | None = None,
    campus_id: str | None = None,
    uploaded_by: str | None = None,
    doc_type: str = "pyq",
    storage_path: str = "direct_upload",
    filename: str | None = None,
) -> dict:
    """
    Full upload pipeline with audit trail.

    filename — NEW. If provided, extraction is dispatched by file extension
    via extract_raw_text_any, so .pdf/.docx/.doc/.png/.jpg/.jpeg/.webp all
    work. If omitted, behaves exactly as before (PDF-only via extract_raw_text),
    so any existing caller that doesn't pass filename is unaffected.

    For doc_type = "solution": routes to match_and_write_solutions instead
    of extracting new questions. Returns match counts instead of insert counts.

    For all other doc_types: extracts questions and inserts into questions table.
    """
    sb = get_supabase()

    # Route solution sheets to the matching pipeline
    if doc_type == "solution":
        pdf_id: str | None = None
        try:
            pdf_id = _create_pdf_record(
                sb=sb,
                uploaded_by=uploaded_by,
                storage_path=storage_path,
                doc_type=doc_type,
                subject_id=subject_id,
                campus_id=campus_id,
                exam_type=exam_type,
                paper_year=paper_year,
            )
        except Exception as e:
            logger.warning(f"[upload_solution] failed to create uploaded_pdfs row: {e}")

        try:
            result = match_and_write_solutions(
                pdf_bytes=pdf_bytes,
                subject=subject,
                college=college,
                subject_id=subject_id,
                filename=filename,
            )
            if pdf_id:
                status = "succeeded" if result["unmatched"] == 0 else "partial"
                _update_pdf_record(sb, pdf_id, status, result["matched"], result["unmatched"])
            return {**result, "pdf_id": pdf_id}
        except Exception:
            if pdf_id:
                _update_pdf_record(sb, pdf_id, "failed", 0, 0)
            raise

    # All other doc types — standard extraction pipeline
    pdf_id = None
    try:
        pdf_id = _create_pdf_record(
            sb=sb,
            uploaded_by=uploaded_by,
            storage_path=storage_path,
            doc_type=doc_type,
            subject_id=subject_id,
            campus_id=campus_id,
            exam_type=exam_type,
            paper_year=paper_year,
        )
        logger.info(f"[upload_pyq] created uploaded_pdfs row: {pdf_id}")
    except Exception as e:
        logger.warning(f"[upload_pyq] failed to create uploaded_pdfs row: {e}")

    raw_text = extract_raw_text_any(pdf_bytes, filename) if filename else extract_raw_text(pdf_bytes)

    exam_type_source = "provided"
    if not exam_type and doc_type == "pyq":
        guessed_exam_type = guess_exam_type_from_text(raw_text)
        if guessed_exam_type:
            exam_type = guessed_exam_type
            exam_type_source = "content"
            logger.info(f"[upload_pyq] exam_type determined from document content: {exam_type}")
            if pdf_id:
                try:
                    sb.table("uploaded_pdfs").update({"exam_type": exam_type}).eq("id", pdf_id).execute()
                except Exception as e:
                    logger.warning(f"[upload_pyq] failed to update exam_type on uploaded_pdfs row: {e}")
        else:
            if pdf_id:
                _update_pdf_record(sb, pdf_id, "failed", 0, 0)
            raise ExamTypeUndeterminedError(
                "exam_type was not provided and could not be determined from document content."
            )

    new_questions = extract_questions_from_text(
        raw_text, subject, paper_year, exam_type, doc_type=doc_type
    )

    if not new_questions:
        if pdf_id:
            _update_pdf_record(sb, pdf_id, "failed", 0, 0)
        raise ValueError("No questions could be extracted from the file.")

    new_embeddings = embed_questions(new_questions)

    questions_failed = 0
    try:
        inserted = save_questions_with_embeddings(
            questions=new_questions,
            embeddings=new_embeddings,
            college=college,
            subject_id=subject_id,
            campus_id=campus_id,
            source_pdf_id=pdf_id,
            doc_type=doc_type,
        )
    except Exception as e:
        logger.error(f"[upload_pyq] save_questions failed: {e}")
        if pdf_id:
            _update_pdf_record(sb, pdf_id, "failed", 0, len(new_questions))
        raise

    questions_failed = len(new_questions) - inserted

    if pdf_id:
        status = "succeeded" if questions_failed == 0 else "partial"
        _update_pdf_record(sb, pdf_id, status, inserted, questions_failed)
        logger.info(f"[upload_pyq] status={status}, extracted={inserted}, failed={questions_failed}")

    return {
        "added":            inserted,
        "pdf_id":           pdf_id,
        "exam_type":        exam_type,
        "exam_type_source": exam_type_source,
        "new_questions":    [q["question_text"][:80] + "..." for q in new_questions],
    }

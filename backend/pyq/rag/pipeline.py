"""
Backwards-compatible shim. The pipeline was split into pyq/rag/{core,ingest,llm,store,services}/
during the backend/pyq/rag refactor — this module just re-exports everything so existing
imports (`from .pipeline import ...`, `from pyq.rag.pipeline import ...`) keep working.
"""

from .core.features import Backend, EMBED_MODEL, SbertBackend, get_embed_model
from .core.mmr import cosine_sim, mmr
from .ingest.chunking import CHUNK_OVERLAP, CHUNK_SIZE, _deduplicate_questions, _make_chunks
from .ingest.extract import (
    _TEXT_EXTRACTORS,
    _get_easyocr_reader,
    _ocr_fallback,
    _ocr_pil_image,
    _ocr_single_page,
    _render_pdf_page,
    extract_doc_text,
    extract_docx_text,
    extract_image_text,
    extract_raw_text,
    extract_raw_text_any,
)
from .llm.client import GROQ_MODEL, get_groq_client
from .llm.extraction import (
    ExamTypeUndeterminedError,
    _extract_answer_blocks,
    extract_questions_from_text,
    guess_exam_type_from_text,
)
from .llm.generation import generate_mcq, generate_model_answer, generate_question
from .services.generate import (
    _EXAM_TYPE_ALLOWED,
    _filter_by_exam_type,
    embed_questions,
    run_generate,
    run_generate_mcq_batch,
    run_generate_open_batch,
)
from .services.upload import match_and_write_solutions, run_upload_pyq
from .store.supabase import (
    _create_pdf_record,
    _update_pdf_record,
    get_supabase,
    load_bank_and_embeddings,
    save_generated_test,
    save_questions_with_embeddings,
)

__all__ = [
    "Backend",
    "EMBED_MODEL",
    "SbertBackend",
    "get_embed_model",
    "cosine_sim",
    "mmr",
    "CHUNK_SIZE",
    "CHUNK_OVERLAP",
    "_make_chunks",
    "_deduplicate_questions",
    "_get_easyocr_reader",
    "_ocr_pil_image",
    "_render_pdf_page",
    "_ocr_single_page",
    "_ocr_fallback",
    "_TEXT_EXTRACTORS",
    "extract_raw_text",
    "extract_docx_text",
    "extract_doc_text",
    "extract_image_text",
    "extract_raw_text_any",
    "GROQ_MODEL",
    "get_groq_client",
    "extract_questions_from_text",
    "_extract_answer_blocks",
    "guess_exam_type_from_text",
    "ExamTypeUndeterminedError",
    "generate_question",
    "generate_mcq",
    "generate_model_answer",
    "get_supabase",
    "load_bank_and_embeddings",
    "save_questions_with_embeddings",
    "save_generated_test",
    "_create_pdf_record",
    "_update_pdf_record",
    "run_upload_pyq",
    "match_and_write_solutions",
    "run_generate",
    "run_generate_mcq_batch",
    "run_generate_open_batch",
    "_filter_by_exam_type",
    "_EXAM_TYPE_ALLOWED",
    "embed_questions",
]

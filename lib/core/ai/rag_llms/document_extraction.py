"""
document_extraction.py

Drop-in replacement for the pdfplumber-based `extract_raw_text` in the
question-extraction pipeline.

Why this exists:
  - pdfplumber only reads PDFs, and its OCR fallback only triggers when the
    WHOLE document is text-sparse — so a single scanned/image-only page
    inside an otherwise text-heavy PDF gets silently dropped.
  - There was no ingestion path at all for .docx or raw image files.

What this gives you:
  - One converter (Docling, MIT license) that natively reads PDF, DOCX,
    and images (.jpg/.jpeg/.png).
  - OCR is decided PER PAGE by Docling's layout model, not per document —
    so a scanned page inside a mostly-digital PDF is caught.
  - OCR runs entirely locally via EasyOCR. No API calls, no rate limits,
    no external cost. Models auto-download on first run.

Integration point:
  In your pipeline module, replace:
      raw_text = extract_raw_text(pdf_bytes)
  with:
      raw_text = extract_content(file_bytes, filename)

  `run_upload_pyq` needs to accept and pass through the original filename
  (or at least its extension) so this can route correctly — see the
  `SUPPORTED_EXTENSIONS` set below for what's handled.
"""

from __future__ import annotations

import io
import logging
from pathlib import Path

from docling.datamodel.base_models import DocumentStream, InputFormat
from docling.datamodel.pipeline_options import (
    EasyOcrOptions,
    PdfPipelineOptions,
)
from docling.document_converter import (
    DocumentConverter,
    ImageFormatOption,
    PdfFormatOption,
)

logger = logging.getLogger(__name__)

SUPPORTED_EXTENSIONS = {".pdf", ".docx", ".jpg", ".jpeg", ".png"}

# ── Converter setup (build once, reuse — model loading is the expensive part) ──

_converter: DocumentConverter | None = None


def _build_converter() -> DocumentConverter:
    pdf_options = PdfPipelineOptions()
    pdf_options.do_ocr = True
    pdf_options.do_table_structure = True  # tabular MCQ options, marks tables, etc.

    # force_full_page_ocr lives on the OcrOptions subclass, not on
    # PdfPipelineOptions itself. Docling's layout model still decides
    # per-page whether OCR is needed when this is False — that's the
    # fix for "one scanned page in a text PDF gets skipped."
    pdf_options.ocr_options = EasyOcrOptions(lang=["en"], force_full_page_ocr=False)

    return DocumentConverter(
        format_options={
            InputFormat.PDF: PdfFormatOption(pipeline_options=pdf_options),
            InputFormat.IMAGE: ImageFormatOption(pipeline_options=pdf_options),
        }
    )

def get_converter() -> DocumentConverter:
    global _converter
    if _converter is None:
        logger.info("[document_extraction] building Docling converter (first call — this downloads OCR models if not cached)")
        _converter = _build_converter()
    return _converter


# ── Public entry point ────────────────────────────────────────────────────────

def extract_content(file_bytes: bytes, filename: str) -> str:
    """
    Extract text (markdown-ish, with tables preserved) from a PDF, DOCX,
    or image file.

    filename only needs a correct extension — Docling uses it to pick the
    right backend. Raises ValueError for unsupported extensions so the
    caller can surface a clean error instead of a Docling stack trace.
    """
    ext = Path(filename).suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise ValueError(
            f"Unsupported file type '{ext}' for '{filename}'. "
            f"Supported: {sorted(SUPPORTED_EXTENSIONS)}"
        )

    converter = get_converter()
    stream = DocumentStream(name=filename, stream=io.BytesIO(file_bytes))

    result = converter.convert(stream)

    if result.status.value not in ("success", "partial_success"):
        raise RuntimeError(
            f"[document_extraction] Docling failed to convert '{filename}': {result.status}"
        )
    if result.status.value == "partial_success":
        logger.warning(f"[document_extraction] '{filename}' converted with partial_success — some pages may be incomplete")

    # export_to_markdown keeps table structure (pipe tables) intact, which
    # matters for MCQ option blocks and marks tables — plain text export
    # would flatten those and hurt extraction quality downstream.
    text = result.document.export_to_markdown()

    if not text or len(text.strip()) < 20:
        logger.warning(f"[document_extraction] '{filename}' produced almost no text after conversion — likely a bad scan or empty document")

    return text
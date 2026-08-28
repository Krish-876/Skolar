# Refactor notes — backend/pyq/rag module split

This refactor was a pure move (main.py / pipeline.py -> core/ingest/llm/store/services/).
No behavior, signatures, or logic were changed. While reading the code end-to-end to move
it, a few pre-existing issues in the *original* code were spotted. They are left untouched,
as instructed, and documented here instead.

## 1. `/upload-pyq` never reaches the multi-format / content-guessed-exam-type paths

`services/upload.py::run_upload_pyq` (and `match_and_write_solutions`) accept a `filename`
parameter that — when provided — dispatches through `extract_raw_text_any` (ingest/extract.py),
enabling `.docx` / `.doc` / image uploads, and enables `guess_exam_type_from_text` fallback
when `exam_type` is omitted for `doc_type="pyq"`.

The FastAPI route in `main.py` (`upload_pyq`) never passes `filename=` to `run_upload_pyq`, and
additionally hard-rejects any non-`.pdf` filename before calling it
(`if not file.filename.endswith(".pdf"): raise HTTPException(...)`). It also requires `exam_type`
to be explicitly provided and valid for `doc_type="pyq"`, so the content-based exam-type guess
never has a chance to run via this endpoint.

Net effect: the entire `.docx` / `.doc` / image extraction path, and the content-based exam-type
guessing path, are dead code from the HTTP API's perspective. They *are* exercised by the
`pyq/batch_upload.py` CLI tool, which does pass `filename=` and can pass `exam_type=None` for pyq
uploads (see `batch_upload.py` lines ~224-244).

This looks like an oversight when the multi-format support was added to the pipeline layer
without updating the FastAPI route to match. Not fixed here since it's a behavior change.

## 2. `match_and_write_solutions(subject_id=...)` is unused

`services/upload.py::match_and_write_solutions` accepts a `subject_id: str | None = None`
parameter and it is threaded in from `run_upload_pyq`, but the function body never reads it —
it's not used to scope `load_bank_and_embeddings`, not passed to the `questions` table update,
nothing. Looks like a leftover from an earlier version of the function, or a parameter that was
meant to scope the existing-question lookup by `subject_id` but never got wired up. Left as-is.

## Files created

```
pyq/rag/core/features.py     Backend protocol + SbertBackend (new scaffolding, unused by
                              existing call sites) + get_embed_model (moved)
pyq/rag/core/mmr.py          cosine_sim, mmr
pyq/rag/ingest/chunking.py   CHUNK_SIZE, CHUNK_OVERLAP, _make_chunks, _deduplicate_questions
pyq/rag/ingest/extract.py    extract_raw_text[_any], extract_docx_text, extract_doc_text,
                              extract_image_text, all _ocr_* / _render_pdf_page helpers,
                              _TEXT_EXTRACTORS
pyq/rag/llm/client.py        get_groq_client, GROQ_MODEL
pyq/rag/llm/extraction.py    extract_questions_from_text, _extract_answer_blocks,
                              guess_exam_type_from_text, ExamTypeUndeterminedError
pyq/rag/llm/generation.py    generate_question, generate_mcq, generate_model_answer
pyq/rag/store/supabase.py    get_supabase, load_bank_and_embeddings,
                              save_questions_with_embeddings, save_generated_test,
                              _create_pdf_record, _update_pdf_record
pyq/rag/services/upload.py   run_upload_pyq, match_and_write_solutions
pyq/rag/services/generate.py run_generate, run_generate_mcq_batch, run_generate_open_batch,
                              _filter_by_exam_type, _EXAM_TYPE_ALLOWED, embed_questions
```

`pyq/rag/pipeline.py` is now a re-export shim (kept because `pyq/batch_upload.py` and the old
`main.py` import from it) — nothing new lives there.

`pyq/rag/main.py` was updated to import from `services.generate`, `services.upload`, and
`store.supabase` instead of `pipeline`; route bodies are unchanged.

The `os.environ["OPENBLAS_NUM_THREADS"/"OMP_NUM_THREADS"]` settings, `load_dotenv()`, and
`logging.basicConfig(...)` now live in `pyq/rag/__init__.py`, since that's guaranteed to execute
before any submodule (and therefore before numpy/sentence-transformers) is imported, regardless
of which submodule an external caller imports first.

## Everything moved cleanly

No signatures, control flow, or string content (prompts, error messages, log messages) were
changed. `tests/test_golden.py` diffs the refactored `core`/`ingest`/`llm`/`services` functions
against the original `pipeline.py` (loaded live from `git show HEAD:...`) for every
dependency-free deterministic function: `cosine_sim`, `mmr`, `_make_chunks`,
`_deduplicate_questions`, `_filter_by_exam_type`, `guess_exam_type_from_text` — all 35 cases pass.

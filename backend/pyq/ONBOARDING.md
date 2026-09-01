# PYQ pipeline: onboarding

## 1. What this system does

PYQ = "Previous Year Questions." Students or staff upload past exam papers (PDF/DOCX/images); the pipeline extracts individual questions from them with
an LLM and stores them, embedded as vectors, in a shared question bank. When
a student wants practice material, the system pulls a relevant, diverse
sample of real past questions from that bank and asks an LLM to generate new
questions in the same style: either one open-ended question, a batch of
MCQs, or a batch of open-ended questions with model answers.

**In:** exam papers (PDF/DOCX/images). **Out:** AI generated practice questions (and, optionally, professor model answers matched to existing questions). 
**Data lives in:** Supabase: a `questions` table (bank + embeddings),
a `published_tests` table, and an `uploaded_pdfs` table (audit trail).
Nothing here writes to a local database file.

## 2. File-by-file map

### `backend/pyq/` (top level)

| File | What it's for | When to open it |
|---|---|---|
| `batch_upload.py` | CLI: recursively upload every PDF/DOCX/image in a local folder through the same pipeline the app's upload button uses. Groups split page-image scans into one document, guesses year/exam type from filenames, and keeps a resumable manifest so a crash mid-batch doesn't redo finished files. | Bulk-loading a folder of scanned papers instead of uploading one at a time through the app. |
| `ONBOARDING.md` | This file. | Now. |

### `backend/pyq/data/`

| File | What it's for | When to open it |
|---|---|---|
| `question_bank.json`, `embeddings.npy` | **Legacy / unused.** Leftovers from an old pre-Supabase design (see `ARCHITECTURE.md`, which still describes them as the live store). No module under `backend/pyq/` reads or writes these two files; the only code that ever touches these filenames is a standalone notebook, `backend/notebooks/data_extraction_llms.ipynb`, run manually and unrelated to the live app. **Don't build on these: they're dead weight, not a cache.** | Never, for pipeline work. |

### `backend/pyq/rag/`

| File | What it's for | When to open it |
|---|---|---|
| `main.py` | The FastAPI app: every HTTP endpoint (`/generate`, `/generate-batch`, `/generate-open-batch`, `/upload-pyq`, `/health`, `/stats`, `/questions`) lives here as thin request/response wiring. | Adding/changing an API endpoint or its request/response shape. |
| `pipeline.py` | A backwards-compatible shim: re-exports everything from `core/`, `ingest/`, `llm/`, `store/`, `services/` under their old names so old `from .pipeline import ...` imports keep working after the module was split up. No real logic here. | Only if an old import breaks; otherwise ignore. |
| `evaluate.py` | Standalone manual QA script: hits a running local server's `/generate-batch` and `/generate-open-batch`, checks MCQ validity, answer substance, and pairwise diversity, and prints a pass/fail report. Not part of the automated test suite. | Sanity-checking generation quality by eye after a change to the generation/retrieval logic. |
| `__init__.py` | Package init: pins BLAS thread counts to 1 (avoids oversubscription with the embedding model) and loads `.env` via `python-dotenv`. | Rarely; only if env-loading or threading behavior needs to change. |

#### `rag/ingest/`: turning a raw file into raw text

| File | What it's for | When to open it |
|---|---|---|
| `extract.py` | Pulls text out of PDFs (`pdfplumber`, with per-page OCR fallback via EasyOCR/`pypdfium2` for image-heavy pages), DOCX (`python-docx` + OCR of embedded images), legacy `.doc` (via a local LibreOffice conversion, needs `soffice` on PATH), and standalone images. | A file type fails to extract, or you're adding support for a new format. |
| `chunking.py` | Splits long extracted text into overlapping chunks (so questions spanning a page break aren't truncated) and deduplicates near-identical questions (word-overlap > 80%) that arise from that overlap. | Tuning chunk size/overlap or the dedup similarity threshold. |

#### `rag/llm/`: talking to Groq

| File | What it's for | When to open it |
|---|---|---|
| `client.py` | The single Groq client + a shared token-budget rate limiter (`TokenBudgetLimiter`). Every Groq call in this codebase should go through `create_chat_completion()` here so the shared TPM budget is actually enforced. | Rate-limit tuning, or adding a new Groq call that needs to respect the shared budget. |
| `extraction.py` | Prompts Groq to turn a chunk of raw text into structured question objects (MCQ options, sub-parts, topic tags, confidence scores), extract answer blocks from solution sheets, and guess exam type from document content. | Changing what gets extracted from an uploaded paper, or the extraction prompt itself. |
| `generation.py` | Prompts Groq to generate a new open-ended question, a new MCQ, or a model answer, given few-shot example questions. | Changing how generated questions/answers are worded or structured. |

#### `rag/core/`: pure math, no I/O, no network

| File | What it's for | When to open it |
|---|---|---|
| `features.py` | The embedding model singleton (`all-MiniLM-L6-v2` via `sentence-transformers`) and the `Backend` protocol (`SbertBackend`, `TfidfBackend`) used for similarity scoring. | Swapping the embedding model or adding a new similarity backend. |
| `retrieval.py` | First-stage retrieval: `retrieve_top_k` narrows the full corpus to a candidate pool by similarity, before MMR reranks it. | Changing how the initial candidate pool is chosen. |
| `mmr.py` | Second-stage reranking: Maximal Marginal Relevance, picks a diverse-but-relevant subset from the candidate pool. Also hosts `cosine_sim`, the raw (non-rescaled) similarity used by `services/upload.py`'s solution matching. | Tuning the relevance/diversity tradeoff (`alpha`) or the reranking algorithm itself. |

#### `rag/store/`: the only place that talks to Supabase

| File | What it's for | When to open it |
|---|---|---|
| `supabase.py` | All Supabase reads/writes: `load_bank_and_embeddings` (read questions + embeddings for a college/subject/year), `save_questions_with_embeddings` (insert newly-extracted questions), `save_generated_test` (publish a generated batch), plus `uploaded_pdfs` audit-trail helpers. | Changing the DB schema mapping, or anything about how questions are read from/written to Supabase. |

#### `rag/services/`: the two orchestration flows

| File | What it's for | When to open it |
|---|---|---|
| `generate.py` | Orchestrates generation: loads the bank, excludes previously-AI-generated rows from the example pool, filters by exam type, retrieves + MMR-reranks examples, fires off concurrent Groq generation workers, and runs two layers of duplicate-detection (word-overlap, then embedding cosine similarity) with backfill if dedup drops the count below what was requested. | Changing generation behavior: pool sizing, worker count, dedup thresholds, exam-type tiering. |
| `upload.py` | Orchestrates upload: extract text → extract questions (or, for `doc_type="solution"`, extract+match answer blocks to existing questions by embedding similarity) → embed → save to Supabase, with an `uploaded_pdfs` audit row updated at each stage. | Changing upload behavior: how exam type is resolved, how solution sheets get matched, what gets written to the audit trail. |

#### `rag/scripts/`

| File | What it's for | When to open it |
|---|---|---|
| `cleanup_generated_questions.py` | Manual, human-run CLI to list (and optionally delete) `doc_type='generated'` rows that were auto-saved to the bank back when `/generate-batch`/`/generate-open-batch` wrote to it as a side effect (that's no longer the default; see `persist` in §3). Refuses to delete anything referenced by a published test unless you force it with `--include-referenced`. Not run automatically by anything. | Cleaning up old auto-persisted generated rows from before the `persist` opt-in was added. |

## 3. The two flows

### Upload: a document goes in, questions end up in Supabase

1. `main.py` (`POST /upload-pyq`) or `batch_upload.py` receives a file and calls `services/upload.py:run_upload_pyq`.
2. `store/supabase.py:_create_pdf_record`: writes an `uploaded_pdfs` audit row (status `"running"`).
3. `ingest/extract.py:extract_raw_text_any` (or `extract_raw_text` for plain PDF calls): pulls raw text out of the file.
4. If `exam_type` wasn't given, `llm/extraction.py:guess_exam_type_from_text` tries to infer it from the document content; if that also fails, `run_upload_pyq` raises `ExamTypeUndeterminedError`.
5. `llm/extraction.py:extract_questions_from_text`: chunks the text (`ingest/chunking.py`) and asks Groq to extract structured questions per chunk, then dedups them.
   - **Solution-sheet branch:** if `doc_type == "solution"`, step 5 is replaced by `services/upload.py:match_and_write_solutions`, which extracts answer blocks and matches them to *existing* questions by embedding similarity instead of creating new question rows.
6. `services/generate.py:embed_questions`: embeds the new questions with the sentence-transformers model.
7. `store/supabase.py:save_questions_with_embeddings`: inserts the new rows into the Supabase `questions` table.
8. `store/supabase.py:_update_pdf_record`: marks the `uploaded_pdfs` row `succeeded`/`partial`/`failed`.

### Generate: a request comes in, new questions come out

1. `main.py` (`POST /generate`, `/generate-batch`, or `/generate-open-batch`) receives the request and calls into `services/generate.py`.
2. `store/supabase.py:load_bank_and_embeddings`: loads that college/subject's (optionally academic-year-scoped) questions + embeddings from Supabase.
3. `services/generate.py:_exclude_generated`: strips previously-AI-generated rows out of the example pool (so generated output never becomes a few-shot example for the next generation).
4. `services/generate.py:_filter_by_exam_type` (batch endpoints only): restricts examples to the requested exam tier and everything "below" it (e.g. `compre` also allows `quiz1`/`quiz2`/`midsem`).
5. `core/retrieval.py:retrieve_top_k`: narrows the filtered bank to a candidate pool by similarity to the query (subject name, or the student's current topic if given).
6. `core/mmr.py:mmr`: reranks that pool down to `k` examples, balancing relevance against diversity (`alpha`).
7. `llm/generation.py:generate_question` / `generate_mcq` / `generate_model_answer`: asks Groq to produce the new question(s) (and, for open-ended batches, a model answer) from those `k` examples. Batch endpoints run several of these concurrently via `ThreadPoolExecutor`.
8. `services/generate.py`: dedups the batch results (word-overlap, then embedding cosine similarity) and backfills any shortfall.
9. Only if the request's `persist` field is `true`: `store/supabase.py:save_generated_test` writes the batch to the `questions` table and a `published_tests` row. **Default is `false`**: generating does not implicitly save.

## 4. Setup

### Install

```bash
cd backend
pip install -r requirements.txt        # runtime deps
pip install -r requirements-dev.txt    # ruff, mypy, pytest, httpx (for tests)
```

`extract.py`'s `.doc` (legacy binary Word) conversion needs LibreOffice
installed separately, with `soffice` on PATH; it's not a pip package. Every
other format (`.pdf`, `.docx`, images) works with just `requirements.txt`.

### Environment variables

Read directly from the code (`grep -rn "os.getenv" backend/pyq/`); no
values invented here, no secrets included:

| Variable | Required? | Where used | Purpose |
|---|---|---|---|
| `SUPABASE_URL` | Yes | `store/supabase.py:14` | Supabase project URL. |
| `SUPABASE_KEY` | Yes | `store/supabase.py:15` | Supabase API key. |
| `GROQ_API_KEY` | Yes | `llm/client.py:15` | Groq API key for all LLM calls. |
| `GROQ_TPM_LIMIT` | No (defaults to 8000) | `llm/client.py:32` | Overrides the assumed Groq tokens-per-minute ceiling the shared rate limiter enforces. |
| `GROQ_COMPLETION_TOKENS_ESTIMATE` | No (defaults to 450) | `llm/client.py:136` | Overrides the completion-token estimate reserved per call when the caller doesn't specify a max. |
| `GROQ_MAX_WORKERS` | No (defaults to 2) | `services/generate.py:26` | Concurrent workers for batch generation. |

These are loaded from a `.env` file in `backend/` via `python-dotenv`
(`pyq/rag/__init__.py`); no `.env.example` exists in this repo, so create
your own `.env` with the four required keys above before running anything
that touches Supabase or Groq.

### Run the API locally

```bash
cd backend
uvicorn pyq.rag.main:app --reload --port 8000
# or: python -m pyq.rag.main
```

Then hit it, e.g.:

```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/upload-pyq \
    -F "file=@somepaper.pdf" -F "subject=Operating Systems" \
    -F "paper_year=2024" -F "exam_type=midsem" -F "college=BITS Pilani Hyderabad"
curl -X POST http://localhost:8000/generate-batch \
    -H "Content-Type: application/json" \
    -d '{"subject":"Operating Systems","college":"BITS Pilani Hyderabad","count":5}'
```

### Run a batch upload locally

```bash
cd backend/pyq
python batch_upload.py D:\PYQs\CS_F372 --subject "Compiler Construction" \
    --college "BITS Pilani Hyderabad" --exam-type compre --doc-type pyq
```

Add `--dry-run` first to preview what would be uploaded without touching
Supabase.

## 5. Benchmark (`backend/bench/`)

**What it measures and why:** `bench/` is a *separate* measurement harness
for deciding retrieval/reranking knobs (`k`, `alpha`, model choice,
reasoning effort) with numbers instead of guesses. It reuses the exact same
code this pipeline ships (`core/retrieval.py`, `core/mmr.py`,
`core/features.py`) against four labelled public classification datasets
(SST2/CoLA/RTE/TREC, vendored under `bench/data/`), *not* against the real
question bank. It is **not** a reproduction of the Diverse-ICL paper it
borrows datasets/method from; different models, different hyperparameters,
not comparable to that paper's numbers.

**Single run:**

```bash
cd backend
python bench/run.py \
    --dataset sst2 --setting mmr_few_shot \
    --k 4 --alpha 0.7 --pool-multiplier 3 \
    --backend sbert --model openai/gpt-oss-120b --reasoning-effort none \
    --limit 5 \
    --out bench/results/raw/sst2_mmr_smoke.jsonl
```

**Sweep (a grid of configs from YAML), cost preview first:**

```bash
cd backend
python -m bench.sweep --estimate                              # no API calls, always run this first
python -m bench.sweep                                          # runs bench/sweeps/default.yaml
python -m bench.sweep --config bench/sweeps/full.yaml --estimate
python -m bench.sweep --config bench/sweeps/full.yaml
```

Every sweep YAML must declare `max_calls`; `sweep.py` refuses to start if
the estimated net-new call count would exceed it.

**Where results land:** raw per-config output goes to `bench/results/raw/*.jsonl`
(+ a `.meta.json` sidecar per file); gitignored, regenerated by running configs.

**Regenerating `REPORT.md`:**

```bash
cd backend
python bench/report.py --results-dir bench/results/raw --out-dir bench/results
```

This turns everything under `results/raw/` into `bench/results/REPORT.md`
(the part between `<!-- BENCH:BEGIN -->`/`<!-- BENCH:END -->` markers is
regenerated each run; content above those markers is hand-edited and never
touched) and appends one row to `bench/results/history.jsonl`.

**Gotcha: Groq free-tier rate limits (two different ceilings, easy to
conflate):**
- The live app (`llm/client.py`) assumes **8000 tokens/minute** and
  throttles all Groq calls against that.
- `bench/run.py` targets a **different** free-tier ceiling (**30
  requests/minute, 1000 requests/day**) and throttles/retries against that
  instead. Hitting the daily cap stops a bench run immediately and writes a
  partial output file (`meta.json` has `"partial": true`) rather than losing
  what was already spent.

Both are real constraints on the same Groq account; a bench sweep and app
traffic against the same key can both burn from the same actual quota even
though each measures against a different assumed ceiling.

## 6. Running the tests

```bash
cd backend
python -m pytest tests/
```

Or, to run just the bench-related tests (all synthetic, no live API calls or quota spent):

```bash
python -m pytest tests/test_bench_datasets.py tests/test_bench_select.py \
    tests/test_bench_prompts.py tests/test_bench_score.py tests/test_bench_run.py \
    tests/test_bench_cache.py tests/test_bench_sweep.py
```

**What the golden tests protect (`tests/test_golden.py`):** the
`backend/pyq/rag` codebase was refactored from one big `pipeline.py` into
today's `core/`/`ingest/`/`llm/`/`store/`/`services/` split. `test_golden.py`
replays fixed synthetic inputs (a seeded random embedding matrix, no real
model calls) through `cosine_sim`, `mmr`, `_deduplicate_questions`,
`_make_chunks`, `guess_exam_type_from_text`, and `_filter_by_exam_type`, and
diffs the output against `tests/fixtures/golden_values.json`: values
captured from the *original pre-refactor* pipeline. If a "pure refactor"
accidentally changes behavior (not just code shape), this is what catches
it.

**Note:** `tests/test_rls.py` needs live `SUPABASE_URL`/`SUPABASE_KEY` to
actually exercise Supabase row-level-security isolation; it calls
`pytest.skip(...)` automatically if those env vars aren't set, so it won't
fail your run, just silently skip.

## 7. Gotchas

- **`pyq/data/question_bank.json` and `embeddings.npy` are dead files.**
  `ARCHITECTURE.md` still describes them as the live store; it's stale.
  Nothing in `pyq/` reads or writes them. All live reads/writes go through
  `store/supabase.py`. Don't spend time trying to "sync" or "refresh" them.
- **Generating does not save by default.** `/generate-batch` and
  `/generate-open-batch` only write to the bank/published feed when the
  request sets `"persist": true`. This changed from the old always-save
  behavior; old callers that relied on the implicit write now get nothing
  saved unless they pass `persist`.
- **Groq has two different rate ceilings depending on which code path you're
  in** (app: 8000 TPM; bench: 30 RPM / 1000 RPD); see §5. Both draw on the
  same account quota.
- **`.doc` upload needs LibreOffice installed locally** (`soffice` on PATH);
  it's not a pip dependency, so `pip install -r requirements.txt` alone
  won't make `.doc` uploads work.
- **`evaluate.py` is a manual script, not part of `pytest`.** It expects a
  server already running on `http://localhost:8000` and spends real Groq
  tokens (10 MCQs + 5 open-ended per run); don't run it reflexively.
- **Batch generation workers are independent**: `services/generate.py`
  runs several Groq calls concurrently per batch, so near-duplicate
  questions across workers are expected and are caught by two dedup passes
  (word-overlap, then embedding similarity) with backfill, not prevented
  upfront.
- **No `.env.example` exists** in this repo. You have to create your own
  `.env` in `backend/` with the four vars listed in §4 before anything that
  touches Supabase or Groq will run.
- **`cleanup_generated_questions.py` is never run automatically.** If you
  see old `doc_type='generated'` rows cluttering a question bank from before
  the `persist` opt-in existed, this is the tool, but it's a manual,
  human-triggered cleanup, not part of any pipeline.

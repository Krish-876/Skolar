# Skolar — Backend Services

Skolar runs **three separate backend services**, not one — they live in
different subdirectories of `backend/`, run on different ports, and none of
them are mounted inside each other:

| Service | Location | Port (dev) | Purpose |
|---|---|---|---|
| Question generation / study plans (DICL pipeline) | `backend/pyq/rag/` | `8000` | Generate MCQ/open questions, upload PYQs, extract study plans |
| Nova API (chat, facts, reasoning, proposals) | `backend/nova/` | `8080` | Everything documented in [NOVA.md](NOVA.md) |
| Nova trigger-check | `backend/app/` | `8001` | `POST /nova/trigger/check` — see [NOVA.md](NOVA.md#nova-trigger-layer-backendapp) |

Back to [README](README.md). This file covers the first and third; Nova's
own service is documented in full in [NOVA.md](NOVA.md).

---

## Table of Contents

- [Question Generation Pipeline (`backend/pyq/rag`)](#question-generation-pipeline-backendpyqrag)
- [AI Pipeline (DICL)](#ai-pipeline-dicl)
- [Study Plan Generation](#study-plan-generation)
- [PDF Upload Pipeline](#pdf-upload-pipeline)
- [PYQ Batch Upload Pipeline (Internal Tooling)](#pyq-batch-upload-pipeline-internal-tooling)
- [Pipeline Evaluation](#pipeline-evaluation)
- [Running RLS Isolation Tests](#running-rls-isolation-tests)
- [CI](#ci)
- [Tech Stack](#tech-stack)
- [Tech Debt](#tech-debt)

---

## Question Generation Pipeline (`backend/pyq/rag`)

> **This moved.** The pipeline used to live at `lib/core/ai/rag_llms/` — that
> directory no longer exists anywhere in the repo. It was restructured into
> `backend/pyq/rag/`, split into `core/`, `ingest/`, `llm/`, `store/`,
> `services/`, and `scripts/` submodules (`backend/pyq/rag/REFACTOR_NOTES.md`
> confirms this was a pure move, no behavior change — `pipeline.py` is now
> just a backwards-compat re-export shim, not where the real logic lives).
> For a full file-by-file map of this new structure, see
> [`backend/pyq/ONBOARDING.md`](backend/pyq/ONBOARDING.md) — this file
> doesn't repeat it.

### Run it locally

```bash
cd backend
pip install -r requirements.txt
uvicorn pyq.rag.main:app --reload --port 8000
```

Interactive API docs at `http://localhost:8000/docs`. Running it as a module
(`python -m pyq.rag.main`) instead binds `0.0.0.0` by default (see
`backend/pyq/rag/main.py`'s own `uvicorn.run(..., host="0.0.0.0", ...)` call)
— the `uvicorn ... --reload` form above does **not**, it defaults to
`127.0.0.1`. For physical-device/LAN testing, add `--host 0.0.0.0`
explicitly:

```bash
uvicorn pyq.rag.main:app --reload --host 0.0.0.0 --port 8000
```

`.env` (in `backend/`, not committed) needs `SUPABASE_URL`, `SUPABASE_KEY`,
`GROQ_API_KEY`; optional `GROQ_API_KEY_2` for one-retry fallback. Full
environment variable reference (including rate-limit tuning) is in
[`backend/pyq/ONBOARDING.md` §4](backend/pyq/ONBOARDING.md).

### Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Sanity check |
| `GET` | `/stats` | Bank stats scoped by college |
| `GET` | `/questions` | Browse/filter the question bank |
| `POST` | `/generate` | One open-ended question |
| `POST` | `/generate-batch` | N MCQs in parallel (Compre Part A) |
| `POST` | `/generate-open-batch` | N open questions + model answers |
| `POST` | `/upload-pyq` | PDF → extract → insert into Supabase |

**`/generate-batch` and `/generate-open-batch` do not auto-save by
default.** Both request schemas take a `persist: bool = False` field; a
batch is only written to `questions`/`published_tests` when the caller sets
`persist: true`. This changed from the old always-save behavior — a caller
relying on the implicit write now gets nothing persisted unless it opts in.

### `POST /extract-plan` — not a FastAPI route

There is **no `/extract-plan` Python endpoint**, and there never has been —
confirmed via full repo history search, not just the current tree. Handout
plan extraction is triggered from Flutter as a Supabase Edge Function call
instead:

```
Student uploads handout PDF (Flutter → Supabase Storage)
        ↓
handout_url + handout_filename written to user_subjects row
        ↓
_triggerPlanExtraction() in subjects_datasource.dart calls
Supabase.instance.client.functions.invoke('extract-plan-proxy', ...)
        ↓
Edge Function extracts topics + generates weekly plan → inserts into study_plans
```

See [Tech Debt](#tech-debt) — this Edge Function currently points at a
placeholder and needs to be pointed at a real deployed URL before study plan
generation works end to end.

## AI Pipeline (DICL)

### Core Idea

Instead of generating generic questions, Skolar uses the college's own
Previous Year Questions (PYQs) as a reference. The generated questions match
that specific college's difficulty level, question style, and topic
distribution. No manual labeling or tagging is required.

### DICL (Diverse In-Context Learning)

Based on *"Exploring the Role of Diversity in Example Selection for
In-Context Learning"* (SIGIR 2025) — selecting diverse examples for the LLM
prompt produces better outputs than selecting only the most similar
examples. Naive selection causes topical bias; DICL uses MMR (Maximal
Marginal Relevance) to pick examples that are both relevant and diverse.

Token efficiency: MMR selects 5 diverse examples (~2,000 tokens) instead of
sending the whole bank — a 95% reduction with better output quality.

### Exam Type Filtering

Before MMR runs, the question bank is filtered to only include PYQs relevant
to the chosen exam type:

| Exam Type | PYQs used as examples |
|---|---|
| Quiz | quiz only |
| Midsem | midsem + quiz1 |
| Quiz 2 | quiz2 + midsem + quiz1 |
| Compre | compre + quiz2 + midsem + quiz1 |

If no questions match the filter, generation falls back to the full bank so
it never hard-fails. A null `exam_type` from Supabase is handled
defensively rather than raising during filtering.

### Generation Modes

**MCQ Blitz** (`/generate-batch`) — Compre Part A. N MCQs in parallel, 4
options + correct index. **Written Practice** (`/generate-open-batch`) —
Quiz, Midsem, Compre Part B. N open-ended questions, each with a
pre-generated structured model answer.

### Pipeline Steps

```
PDF Files (PYQs)
      ↓
pdfplumber — extract raw text
      ↓
Groq LLM (LLaMA 3.3 70B) — extract clean questions with marks, type, subject, year
      ↓
sentence-transformers (all-MiniLM-L6-v2) — embed each question → vector(384)
      ↓
Supabase (questions table, scoped by college + subject + exam_type)
      ↓
Exam type filter — keep only allowed exam_types for this mode
      ↓
sentence-transformers (all-MiniLM-L6-v2) — query embedding
      ↓
MMR Algorithm — select k diverse examples from question bank
      ↓
Groq LLM (LLaMA 3.3 70B) — generate MCQ or open question
      ↓  (written practice only)
Groq LLM (LLaMA 3.3 70B) — generate structured model answer
      ↓
Save to published_tests — only if the request set persist: true
      ↓
Questions returned to Flutter app
```

### MMR Algorithm

At every step, MMR picks the candidate that maximises:

```
score = alpha * relevance_to_query - (1 - alpha) * max_similarity_to_already_selected
```

Alpha = 0.7 means 70% relevance, 30% diversity. Greedy, builds selection one
item at a time. MMR currently runs over the **entire** question bank —
correct DICL first retrieves top-15 by cosine similarity, then runs MMR over
those 15. See [Tech Debt](#tech-debt).

## Study Plan Generation

```
Student uploads handout PDF (Flutter → Supabase Storage)
      ↓
handout_url + handout_filename written to user_subjects row
      ↓
Edge Function `extract-plan-proxy` (see above — not a FastAPI route)
      ↓
pdfplumber — extract raw text from handout
      ↓
Groq LLM — extract flat topic list from handout text
      ↓
Groq LLM — generate weekly study plan grouped by topic
      ↓
Deactivate existing active plan for this user_subject
      ↓
Insert new row into study_plans (topics jsonb, weekly_plan jsonb, raw_handout_data jsonb, is_active true)
```

The upload completes and the UI updates immediately; plan generation runs in
the background. Re-uploading a new handout deactivates the previous plan and
generates a fresh one. Schema: [DATABASE.md — `study_plans`](DATABASE.md#core-tables).
No Flutter page displays this data yet — see [FLUTTER.md](FLUTTER.md).

## PDF Upload Pipeline

`uploaded_pdfs` tracks any PDF through ingestion independent of which
feature triggered the upload; `questions.source_pdf_id` links extracted
questions back to the source upload.

The `POST /upload-pyq` endpoint — the one path the Flutter app and any
external API caller can reach — still only accepts `.pdf`, hard-rejecting
anything else by filename extension before `run_upload_pyq` is even called.
Multi-format extraction (below) is only reachable through the internal
`batch_upload.py` script.

## PYQ Batch Upload Pipeline (Internal Tooling)

`backend/pyq/batch_upload.py` walks a local directory of PYQs and pushes
every file through the same extraction/insert path the Flutter app's upload
button uses, one file at a time, without touching the UI or the FastAPI
endpoint. Dev/maintainer tool for seeding the question bank in bulk — not
exposed to students.

```bash
python backend/pyq/batch_upload.py D:\PYQs\CS_F372 \
    --subject "Compiler Construction" --college "BITS Pilani Hyderabad" \
    --exam-type compre --doc-type pyq
```

### Multi-Format Extraction

`extract_raw_text_any(file_bytes, filename)` dispatches by extension:

| Extension | Extractor |
|---|---|
| `.pdf` | `extract_raw_text` — pdfplumber, hybrid per-page OCR |
| `.docx` | `extract_docx_text` — `python-docx` + OCR of embedded images |
| `.doc` | `extract_doc_text` — converts to `.docx` via local LibreOffice (`soffice`), then `extract_docx_text`. Raises a clear error if `soffice` isn't on PATH |
| `.png` / `.jpg` / `.jpeg` / `.webp` / `.tif` / `.tiff` | `extract_image_text` — OCRs the image directly |

### Hybrid Per-Page OCR (PDF)

Every page is checked individually: a page with an embedded image and under
400 characters of extracted text gets OCR'd on its own, tagged
`[OCR supplement — page N, ...]`. The whole-document 200-character fallback
still runs afterward for fully image-only PDFs. OCR uses `easyocr` +
`pypdfium2` for PDF rendering; `pytesseract` handles images embedded inside
`.docx` files.

### Exam Type Resolution

`exam_type` is no longer required up front. Resolution order:

1. **Filename** — `_guess_exam_type()` looks for `compre` / `midsem` /
   `test1`/`quiz1` / `test2`/`quiz2` / `test3` in the filename.
2. **Document content** — `guess_exam_type_from_text()` scans the first 2000
   characters of extracted text if the filename guess is empty.
3. **`--exam-type` flag** — only tried if both above fail.

If all three come up empty, the file is skipped (`skipped_no_exam_type` in
the manifest) rather than silently mis-tagged. The result dict reports
`exam_type_source` (`"filename"` / `"content"` / `"flag"`).

### Resumability

Every file is hashed (SHA-256 of content, not filename) and recorded in
`<directory>/.upload_manifest.json` after every upload. Re-running after a
crash or `Ctrl+C` skips everything already `succeeded`.

### Scanned-Page Merging

Image files whose filename ends in a page-number suffix (`...p1`,
`...page 2`, `..._3`) are grouped by base name, sorted numerically, and
merged in-memory into one multi-page PDF via Pillow before upload.

### `download_papers.py`

A standalone scraper (`backend/download_papers.py`) for bulk-downloading
question papers from a DSpace-based college repository, for feeding into
`batch_upload.py`. Hardcodes an internal-network base URL — local/dev tool
only.

```bash
python backend/download_papers.py "CS F372"
```

## Pipeline Evaluation

```bash
cd backend/pyq/rag
python evaluate.py
```

Requires a server already running on `http://localhost:8000` (`evaluate.py`
talks to it over HTTP — it doesn't need to run from inside a specific venv,
just needs `requests`, `numpy`, `sentence-transformers` importable). Spends
real Groq tokens (10 MCQs + 5 open-ended per run) — don't run it reflexively.

| Test | What it checks | Pass threshold |
|---|---|---|
| Health | Server is reachable | 200 OK |
| Stats | Question bank has data | total_questions > 0 |
| MCQ Accuracy | correct_index is 0–3, all 4 options distinct, non-empty question | 10/10 |
| MCQ Diversity | Pairwise cosine similarity across 10 generated questions | avg < 0.5, max < 0.8 |
| Open Quality | Non-empty questions, substantive answers (>50 chars), not MCQ format | 5/5 |
| Open Diversity | Pairwise cosine similarity across 5 open-ended questions | avg < 0.5, max < 0.8 |

## Running RLS Isolation Tests

`backend/tests/test_rls.py` verifies students can't read each other's rows
across `user_topic_weights`, `nova_capacity_log`, `standing_flags`,
`situation_flags`, and `nova_config`, and that a fully unauthenticated
client gets 0 rows back too. Needs two real Supabase Auth accounts.

```bash
cd backend
pip install pytest
pytest tests/test_rls.py
```

`TEST_STUDENT_A_EMAIL`/`TEST_STUDENT_B_EMAIL` (+ passwords) need to already
exist as real Supabase Auth accounts — nothing in this repo provisions
them. If `SUPABASE_URL`/`SUPABASE_KEY` are unset the whole module skips; if
the two test accounts can't sign in, cross-student tests skip individually.
`pytest` isn't in `backend/requirements.txt` — install it separately, or use
`backend/requirements-dev.txt` which includes it alongside `ruff`/`mypy`/`httpx`.

The full `backend/tests/` suite (not just RLS) is run via
`cd backend && python -m pytest tests/` — see
[`backend/pyq/ONBOARDING.md` §6](backend/pyq/ONBOARDING.md) for what each
test file covers (golden-value refactor tests, bench tests, rate-limiter
tests, etc.).

## CI

`.github/workflows/ci.yml` **does** include `backend/**` in its path filter
(feeding a `python-lint` job: `ruff check`, `ruff check --select S`, a
retry-decorator grep check, and `mypy backend/nova` when that directory
exists). What it does **not** do is run any tests — there's no `pytest` step
anywhere in the workflow. So `backend/tests/test_rls.py` (and every other
test under `backend/tests/`) is linted/type-checked-adjacent but never
executed in CI; it has to be run manually.

## Tech Stack

| Purpose | Tool |
|---|---|
| PDF text extraction | `pdfplumber` |
| PDF page OCR (hybrid per-page + whole-doc fallback) | `easyocr` + `pypdfium2` |
| `.docx` / `.doc` extraction | `python-docx` (+ local LibreOffice `soffice` for legacy `.doc`) |
| Image / embedded-image OCR | `pytesseract`, `pillow` |
| Question extraction | Groq API — LLaMA 3.3 70B |
| Topic + study plan extraction | Groq API — LLaMA 3.3 70B |
| Semantic embeddings | `sentence-transformers` — all-MiniLM-L6-v2 |
| Diversity selection | MMR algorithm (numpy) |
| MCQ + open question generation | Groq API — LLaMA 3.3 70B |
| Backend API | FastAPI + uvicorn |
| Deployment | Railway |
| Data store | Supabase (PostgreSQL + pgvector) |
| File storage | Supabase Storage (handouts bucket) |

Install via `pip install -r backend/requirements.txt` (pinned versions —
prefer this over hand-listing packages).

## Tech Debt

- **Multi-format PYQ extraction not reachable from the app or `/upload-pyq`.**
  `.docx`/`.doc`/image support and content-based exam-type detection only
  run through `batch_upload.py`, which calls `run_upload_pyq` directly. The
  public endpoint still hard-rejects any filename not ending in `.pdf`.
- **`_triggerPlanExtraction` needs a real deployed URL.** Currently calls
  the `extract-plan-proxy` Edge Function as a placeholder — needs to point
  at the real deployed target before study plan generation works end to end
  for real users.
- **Full DICL — top-15 cosine retrieval not implemented.** MMR runs over
  the entire bank instead of a pre-filtered top-15. Needs 100+ questions per
  subject to be measurable.
- **`download_papers.py` — hardcoded internal-network URL.** Fine for a
  one-off scraping run on a maintainer's machine; would need to become
  configurable (env var/CLI flag) before anyone else could use it as-is.
- **Stale path references elsewhere in the repo.** `lib/core/ai/rag_llms/`
  no longer exists, but is still referenced by `.github/dependabot.yml`
  (pip ecosystem directory), `.vscode/settings.json` (Pylance extra paths),
  `ARCHITECTURE.md`, `CONTRIBUTING.md` (CI path-filter description),
  `INDEX.md`, and `create_security_issues.ps1`. None of these are
  documentation files this pass covers, but they're wrong and worth fixing
  in a follow-up pass.

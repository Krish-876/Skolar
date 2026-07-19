# Skolar

An AI-powered exam preparation platform built with Flutter. Helps students track syllabus progress, attempt mock tests, get AI-driven predictions, and visualize their performance — all in one place.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Mock Test Platform](#mock-test-platform)
- [AI Pipeline (DICL)](#ai-pipeline-dicl)
- [Exam Prediction Feature](#exam-prediction-feature)
- [Focus Session](#focus-session)
- [Community Feed](#community-feed)
- [Subjects and Handout Upload](#subjects-and-handout-upload)
- [Test Attempts, Question Results, and AI Evaluation](#test-attempts-question-results-and-ai-evaluation)
- [PDF Upload Pipeline](#pdf-upload-pipeline)
- [Nova — Adaptive Prep Planner](#nova--adaptive-prep-planner)
- [Folder Structure](#folder-structure)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Dashboard -- How It Works](#dashboard----how-it-works)
- [Running the App](#running-the-app)
- [Code Generation](#code-generation)
- [Running the Backend](#running-the-backend)
- [Adding a New Feature](#adding-a-new-feature)
- [Tech Debt](#tech-debt)
- [Roadmap](#roadmap)

---

## Project Overview

An AI-powered study platform designed for college exam preparation. It offers personalized mock tests calibrated to a student's college difficulty level using Diverse In-Context Learning (DICL), along with PYQ analysis, performance analytics, goal tracking, and distraction-free focus sessions. Students can also access a community feed of AI-generated tests shared across subjects within their college ecosystem. Authentication through college email ensures secure, college-specific access to resources and data isolation.

---

## Architecture

Follows **Clean Architecture** with a **feature-first** folder structure. Every feature is fully isolated across three layers.

```
Presentation  ->  Domain  ->  Data
```

- **Presentation**: Riverpod providers, pages, widgets. Knows nothing about data sources.
- **Domain**: Pure Dart. Entities, repository interfaces, use cases. No Flutter imports.
- **Data**: DTOs, data sources, repository implementations. Talks to Supabase, APIs, or local storage.

Dependencies always point **inward** — data depends on domain, presentation depends on domain, nothing depends on presentation or data directly.

### State Management Flow

```
UI Widget
   ↓  watches
Riverpod Provider (AsyncNotifierProvider / NotifierProvider)
   ↓  calls
UseCase
   ↓  calls
Repository (abstract interface)
   ↓  implemented by
RepositoryImpl
   ↓  calls
DataSource (Supabase / FastAPI / local storage)
```

### Error Handling

- Data layer catches exceptions, returns `Either<Failure, Data>`
- Domain layer defines `Failure` types
- Presentation layer handles `Either` results with `state.when(loading, error, data)`

---

## Mock Test Platform

The mock test feature lets students take AI-generated tests calibrated to their subject, college, and exam type. It follows full Clean Architecture across all layers.

### Exam Types

| Type | Mode | Default Questions | Max Questions | Description |
|---|---|---|---|---|
| Quiz | Written Practice | 5 | 10 | Short open-ended questions, model answers included |
| Midsem | Written Practice | 6 | 10 | Medium difficulty, draws from midsem + quiz PYQs |
| Compre Part A | MCQ Blitz | 8 | 15 | Timed MCQ quiz, draws from full syllabus PYQs |
| Compre Part B | Written Practice | 4 | 10 | Long-answer practice, draws from full syllabus PYQs |

### Flutter Files

| File | Role |
|---|---|
| `domain/entities/mock_test_entity.dart` | `MockTestEntity`, `McqQuestion`, `OpenQuestion` — freezed domain models |
| `domain/repositories/mock_test_repository.dart` | Abstract repository interface |
| `domain/usecases/mock_test_usecases.dart` | `FetchMcqQuestionsUseCase`, `FetchOpenQuestionsUseCase`, `FetchQuestionsByIdsUseCase` |
| `data/dtos/mock_test_dto.dart` | DTOs with `fromJson` / `toJson` |
| `data/datasources/mock_test_datasource.dart` | Calls `/generate-batch`, `/generate-open-batch`, fetches by IDs from Supabase, sources subjects dynamically per user |
| `data/repository_impl/mock_test_repository_impl.dart` | Wraps datasource in `Either<Failure, T>` |
| `presentation/providers/mock_tests_provider.dart` | `MockTestNotifier` — state, API calls, exam mode routing, `loadExistingTest` |
| `presentation/pages/mock_tests_pages.dart` | Full UI: setup screen, loading, error, MCQ flow, written practice flow, result screen |
| `shared/models/exam_type.dart` | `ExamType` enum — single source of truth used across mock tests and feed |

### `ExamMode` Mapping

```dart
ExamType.compreA  →  ExamMode.mcqBlitz        →  POST /generate-batch
ExamType.quiz     →  ExamMode.writtenPractice  →  POST /generate-open-batch
ExamType.midsem   →  ExamMode.writtenPractice  →  POST /generate-open-batch
ExamType.compreB  →  ExamMode.writtenPractice  →  POST /generate-open-batch
```

### Load Existing Test

`loadExistingTest(questionIds, examType)` fetches questions by their Supabase IDs and reconstructs the test state. Used by the community feed Attempt button. Currently only supports written practice exam types — see Tech Debt for Compre Part A limitation.

### Dynamic Subject Sourcing

The mock test setup screen pulls the student's subject list from their actual `user_subjects` enrollment rather than a hardcoded list.

---

## AI Pipeline (DICL)

### Core Idea

Instead of generating generic questions, Skolar uses the college's own Previous Year Questions (PYQs) as a reference. The generated questions match that specific college's difficulty level, question style, and topic distribution. No manual labeling or tagging is required — the system infers difficulty from context.

### DICL (Diverse In-Context Learning)

The pipeline is based on the paper *"Exploring the Role of Diversity in Example Selection for In-Context Learning"* published at SIGIR 2025. The key finding is that selecting diverse examples for the LLM prompt produces better outputs than selecting the most similar examples.

Naive example selection picks the most similar PYQs to the query. This causes topical bias — the LLM sees only one subtopic and generates repetitive questions. DICL uses MMR (Maximal Marginal Relevance) to pick examples that are both relevant and diverse, spreading coverage across different topics.

Token efficiency: instead of sending all PYQs to the LLM, MMR selects 5 diverse examples (~2,000 tokens). This is a 95% reduction in token usage with better output quality.

### Exam Type Filtering

Before MMR runs, the question bank is filtered to only include PYQs relevant to the chosen exam type:

| Exam Type | PYQs used as examples |
|---|---|
| Quiz | quiz only |
| Midsem | midsem + quiz1 |
| Quiz 2 | quiz2 + midsem + quiz1 |
| Compre | compre + quiz2 + midsem + quiz1 |

If no questions match the filter, the pipeline falls back to the full bank so generation never hard-fails. A null `exam_type` value from Supabase is handled defensively so it no longer raises an `AttributeError` during filtering.

### Generation Modes

**MCQ Blitz** (`/generate-batch`) — used for Compre Part A. Generates N MCQs in parallel, each with 4 options and a correct index. Timed quiz UI with score tracking.

**Written Practice** (`/generate-open-batch`) — used for Quiz, Midsem, and Compre Part B. Generates N open-ended questions, each with a pre-generated structured model answer. Two practice views: flashcard (one at a time, reveal answer) and paper (all questions scrollable).

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
Auto-save to published_tests (written practice only — see Tech Debt)
      ↓
Questions returned to Flutter app
```

### Study Plan Generation Pipeline

```
Student uploads handout PDF (Flutter → Supabase Storage)
      ↓
handout_url + handout_filename written to user_subjects row
      ↓
Fire-and-forget POST /extract-plan (FastAPI)
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

The upload completes and the UI updates immediately. Plan generation runs in the background and persists permanently in `study_plans`. Re-uploading a new handout deactivates the previous plan and generates a fresh one.

### MMR Algorithm

At every step, MMR picks the candidate that maximises:

```
score = alpha * relevance_to_query - (1 - alpha) * max_similarity_to_already_selected
```

Alpha = 0.7 means 70% relevance, 30% diversity. Greedy algorithm that builds selection one item at a time.

### Supabase Schema

> The schema below reflects the live database. Tables with no corresponding Flutter/Python description yet are marked **(schema only)**. Nova-specific tables are documented in the [Nova section](#nova--adaptive-prep-planner).

#### `institutions` table

```
id                uuid, primary key, default gen_random_uuid()
name              text, not null
short_name        text, not null, unique
email_patterns    jsonb, not null, default '[]'::jsonb
website           text, nullable
created_at        timestamptz, not null, default now()
```

#### `campuses` table

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE
name              text, not null
short_name        text, not null, unique
subdomain         text, nullable
location          text, nullable
created_at        timestamptz, not null, default now()
```

#### `subjects` table

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE
name              text, not null
short_name        text, nullable
academic_year     smallint, not null, check (1–4)
semester          smallint, nullable
credits           smallint, nullable
campus_id         uuid, nullable, references campuses.id
created_at        timestamptz, not null, default now()
```

#### `users` table

```
id                uuid, primary key, references auth.users(id)
email             text, not null, unique
full_name         text, nullable
roll_number       text, nullable
college           text, nullable
institution_id    uuid, nullable, references institutions.id
campus_id         uuid, nullable, references campuses.id
academic_year     smallint, nullable, check (1–4)
avatar_url        text, nullable
branch            text, nullable
plan              text, not null, default 'free'
role              text, not null, default 'student', check (student|admin|super_admin)
semester_credits  smallint, nullable
created_at        timestamptz, not null, default now()
updated_at        timestamptz, not null, default now()
```

RLS policies: insert, update, select scoped to `auth.uid()`.

#### `custom_subjects` table **(schema only)**

User- or institution-defined subjects that don't exist in the shared `subjects` catalog yet.

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE
course_code       text, not null
name              text, not null
credits           smallint, nullable
created_at        timestamptz, not null, default now()
```

#### `user_subjects` table

```
id                    uuid, primary key, default gen_random_uuid()
user_id               uuid, not null, references users.id ON DELETE CASCADE
subject_id            uuid, nullable, references subjects.id ON DELETE CASCADE
custom_subject_id     uuid, nullable, references custom_subjects.id ON DELETE SET NULL
semester              text, not null
handout_url           text, nullable
handout_filename      text, nullable
handout_uploaded_at   timestamptz, nullable
```

**Constraint:** exactly one of `subject_id` / `custom_subject_id` must be set — enforced via CHECK constraint `user_subjects_subject_check`.

> `topic_schedule` column was present in an earlier version and has been dropped. Study plan data lives in `study_plans`.

#### `user_subject_exams` table

Stores exam dates per enrolled subject. Nova uses this for `time_left` urgency signal.

```
id                uuid, primary key, default gen_random_uuid()
user_subject_id   uuid, not null, references user_subjects.id ON DELETE CASCADE
exam_type         text, not null, check (quiz1|midsem|quiz2|compre)
exam_date         date, not null
created_at        timestamptz, not null, default now()
unique            (user_subject_id, exam_type)
```

RLS: scoped to student via `user_subject_id` join.

#### `topics` table

Canonical topic list extracted from PYQs and handouts. All free-text `topic` columns across the schema have a corresponding `topic_id` FK to this table.

```
id                  uuid, primary key, default gen_random_uuid()
subject_id          uuid, nullable, references subjects.id
custom_subject_id   uuid, nullable, references custom_subjects.id
name                text, not null
created_at          timestamptz, not null, default now()
```

**Constraint:** exactly one of `subject_id` / `custom_subject_id` must be set. Case-insensitive unique indexes prevent "Normalization" and "normalization" from being stored as separate topics.

RLS: read-only for all authenticated users. Write access pending pipeline key confirmation (service-role vs anon).

#### `questions` table

```
id                  uuid, primary key, default gen_random_uuid()
question_text       text, not null
marks               integer, not null, default 0
question_type       text, not null — mcq|short_answer|long_answer|numerical
subject             text, not null  — legacy text, kept for pipeline compatibility
college             text, not null  — legacy text, kept for pipeline compatibility
paper_year          integer, nullable
academic_year       smallint, nullable
exam_type           text, nullable — quiz1|midsem|quiz2|compre|generated
embedding           vector(384), nullable — all-MiniLM-L6-v2
published           boolean, not null, default false
published_by        uuid, nullable, references users.id ON DELETE SET NULL
published_at        timestamptz, nullable
created_at          timestamptz, not null, default now()
options             jsonb, nullable — MCQ options array
correct_index       smallint, nullable — correct option index 0–3
subject_id          uuid, nullable, references subjects.id — canonical FK
campus_id           uuid, nullable, references campuses.id
source_pdf_id       uuid, nullable, references uploaded_pdfs.id
doc_type            text, nullable
topic               text, nullable — legacy free text, kept for pipeline compatibility
topic_id            uuid, nullable, references topics.id — canonical FK
has_diagram         boolean, not null, default false
sub_parts           jsonb, nullable
model_answer        text, nullable
answer_source       text, nullable
confidence_score    numeric, nullable
marks_inferred      boolean, not null, default false
```

`subject` and `topic` text columns coexist with their FK replacements (`subject_id`, `topic_id`) during migration. New code should write both; future cleanup will drop the text columns once the pipeline is fully migrated.

#### `published_tests` table

```
id                uuid, primary key, default gen_random_uuid()
published_by      uuid, nullable, references users.id ON DELETE SET NULL
college           text, not null — legacy
subject           text, not null — legacy
subject_id        uuid, nullable — canonical FK
campus_id         uuid, nullable
exam_type         text, not null, check (quiz1|midsem|quiz2|compre|generated)
question_ids      uuid[], not null — plain array, not FK-enforced
upvotes           integer, not null, default 0
downvotes         integer, not null, default 0
attempts          integer, not null, default 0
created_at        timestamptz, not null, default now()
```

`question_ids` is a plain array — deleting a `questions` row will silently leave a dangling ID here.

#### `post_votes` table

```
user_id           uuid, not null, references users.id ON DELETE CASCADE
post_id           uuid, not null, references published_tests.id ON DELETE CASCADE
vote              smallint, not null, check (1 or -1)
created_at        timestamptz, not null, default now()
primary key       (user_id, post_id)
```

#### `study_plans` table

```
id                uuid, primary key, default gen_random_uuid()
user_subject_id   uuid, not null, references user_subjects.id ON DELETE CASCADE
user_id           uuid, not null, references users.id ON DELETE CASCADE
subject_name      text, not null — denormalized for query convenience
handout_url       text, not null — which handout version this plan was generated from
topics            jsonb, not null — flat list of topic strings
weekly_plan       jsonb, not null — array of {week, topics, study_hours, focus}
raw_handout_data  jsonb, nullable — full extracted handout data, preserves all content
is_active         boolean, not null, default true
generated_at      timestamptz, not null, default now()
updated_at        timestamptz, not null, default now()
```

Only one plan per `user_subject_id` is active at a time. Uploading a new handout deactivates the previous plan before inserting the new one.

#### `uploaded_pdfs` table **(schema only)**

```
id                    uuid, primary key, default gen_random_uuid()
uploaded_by           uuid, nullable, references users.id ON DELETE SET NULL
uploaded_as           text, not null, default 'student', check (student|admin)
storage_path          text, not null
doc_type              text, not null, check (pyq|tutorial|solution|lab|misc)
subject_id            uuid, nullable, references subjects.id
campus_id             uuid, nullable, references campuses.id
exam_type             text, nullable
paper_year            integer, nullable
topic                 text, nullable
topic_id              uuid, nullable, references topics.id
status                text, not null, default 'pending', check (pending|running|succeeded|partial|failed)
questions_extracted   integer, not null, default 0
questions_failed      integer, not null, default 0
created_at            timestamptz, not null, default now()
```

#### `test_attempts` table **(schema only)**

```
id                uuid, primary key, default gen_random_uuid()
test_id           uuid, not null, references published_tests.id ON DELETE CASCADE
user_id           uuid, not null, references users.id ON DELETE CASCADE
subject_id        uuid, nullable, references subjects.id
exam_type         text, nullable, check (quiz1|midsem|quiz2|compre)
attempt_number    smallint, not null, default 1
total_marks       integer, not null, default 0
obtained_marks    integer, not null, default 0
completed_at      timestamptz, not null, default now()
unique            (test_id, user_id, attempt_number)
```

#### `question_results` table **(schema only)**

```
id                  uuid, primary key, default gen_random_uuid()
attempt_id          uuid, not null, references test_attempts.id ON DELETE CASCADE
question_id         uuid, not null, references questions.id
topic               text, nullable — legacy free text
topic_id            uuid, nullable, references topics.id — canonical FK
is_correct          boolean, nullable
marks_available     integer, not null, default 0
marks_obtained      numeric, not null, default 0
self_rating         smallint, nullable, check (1–5)
error_category      text, nullable, check (concept_gap|practice_gap|careless)
ai_evaluation_id    uuid, nullable, references ai_evaluations.id ON DELETE SET NULL
created_at          timestamptz, not null, default now()
```

#### `ai_evaluations` table **(schema only)**

```
id                    uuid, primary key, default gen_random_uuid()
question_result_id    uuid, not null, references question_results.id ON DELETE CASCADE
user_id               uuid, not null, references users.id ON DELETE CASCADE
question_id           uuid, not null, references questions.id
answer_photo_url      text, nullable
extracted_text        text, nullable
model_answer_used     text, nullable
score_awarded         numeric, nullable
max_score             numeric, nullable
feedback_json         jsonb, nullable
evaluated_at          timestamptz, not null, default now()
```

#### `user_topic_weights` table

EMA-style weakness signal per topic per student.

```
id                  uuid, primary key, default gen_random_uuid()
user_id             uuid, not null, references users.id
subject_id          uuid, nullable, references subjects.id — null for custom subjects
custom_subject_id   uuid, nullable, references custom_subjects.id — null for catalog subjects
topic               text, not null — legacy free text
topic_id            uuid, nullable, references topics.id — canonical FK
weight              numeric, not null, default 0.5, check (0–1)
created_at          timestamptz, not null, default now()
updated_at          timestamptz, not null, default now()
unique              (user_id, subject_id, topic)
```

**Constraint:** exactly one of `subject_id` / `custom_subject_id` must be set — enforced via CHECK constraint `user_topic_weights_subject_check`.

### Cascade Behavior Summary

| Parent deleted | Cascades to | Effect |
|---|---|---|
| `users` | `ai_evaluations`, `post_votes`, `study_plans`, `test_attempts`, `user_subjects`, `nova_*` tables | hard delete |
| `institutions` | `campuses`, `custom_subjects`, `subjects` | hard delete |
| `subjects` | `user_subjects` | hard delete — but blocked by `NO ACTION` from `questions`, `test_attempts`, `uploaded_pdfs` |
| `user_subjects` | `study_plans`, `user_subject_exams`, `staleness_tracker` | hard delete |
| `published_tests` | `post_votes`, `test_attempts` | hard delete |
| `test_attempts` | `question_results` | hard delete |
| `question_results` | `ai_evaluations` | hard delete |
| `users` (as `published_by` / `uploaded_by`) | `published_tests`, `questions`, `uploaded_pdfs` | `SET NULL` — content kept, authorship orphaned |
| `custom_subjects` | `user_subjects.custom_subject_id` | `SET NULL` — enrollment kept, link cleared |
| `ai_evaluations` | `question_results.ai_evaluation_id` | `SET NULL` |
| `questions` | `ai_evaluations`, `question_results` | `NO ACTION` — delete blocked while referenced |

### Model Answer Structure

Model answers are structured markdown, calibrated to marks:

- **1–3 marks**: 2–3 sentences, bold key terms, no headings
- **4–6 marks**: direct answer + `### Steps` (computational) or `### Key points` (conceptual)
- **7+ marks**: full worked answer with `### Working`, `### Result`, or `### Approach / Explanation / Conclusion`

### FastAPI Endpoints

The backend is deployed on Railway. Start locally with:

```bash
uvicorn main:app --reload --port 8000
```

#### Question Generation + Upload (`main.py`)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Sanity check |
| `GET` | `/stats` | Bank stats scoped by college |
| `GET` | `/questions` | Browse/filter the question bank |
| `POST` | `/generate` | One open-ended question |
| `POST` | `/generate-batch` | N MCQs in parallel (Compre Part A) |
| `POST` | `/generate-open-batch` | N open questions + model answers, auto-saves to `published_tests` |
| `POST` | `/upload-pyq` | PDF → extract → insert into Supabase |
| `POST` | `/extract-plan` | Handout PDF → topic list + weekly study plan → insert into `study_plans` |

#### Nova (`nova_router.py`, mounted at `/nova`)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/nova/capacity` | Submit today's capacity tap (light/normal/packed) |
| `POST` | `/nova/trigger/check` | Run trigger layer — decides if a reasoning pass is needed |
| `POST` | `/nova/plan/generate` | Run reasoning pass, return ranked focus list + time budgets + why |
| `GET` | `/nova/plan/current` | Fetch today's active plan |
| `GET` | `/nova/plan/log` | Full audit trail of all plan changes |
| `POST` | `/nova/flags/situation` | Propose + confirm a situation flag |
| `POST` | `/nova/flags/standing` | Propose + confirm a standing flag |
| `DELETE` | `/nova/flags/{flag_id}` | Remove an active flag |
| `POST` | `/nova/career/track` | Add a career/industry unit to track |
| `POST` | `/nova/career/relevance/refresh` | Trigger industry relevance web lookup |
| `GET` | `/nova/career/tracks` | List active career units with relevance + staleness |
| `POST` | `/nova/conversation` | Send a message to Nova — stores turn, extracts facts, proposes writes |
| `GET` | `/nova/conversation/history` | Fetch active conversation history |
| `POST` | `/nova/override/one-off` | Log a one-off override — never persisted to schema |
| `GET` | `/nova/proposals/pending` | List unconfirmed proposals awaiting confirmation |
| `POST` | `/nova/proposals/{proposal_id}/confirm` | Confirm a proposal — triggers schema write + reasoning pass |
| `DELETE` | `/nova/proposals/{proposal_id}` | Reject and discard a pending proposal |

#### Notes

- All `/nova/*` endpoints are scoped to the authenticated student — no cross-student data access
- Nova never calls `pipeline.py` — question generation and Nova are fully separate
- `/nova/trigger/check` is called on app open, after test submission, and after flag confirmation
- `/nova/conversation` never writes silently — all fact writes go through `/nova/proposals/{id}/confirm`
- Minor re-ranks (no LLM call) and full reasoning passes both go through `/nova/plan/generate` — trigger severity decided beforehand by `/nova/trigger/check`

> These `/nova/*` endpoints describe the planned Phase 5 backend (`nova_router.py`, not yet built). The Nova CLI prototype that exists today (see [Nova CLI (Q&A Prototype)](#nova-cli-qa-prototype)) does not go through FastAPI at all — it talks to Supabase and Groq directly from a local script.

#### `POST /extract-plan` — Request body

```json
{
  "user_subject_id": "<uuid>",
  "user_id": "<uuid>",
  "subject_name": "Operating Systems",
  "handout_url": "https://..."
}
```

> Note: this endpoint is not yet wired in Flutter — see Tech Debt.

### Pipeline Evaluation

`evaluate.py` measures generation quality across two dimensions: accuracy and diversity.

```bash
cd lib/core/ai/rag_llms
myenv311\Scripts\activate
python evaluate.py
```

**Tests run:**

| Test | What it checks | Pass threshold |
|---|---|---|
| Health | Server is reachable | 200 OK |
| Stats | Question bank has data | total_questions > 0 |
| MCQ Accuracy | correct_index is 0–3, all 4 options distinct, non-empty question | 10/10 |
| MCQ Diversity | Pairwise cosine similarity across 10 generated questions | avg < 0.5, max < 0.8 |
| Open Quality | Non-empty questions, substantive answers (>50 chars), not MCQ format | 5/5 |
| Open Diversity | Pairwise cosine similarity across 5 open-ended questions | avg < 0.5, max < 0.8 |

**Current baseline (BPHC / Artificial Intelligence, 33 questions):**

> Note: eval scores at this bank size are not meaningful — 33 questions is too small for MMR to diversify effectively. Re-run when the bank reaches 100+ questions per subject.

| Metric | Score | Status |
|---|---|---|
| MCQ avg similarity | 0.435 | ✅ Pass |
| MCQ max similarity | 0.996 | ❌ Fail — duplicate DFS question in bank |
| Open avg similarity | 0.539 | ❌ Fail — bank skewed toward RL questions |
| Open max similarity | 0.887 | ❌ Fail — bank skewed toward RL questions |

### Thread Safety

Multiple concurrent generation requests are safe. The `ThreadPoolExecutor` for parallel generation is capped at 3 workers to stay within Groq free-tier rate limits. Supabase handles concurrent reads natively.

### Pipeline Location

```
lib/core/ai/rag_llms/
  main.py              — FastAPI app and all endpoints
  pipeline.py          — DICL pipeline: parsing, embedding, MMR, generation, bank I/O, study plan extraction
  .env                 — GROQ_API_KEY, SUPABASE_URL, SUPABASE_KEY (not committed)
  evaluate.py          — Pipeline evaluation: accuracy, diversity scoring
```

---

## Exam Prediction Feature

The exam prediction feature lets students browse and filter the college question bank directly from the app.

### Flutter Files

| File | Role |
|---|---|
| `exam_prediction_pages.dart` | Main page with tabs: Question Bank browser |
| `exam_prediction_datasource.dart` | Calls `GET /questions` with filters |
| `exam_prediction_repository_impl.dart` | Wraps datasource in `Either<Failure, T>` |
| `exam_prediction_provider.dart` | Riverpod notifier for question bank state |
| `exam_prediction_usecases.dart` | Use cases: `GetQuestionsUseCase`, `GetStatsUseCase` |
| `exam_prediction_entity.dart` | `QuestionEntity`, `StatsEntity` domain models |

### Available Filters

Questions can be filtered by `subject`, `year`, `exam_type`, `question_type`, and `source`.

---

## Focus Session

The focus session feature gives students a distraction-free countdown timer for managing structured study blocks. It is self-contained with no backend dependency — all state lives in `FocusTimerController`.

### Duration Picker

`FocusSetupPage` provides a full-screen custom duration picker, navigated to from the Custom chip.

- A hero time display (large gradient text) updates in real time as the slider moves
- A `Slider` ranges from 5 minutes to 3 hours with 1-minute steps and a custom `GlowThumbShape` thumb
- Three preset chips (Pomodoro, 45 min, 1 hr) sync bidirectionally with the slider
- A **Session breakdown** card shows the chosen duration in hours/minutes and the equivalent pomodoro count
- Tapping **Start session** calls `onConfirm(seconds)` and pops back to the timer page

### Architecture

The focus session is presentation-layer only. There is no domain layer or backend call. State is managed by `FocusTimerController`, a `ChangeNotifier` consumed directly by `FocusTimerPage` via `addListener`.

This is intentional — the timer resets if the user leaves the app (AppLifecycleState observer), enforcing distraction-free focus. If session history or streak tracking is added in Phase 5, a `StorageService.saveSession()` call should be added inside `_onTick` when `_secondsLeft` reaches zero.

### Flutter Files

| File | Role |
|---|---|
| `controllers/focus_timer_controller.dart` | State machine, countdown ticker, wave animation |
| `presentation/focus_timer_page.dart` | Main timer screen: bonsai hero, readout, slide track, give-up sheet |
| `presentation/focus_setup_page.dart` | Custom duration picker: hero time, preset chips, slider, session card |
| `widgets/focus_background.dart` | Custom painter: base, ambient glow, sliding surface panel |
| `widgets/glow_thumb_shape.dart` | Custom `SliderComponentShape` with glow halo for the setup page slider |
| `widgets/present_chip.dart` | Animated chip widget used for preset selection on both pages |
| `data/models/focus_present.dart` | `FocusPreset` value type with three default presets |

---

## Community Feed

The community feed surfaces AI-generated tests created by students on college subjects. It is backed by a live Supabase query against the `published_tests` table.

### How a Test Gets Published

```
Student generates a written practice test (Quiz / Midsem / Compre B)
        ↓
Backend auto-saves questions to Supabase and inserts row into published_tests
        ↓
published_tests row contains: subject, college, exam_type, question_ids[], published_by
        ↓
Community feed shows the test with subject, question count, upvotes, attempts
        ↓
Attempt button calls loadExistingTest(questionIds, examType) on MockTestNotifier
```

Note: Compre Part A (MCQ Blitz) tests are not currently published or displayed in the feed — see Tech Debt.

### Feed Architecture

The feed follows the same Clean Architecture pattern as every other feature. The datasource was swapped from local mock data to the live API in one file:

```
FeedLocalDataSourceImpl  →  FeedRemoteDataSourceImpl
        (mock JSON)               (Supabase: published_tests table)
```

Everything above — `FeedRepositoryImpl`, `GetFeedUseCase`, `FeedNotifier`, `FeedPage`, `FeedPostCard` — stayed identical.

### Vote Persistence

Upvote/downvote state is persisted to Supabase via the `post_votes` table, with optimistic UI updates on the client so the vote reflects instantly before the write confirms.

### Flutter Files

| File | Role |
|---|---|
| `data/datasources/feed_remote_datasource.dart` | Queries `published_tests` from Supabase |
| `data/dtos/feed_post_dto.dart` | `fromSupabase` factory, `questionIds`, `examType` fields |
| `data/repository_impl/feed_repository_impl.dart` | Wraps remote datasource in `Either<Failure, T>` |
| `domain/entities/feed_post_entity.dart` | `examType`, `questionIds` fields |
| `presentation/providers/feed_provider.dart` | College read from `userProvider` |
| `presentation/pages/feed_page.dart` | College from `userProvider` |
| `presentation/widgets/feed_post_card.dart` | Attempt button wired to `loadExistingTest`, vote buttons wired to Supabase |

---

## Subjects and Handout Upload

The subjects feature lets students view their enrolled subjects for the current semester and upload a course handout PDF per subject. Uploading a handout triggers automatic AI study plan generation in the background.

### How Handout Upload Works

```
Student taps "Upload handout" chip on a subject card
        ↓
FilePicker.pickFiles() — native PDF picker (file_picker v11)
        ↓
PDF uploaded to Supabase Storage: handouts/{userId}/{userSubjectId}/{filename}
        ↓
handout_url + handout_filename written to user_subjects row
        ↓
UI chip updates to show filename immediately
        ↓
Fire-and-forget POST /extract-plan → study plan generated and saved to study_plans
```

The upload and UI update are synchronous from the user's perspective. Plan generation is asynchronous — it completes in the background and persists permanently. Re-uploading replaces the handout and regenerates the plan.

### Supabase Storage

Bucket: `handouts` (public)

RLS policies:
- `INSERT` — authenticated users only, `bucket_id = 'handouts'`
- `SELECT` — authenticated users only, `bucket_id = 'handouts'`

### Flutter Files

| File | Role |
|---|---|
| `data/datasources/subjects_datasource.dart` | `uploadHandout` — uploads to Storage, updates `user_subjects`, triggers plan extraction |
| `data/repository_impl/subjects_repository_impl.dart` | Wraps `uploadHandout` in `Either<Failure, SubjectEntity>` |
| `presentation/pages/subjects_pages.dart` | `_SubjectsNotifier.uploadHandout`, `_HandoutChip`, `_pickAndUploadHandout` |

### `_HandoutChip` States

| State | Appearance |
|---|---|
| No handout | "Upload handout" with upload icon, dimmed border |
| Uploading | Spinner + "Generating plan…" text |
| Handout uploaded | Filename + ↺ icon, primary color border |

---

## Test Attempts, Question Results, and AI Evaluation

> Schema is live in Supabase; no Flutter or FastAPI code description exists yet for this flow.

A `test_attempts` row represents one student's attempt at a `published_tests` entry. Each question answered within that attempt becomes a `question_results` row, capturing correctness, marks, error category, and an optional self-rating. For written/photographed answers, a `question_results` row can link to an `ai_evaluations` row.

```
published_tests
      ↓ (student attempts)
test_attempts  (total_marks, obtained_marks, exam_type, completed_at)
      ↓ (one row per question)
question_results  (is_correct, marks_obtained, error_category, topic_id, self_rating)
      ↓ (optional, for photographed/handwritten answers)
ai_evaluations  (answer_photo_url → extracted_text → score_awarded, feedback_json)
```

---

## PDF Upload Pipeline

> Schema is live in Supabase (`uploaded_pdfs` table); no corresponding Flutter/FastAPI description exists yet.

`uploaded_pdfs` tracks any PDF through ingestion independent of which feature triggered the upload. `questions.source_pdf_id` links extracted questions back to the source upload.

---

## Nova — Adaptive Prep Planner

Nova is an AI mentor that tells the student where to put their hours today. It reasons over a fresh facts snapshot every day, weighing exam urgency, weakness type, capacity, career relevance, and history — with no hardcoded priority rules.

### Core Principle

Nothing about what to prioritize is hardcoded. Only the plumbing — what triggers re-evaluation, what gets confirmed, what gets logged — is rule-based. The actual judgment is reasoned fresh every time by an LLM acting like an experienced senior.

### Nova Schema Tables

All Nova tables have RLS enabled, scoped to `user_id = auth.uid()`.

#### `nova_capacity_log` table

Daily capacity tap per student. One row per student per day, upserted when student changes their tap.

```
id                uuid, primary key, default gen_random_uuid()
user_id           uuid, not null, references users.id
capacity          text, not null, check (light|normal|packed)
logged_for_date   date, not null
created_at        timestamptz, not null, default now()
updated_at        timestamptz, not null, default now()
unique            (user_id, logged_for_date)
```

When upserting: `ON CONFLICT (user_id, logged_for_date) DO UPDATE SET capacity = EXCLUDED.capacity, updated_at = now()`.

#### `staleness_tracker` table

Tracks when each unit (academic subject or career unit) was last meaningfully worked on. Used by the trigger layer to detect neglected topics.

```
id                        uuid, primary key, default gen_random_uuid()
user_id                   uuid, not null, references users.id
user_subject_id           uuid, nullable, references user_subjects.id
career_unit_id            uuid, nullable, references career_units.id
topic_id                  uuid, nullable, references topics.id
last_meaningfully_touched timestamptz, not null, default now()
created_at                timestamptz, not null, default now()
updated_at                timestamptz, not null, default now()
```

**Constraint:** exactly one of `user_subject_id` / `career_unit_id` must be set (XOR).

#### `standing_flags` table

Durable instructions from the student that persist until explicitly removed or superseded. Example: "always buffer DBMS practicals." Can attach to either an academic subject or a career unit — not academic-only.

```
id                uuid, primary key, default gen_random_uuid()
user_id           uuid, not null, references users.id
user_subject_id   uuid, nullable, references user_subjects.id
career_unit_id    uuid, nullable, references career_units.id
instruction_text  text, not null
confirmed_at      timestamptz, nullable — null = pending confirmation, inert until confirmed
superseded_at     timestamptz, nullable — set when a newer statement replaces this one
supersedes_id     uuid, nullable, references standing_flags.id — links to the flag this replaced
source            text, not null, default 'conversation'
created_at        timestamptz, not null, default now()
```

Active flags: `WHERE superseded_at IS NULL AND confirmed_at IS NOT NULL`.

#### `situation_flags` table

Temporary context the student tells Nova. Example: "I'm sick this week," "I have a family event Saturday." Can attach to either an academic subject or a career unit.

```
id                uuid, primary key, default gen_random_uuid()
user_id           uuid, not null, references users.id
user_subject_id   uuid, nullable, references user_subjects.id
career_unit_id    uuid, nullable, references career_units.id
flag_text         text, not null
confirmed_at      timestamptz, nullable
superseded_at     timestamptz, nullable
supersedes_id     uuid, nullable, references situation_flags.id
starts_at         timestamptz, not null, default now()
expires_at        timestamptz, nullable — null = no fixed end date
created_at        timestamptz, not null, default now()
```

**Constraint:** `expires_at IS NULL OR expires_at > starts_at`.

> Unlike `standing_flags` and `nova_history`, this table has no `source` column — unconfirmed whether that's intentional (situation flags are conversation-only by design) or a gap. Worth confirming before assuming either way.

#### `nova_history` table

What has worked for this student before, conversation-fed only. Not auto-inferred from scores (v2 deferral). Can attach to either an academic subject or a career unit.

```
id                uuid, primary key, default gen_random_uuid()
user_id           uuid, not null, references users.id
user_subject_id   uuid, nullable, references user_subjects.id
career_unit_id    uuid, nullable, references career_units.id
content           text, not null — free text, preserves full nuance
confirmed_at      timestamptz, nullable
superseded_at     timestamptz, nullable
supersedes_id     uuid, nullable, references nova_history.id
source            text, not null, default 'conversation'
created_at        timestamptz, not null, default now()
```

**Known dependency:** contradiction detection (setting `supersedes_id` correctly) must be handled by the conversation layer at write time. The schema cannot enforce this.

#### `career_units` table

Career/industry skills or directions the student is tracking alongside academic prep.

```
id                              uuid, primary key, default gen_random_uuid()
user_id                         uuid, not null, references users.id
name                            text, not null
description                     text, nullable
industry_relevance_text         text, nullable — human-readable relevance signal
industry_relevance_score        numeric, nullable, check (0–1) — machine-readable, used by trigger layer
industry_relevance_updated_at   timestamptz, nullable — when relevance was last refreshed
confirmed_at                    timestamptz, nullable
paused_at                       timestamptz, nullable — null = active, set = paused
source                          text, not null, default 'conversation'
created_at                      timestamptz, not null, default now()
updated_at                      timestamptz, not null, default now()
```

Active units: `WHERE paused_at IS NULL AND confirmed_at IS NOT NULL`. Career units use pause/resume rather than supersession — pausing a skill is not the same shape as contradicting a stated preference.

#### `nova_why_log` table

Audit trail for every plan change — full facts snapshot, resulting plan, and a reasoning summary, per §7/§9 of the Nova spec. `entry_type` distinguishes the three shapes a log entry can take: a full reasoning pass, a no-LLM-call minor arithmetic re-rank, or a logged one-off override that never touched the schema.

```
id                  uuid, primary key, default gen_random_uuid()
user_id             uuid, not null, references users.id
entry_type          text, not null, check (full_pass|minor_trigger|one_off_override)
user_subject_id     uuid, nullable, references user_subjects.id
topic_id            uuid, nullable, references topics.id
career_unit_id      uuid, nullable, references career_units.id
facts_snapshot      jsonb, nullable — full snapshot the model reasoned over; null for lighter entry types
plan_output         jsonb, nullable — the resulting ranked plan
reasoning_summary   text, not null
superseded_at       timestamptz, nullable — set when a later pass supersedes this entry (concurrency rule, §6)
supersedes_id       uuid, nullable, references nova_why_log.id
created_at          timestamptz, not null, default now()
```

#### `nova_config` table

Generic key/value config store — not fixed columns. `user_id` is nullable, which allows global/default config rows (e.g. default staleness thresholds) alongside per-student overrides.

```
id            uuid, primary key, default gen_random_uuid()
user_id       uuid, nullable, references users.id — null = global/default config, not per-student
key           text, not null
value         jsonb, not null
updated_at    timestamptz, not null, default now()
```

### Nova Facts Snapshot (not a table)

Nova's facts snapshot is derived live at reasoning time by `nova_pipeline.py`, not stored as a materialized table. It joins:

- `user_subject_exams` → `time_left` per subject
- `nova_capacity_log` → today's capacity
- `staleness_tracker` → last touched per unit
- `standing_flags` + `situation_flags` → active flags
- `nova_history` → confirmed history entries
- `career_units` → active career units with relevance scores
- `question_results` + `user_topic_weights` → performance and error_category per topic
- `study_plans` → topic structure per subject

The snapshot is logged as jsonb inside `nova_why_log` for auditability. A pre-materialized table is not used because it would create a sync problem and violate the spec's atomic-fetch requirement.

### Nova CLI (Q&A Prototype)

A working, dev-only prototype exists today, ahead of the full pipeline described above. It's a local CLI (`lib/core/ai/nova/nova_agent.py`) that fetches a student's live facts snapshot from Supabase and lets you ask Nova questions about it in a terminal chat loop, answered by Groq (`llama-3.3-70b-versatile`).

```
python nova_agent.py <user_id>
```

**What it is:** a read-only conversational surface over real data — a way to sanity-check what a "facts snapshot" looks like and how naturally an LLM can talk about it, before the rest of the pipeline is built.

**What it is *not*:** it does not implement the trigger layer, the reasoning/ranking pass, structured plan output, or why-log writes described elsewhere in this section. There's no daily plan, no confirmation-gated writes, no audit trail — it's purely "fetch facts, answer a question, forget everything when the process exits."

**Known limitations** (tracked in [#15](https://github.com/Krish-876/Skolar/issues/15)):
- `user_id` is taken as a raw CLI argument with no auth check against the caller's identity — dev-only, local use, service-role key
- No error handling around the Groq/Supabase calls — an API failure crashes the whole session
- The facts snapshot is fetched once at startup and held for the entire session, so it can go stale mid-conversation if underlying data changes

See [Tech Debt](#tech-debt) for the full writeup and fix conditions.

### Nova Tables Still To Build

| Table | Purpose |
|---|---|
| `nova_conversations` | Conversation turn history with Nova |
| `nova_conversations_archive` | Older conversations moved out for performance |
| `nova_plan_outputs` | Ranked plan the student sees — subjects, time budgets, one-line reasons per item |
| `nova_trigger_log` | What fired each reasoning pass and why |
| `nova_unconfirmed_proposals` | Conversation-proposed changes inert until student confirms |
| `nova_industry_relevance_log` | Web lookup history for career unit relevance signals |
| `nova_one_off_overrides` | Today-only overrides, never persisted to schema |

> `nova_why_log` and `nova_config` were previously listed here but are already live in Supabase — see [Nova Schema Tables](#nova-schema-tables) above.

---

## Folder Structure

```
lib/
├── core/
│   ├── ai/
│   │   ├── data/                    # PYQ PDF files
│   │   ├── rag_llms/                # Python backend
│   │   │   ├── main.py              # FastAPI app (all endpoints)
│   │   │   ├── pipeline.py          # DICL pipeline + study plan extraction
│   │   │   ├── evaluate.py          # Pipeline evaluation
│   │   │   └── .env                 # GROQ_API_KEY, SUPABASE_URL, SUPABASE_KEY (not committed)
│   │   └── nova/                    # Nova CLI Q&A prototype (dev-only, read-only — see Nova section)
│   │       ├── nova_agent.py        # CLI entrypoint — python nova_agent.py <user_id>
│   │       └── nova/
│   │           ├── prompts/         # nova_system_prompt.py
│   │           ├── schemas/         # chat.py, facts_snapshot.py
│   │           └── services/        # clients.py, facts_service.py, chat_service.py
│   ├── config/
│   ├── di/
│   ├── errors/
│   ├── network/
│   ├── routing/                     # GoRouter — auth guard, named routes
│   ├── services/
│   │   └── activity_log_service.dart   # stub — pending implementation
│   ├── storage/
│   ├── theme/
│   ├── utils/
│   │   └── email_parser.dart        # Parses BITS email → roll_number, academic_year, subdomain
│   └── widgets/
│
├── shared/
│   ├── components/
│   ├── extensions/
│   ├── models/
│   │   └── exam_type.dart           # ExamType enum — single source of truth
│   └── providers/
│
├── features/
│   ├── auth/
│   ├── onboarding/
│   ├── subjects/
│   ├── analytics/
│   ├── dashboard/
│   ├── colleges/
│   ├── syllabus/
│   ├── pyq_upload/
│   ├── exam_prediction/
│   ├── feed/
│   ├── focus_session/
│   ├── mock_tests/
│   ├── nova/                        # planned — Nova conversation + plan display
│   └── profile/
│
└── main.dart
```

---

## Tech Stack

### Flutter App

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| Immutable models | `freezed` + `freezed_annotation` |
| JSON serialization | `json_serializable` + `json_annotation` |
| Functional error handling | `dartz` (Either type) |
| HTTP client | `dio` |
| Dependency injection | `get_it` |
| Local storage | `hive` + `shared_preferences` |
| Charts | `fl_chart` |
| Quiz confetti | `confetti ^0.8.0` |
| Markdown rendering | `flutter_markdown_plus` |
| File picker | `file_picker ^11.0.2` |
| Code generation | `build_runner` |

### AI Backend

| Purpose | Tool |
|---|---|
| PDF text extraction | `pdfplumber` |
| Question extraction | Groq API — LLaMA 3.3 70B |
| Topic + study plan extraction | Groq API — LLaMA 3.3 70B |
| Semantic embeddings | `sentence-transformers` — all-MiniLM-L6-v2 |
| Diversity selection | MMR algorithm (numpy) |
| MCQ + open question generation | Groq API — LLaMA 3.3 70B |
| Model answer generation | Groq API — LLaMA 3.3 70B |
| Parallel generation | `concurrent.futures.ThreadPoolExecutor` (3 workers) |
| Backend API | FastAPI + uvicorn |
| Deployment | Railway |
| Data store | Supabase (PostgreSQL + pgvector) |
| File storage | Supabase Storage (handouts bucket) |

---

## Features

### Built

- **Authentication** — magic link via BITS college email (Supabase Auth)
- **Onboarding** — full flow wired to Supabase
- **Real user data via `userProvider`**
- **Subjects feature** — full Clean Architecture, handout upload, study plan generation
- **Routing** — GoRouter with auth guard
- **Scrollable analytics dashboard**
- **Dark theme** with custom color palette
- **Full AI pipeline** (DICL + MMR + Supabase)
- **FastAPI backend** — 8 endpoints, fully Supabase-backed, deployed on Railway
- **Mock test platform** — full Clean Architecture, 4 exam types, MCQ Blitz + Written Practice
- **Exam prediction** / question bank browser
- **Focus session timer**
- **Community feed** — live from Supabase, vote persistence
- **Nova CLI Q&A prototype** — dev-only, read-only chat over a live facts snapshot (see [Nova CLI (Q&A Prototype)](#nova-cli-qa-prototype))

### Schema Live, No UI/Code Yet

- `test_attempts`, `question_results`, `ai_evaluations` — test attempt flow
- `uploaded_pdfs` — PDF upload tracking
- All Nova tables listed in [Nova Tables Still To Build](#nova-tables-still-to-build)

### Still Mock

- Streak and coins on profile
- PYQ upload UI
- Friends on profile
- Onboarding subject selection step (UI exists, not wired to DB)
- Study plan display UI (plan is generated and persisted, no page to show it yet)

### Planned

- Study plan display page per subject
- Syllabus progress tracking
- PYQ upload through the app UI
- Nova conversation UI + daily plan display
- Personal learning goal mode
- Focus session history and streak tracking
- Compre Part A published to feed

---

## Dashboard -- How It Works

All dashboard data lives in `assets/data/analytics.json`. To change what appears on screen, edit this file and hot-restart the app.

### Data Flow

```
assets/data/analytics.json
        ↓
AnalyticsLocalDataSourceImpl
        ↓
AnalyticsDataDto.fromJson()
        ↓
dto.toDomain()
        ↓
AnalyticsRepositoryImpl
        ↓
GetAnalyticsUseCase
        ↓
DashboardNotifier
        ↓
dashboardProvider
        ↓
DashboardPage → charts and tiles
```

---

## Running the App

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

---

## Code Generation

| File suffix | Generated by | Purpose |
|---|---|---|
| `.freezed.dart` | `freezed` | Immutable value classes |
| `.g.dart` | `json_serializable` | `fromJson` / `toJson` methods |

Run `build_runner` after adding or changing any `@freezed` class or `@JsonSerializable` DTO.

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

---

## Running the Backend

```bash
cd lib/core/ai/rag_llms
python -m venv myenv311
myenv311\Scripts\activate
pip install fastapi uvicorn pdfplumber sentence-transformers numpy groq python-dotenv supabase requests
uvicorn main:app --reload --port 8000
```

Interactive API docs at `http://localhost:8000/docs`.

### Running the Nova CLI Prototype

```bash
cd lib/core/ai/nova
python nova_agent.py <user_id>
```

Reads `SUPABASE_URL`, `SUPABASE_KEY`, and `GROQ_API_KEY` from `lib/core/ai/rag_llms/.env`. Service-role key, local dev only — see [Nova CLI (Q&A Prototype)](#nova-cli-qa-prototype) and [Tech Debt](#tech-debt) before using this with real student data.

---

## Adding a New Feature

1. Create folder structure under `lib/features/your_feature/`
2. Define domain entities in `domain/entities/` using `@freezed`
3. Define repository interface in `domain/repositories/`
4. Write use cases in `domain/usecases/`
5. Create the DTO in `data/dtos/` using `@JsonSerializable`
6. Implement the datasource in `data/datasources/`
7. Implement the repository in `data/repository_impl/`
8. Create a Riverpod `AsyncNotifierProvider` in `presentation/providers/`
9. Build the page and widgets in `presentation/pages/` and `presentation/widgets/`
10. Add a route in `core/routing/`
11. Run `dart run build_runner build --delete-conflicting-outputs`

---

## Tech Debt

### Compre Part A (MCQ Blitz) — not published or loadable from feed

`/generate-batch` does not save to `published_tests`. `loadExistingTest` has no MCQ Blitz path. Feed Attempt button always routes to written practice regardless of `examType`.

**When to fix:** After Phase 5 ships.

---

### Study plan display UI — not yet built

`study_plans` rows are generated and persisted. No Flutter page exists to display them yet.

**When to fix:** Phase 5 — foundation for the daily question scheduler.

---

### `_triggerPlanExtraction` — needs real FastAPI URL

Currently calls a Supabase Edge Function placeholder. Needs to point to the deployed Railway URL.

**When to fix:** Before study plan display UI is built.

---

### `academic_year` filtering — not wired

`academic_year` exists in `questions` and `UserModel` but is not used as a filter in Flutter or the pipeline.

**When to fix:** Before Phase 5 — daily question plan needs year scoping.

---

### Full DICL — top-15 cosine retrieval not implemented

MMR currently runs over the entire question bank. Correct DICL first retrieves top-15 by cosine similarity, then runs MMR over those 15.

**When to fix:** Phase 6. Needs 100+ questions per subject to be measurable.

---

### Onboarding subject selection — not wired to DB

Subject selection step UI exists but does not fetch real subjects from the `subjects` table.

**When to fix:** Before real user onboarding goes live.

---

### Focus session — minor issues

- Duplicate controller file in `widgets/` vs `controllers/` — delete widgets copy
- `resume()` is a no-op
- `FocusTimerStatus.paused` defined but never set
- No session persistence — add `StorageService.saveSession()` when Phase 5 streak tracking lands

---

### `published_tests.question_ids` is not a real foreign key

Plain `uuid[]` array — deleting a `questions` row silently leaves a dangling ID.

**When to fix:** Before any question-deletion or moderation tooling is built.

---

### `topics` RLS — write policy not yet set

RLS is enabled on `topics` with read-only access for authenticated users. Write policy (for pipeline inserts) is pending confirmation of whether the FastAPI backend connects via service-role or anon key.

**When to fix:** Before wiring the pipeline to write `topic_id` on question extraction.

---

### Free-text `topic` columns — migration in progress

`questions`, `question_results`, `uploaded_pdfs`, `user_topic_weights`, and `staleness_tracker` all have both a legacy `topic` text column and a new `topic_id` FK to the `topics` table. Old code writes to `topic` text. New code should write both. Text columns will be dropped once the pipeline is fully migrated.

**When to fix:** When the pipeline is updated to write `topic_id` on extraction.

---

### Nova CLI — no auth, no error handling, snapshot goes stale mid-session

`nova_agent.py` currently trusts any `user_id` passed via argv with no check against the caller's identity — it runs against a service-role key locally, so anyone running it could pull any student's exam/weakness/career data just by changing the ID. API failures (Groq overloaded, Supabase down) crash the whole CLI and dump a raw stack trace, killing the session and losing all conversation history built up so far. The facts snapshot is also fetched once at CLI startup and held for the whole session — if underlying data changes mid-session (new test score, capacity update), Nova keeps answering from the stale startup snapshot. Fine for local dev/testing; tracked in [#15](https://github.com/Krish-876/Skolar/issues/15).

**When to fix:** Auth before this touches any real user's data; error handling before it's used for real QA testing; snapshot staleness before this pattern carries over into the real triggered Nova pipeline (Phase 5).

---

## Roadmap

```
Phase 1 — Foundation (complete)
    Project scaffold and architecture
    Theme system
    Analytics dashboard with charts
    Dev navigation menu

Phase 2 — AI Pipeline (complete)
    PDF parsing and question extraction
    Semantic embeddings with sentence-transformers
    MMR-based diverse example selection (DICL)
    LLM MCQ + open question generation
    Exam type filtering
    Thread-safe parallel generation
    FastAPI backend with 8 endpoints
    Supabase integration
    Railway deployment

Phase 3 — Core Features (complete)
    Mock test platform — full Clean Architecture
    Exam prediction / question bank browser
    Community feed — live from Supabase
    Focus session timer
    Auto-save written practice tests to published_tests

Phase 4 — Auth and Backend (complete)
    ✅ Magic link auth via BITS college email
    ✅ Onboarding → Supabase write
    ✅ Real userProvider
    ✅ Subjects feature — full Clean Architecture
    ✅ Handout upload + study plan generation
    ✅ GoRouter migration
    ✅ RLS policies
    ✅ Vote state persistence
    ✅ Subject retrieval corrected end-to-end
    ✅ test_attempts composite uniqueness fixed
    ✅ Nova schema foundations — user_subject_exams, nova_capacity_log,
       staleness_tracker, topics, standing_flags, situation_flags,
       nova_history, career_units, nova_why_log, nova_config,
       topic_id and career_unit_id on all affected tables
    ✅ Nova CLI Q&A prototype — dev-only, read-only (see Tech Debt)
    ⬜ _triggerPlanExtraction wired to real FastAPI URL
    ⬜ Study plan display UI per subject
    ⬜ Compre Part A → published_tests pipeline + feed (deferred to post-Phase 5)

Phase 5 — Personalisation
    Study plan display page per subject
    Wire test_attempts / question_results / ai_evaluations into the app
    academic_year filter across pipeline + exam prediction

    Nova schema (remaining)
        nova_conversations
        nova_conversations_archive
        nova_plan_outputs
        nova_trigger_log
        nova_unconfirmed_proposals
        nova_industry_relevance_log
        nova_one_off_overrides
        (nova_why_log and nova_config already live — see Nova Schema Tables)

    Nova backend
        nova_pipeline.py — facts fetch, trigger check, reasoning pass,
            minor rerank, flag writes, conversation extraction, why-log writes
        nova_router.py — all Nova endpoints
        main.py — mount nova_router (one line)
        pg_cron nightly retention job driven by nova_config
        Harden Nova CLI prototype into the real pipeline — auth, error
            handling, and live (non-stale) facts fetch (closes #15)

    Nova Flutter
        Decouple handout plan trigger from Nova plan trigger
        capacity_today tap → POST /nova/student/capacity
        Daily plan screen → reads from nova_plan_log
        Nova conversation UI (chatbot-style)
        Trigger check on app open, after test submission, after flag confirmation

    Personal learning goal mode
    Lives and streak system
    Coin economy
    Daily college-wide brain puzzle
    College leaderboard
    Dashboard integration with mock test scores
    Focus session history and streak tracking

Phase 6 — ML Extension
    Full DICL: top-15 cosine retrieval → MMR over those 15 → pick 5
    Fine-tune FLAN-T5 on generated question-answer pairs
    Experiment comparing MMR vs random vs top-k selection
    Distractor quality analysis for MCQ options
```

---

*Built by Krishna — BITS Pilani Hyderabad, B.Tech CSE 2024–2028*
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
| `data/datasources/mock_test_datasource.dart` | Calls `/generate-batch`, `/generate-open-batch`, fetches by IDs from Supabase, now sources subjects dynamically per user instead of a hardcoded list |
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

As of the latest fix, the mock test setup screen pulls the student's subject list from their actual `user_subjects` enrollment rather than a hardcoded list, end-to-end with the subjects feature's retrieval fix.

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

If no questions match the filter, the pipeline falls back to the full bank so generation never hard-fails. A null `exam_type` value from Supabase is also handled defensively so it no longer raises an `AttributeError` during filtering.

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
Insert new row into study_plans (topics jsonb, weekly_plan jsonb, is_active true)
```

The upload completes and the UI updates immediately. Plan generation runs in the background and persists permanently in `study_plans`. Re-uploading a new handout deactivates the previous plan and generates a fresh one.

### MMR Algorithm

At every step, MMR picks the candidate that maximises:

```
score = alpha * relevance_to_query - (1 - alpha) * max_similarity_to_already_selected
```

Alpha = 0.7 means 70% relevance, 30% diversity. Greedy algorithm that builds selection one item at a time.

### Supabase Schema

> The schema below reflects the live database as queried directly via `information_schema` and `pg_policies`, not just what's referenced in application code. Tables with no corresponding Flutter/Python description yet are marked **(schema only)**.

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

#### `users` table

```
id                uuid, primary key
email             text
full_name         text, nullable
roll_number       text, nullable
college           text, nullable
institution_id    uuid, nullable
campus_id         uuid, nullable
academic_year     smallint, nullable
avatar_url        text, nullable
branch            text, nullable
plan              text
created_at        timestamptz
updated_at        timestamptz
```

RLS policies: insert, update, select scoped to `auth.uid()`.

#### `subjects` table

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE, unique
name              text, not null, unique
short_name        text, nullable
academic_year     smallint
created_at        timestamptz
```

#### `custom_subjects` table **(schema only)**

User- or institution-defined subjects that don't exist in the shared `subjects` catalog yet.

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE, unique
course_code       text, not null, unique
name              text, not null
credits           smallint, nullable
created_at        timestamptz, not null, default now()
```

#### `user_subjects` table

> PK is a standalone `id` column, not the composite `(user_id, subject_id)` previously documented here.

```
id                    uuid, primary key, default gen_random_uuid()
user_id               uuid, not null, references users.id ON DELETE CASCADE
subject_id            uuid, nullable, references subjects.id ON DELETE CASCADE
custom_subject_id     uuid, nullable, references custom_subjects.id ON DELETE SET NULL
semester              text, not null
handout_url           text, nullable
handout_filename      text, nullable
handout_uploaded_at   timestamptz, nullable
topic_schedule        jsonb, nullable
```

A `user_subjects` row can reference either a catalog `subjects` row or a `custom_subjects` row via `custom_subject_id`. If a custom subject is deleted, the link is nulled rather than the enrollment row being removed.

#### `questions` table

```
id                  uuid, primary key, default gen_random_uuid()
question_text       text, not null
marks               integer, not null, default 0
question_type       text, not null  — mcq | short_answer | long_answer | numerical
subject             text, not null
college             text, not null  — used to scope all queries
paper_year          integer, nullable
academic_year       smallint, nullable
exam_type           text, nullable  — quiz | midsem | compre | generated
embedding           vector(384), nullable  — all-MiniLM-L6-v2
published           boolean, not null, default false
published_by        uuid, nullable, references users.id ON DELETE SET NULL
published_at        timestamptz, nullable
created_at          timestamptz, not null, default now()
options              jsonb, nullable  — MCQ options array
correct_index        smallint, nullable  — correct option index 0–3
subject_id           uuid, nullable, references subjects.id
campus_id            uuid, nullable, references campuses.id
source_pdf_id        uuid, nullable, references uploaded_pdfs.id
doc_type             text, nullable
topic                text, nullable
has_diagram          boolean, not null, default false
sub_parts            jsonb, nullable
model_answer         text, nullable
answer_source        text, nullable
confidence_score     numeric, nullable
marks_inferred       boolean, not null, default false
```

`subject_id` / `campus_id` / `source_pdf_id` normalize what `subject` / `college` previously captured as plain text, alongside the original text columns. None of `subject_id`, `campus_id`, or `source_pdf_id` cascade on delete — deleting a referenced `subjects`, `campuses`, or `uploaded_pdfs` row is blocked while questions still reference it.

#### `published_tests` table

```
id                uuid, primary key, default gen_random_uuid()
published_by      uuid, nullable, references users.id ON DELETE SET NULL
college           text, not null
subject           text, not null
exam_type         text, not null
question_ids      uuid[], not null  — references questions.id (not a DB-enforced FK)
upvotes           integer, not null, default 0
downvotes         integer, not null, default 0
attempts          integer, not null, default 0
created_at        timestamptz, not null, default now()
subject_id        uuid, nullable
campus_id         uuid, nullable
```

`question_ids` is a plain array column, not a foreign key — deleting a `questions` row will not cascade or block here, it will silently leave a dangling ID in the array.

#### `post_votes` table

Implemented and live — vote state is persisted to Supabase with optimistic UI on the client.

```
user_id           uuid, not null, references users.id ON DELETE CASCADE
post_id           uuid, not null, references published_tests.id ON DELETE CASCADE
vote              smallint, not null
created_at        timestamptz, not null, default now()
primary key       (user_id, post_id)
```

#### `study_plans` table

```
id                uuid, primary key, default gen_random_uuid()
user_subject_id   uuid, not null, references user_subjects.id ON DELETE CASCADE
user_id           uuid, not null, references users.id ON DELETE CASCADE
subject_name      text, not null
handout_url       text, not null
topics            jsonb, not null  — flat list of topic strings
weekly_plan       jsonb, not null  — array of {week, topics, study_hours, focus}
is_active         boolean, not null, default true
generated_at      timestamptz, not null, default now()
updated_at        timestamptz, not null, default now()
```

Only one plan per `user_subject_id` is active at a time. Uploading a new handout deactivates the previous plan before inserting the new one. Deleting the parent `user_subjects` row (or the parent `users` row) cascades and removes associated study plans.

#### `uploaded_pdfs` table **(schema only)**

Tracks PDF uploads (PYQ papers, handouts, etc.) through ingestion, independent of which feature triggered the upload.

```
id                    uuid, primary key, default gen_random_uuid()
uploaded_by           uuid, nullable, references users.id ON DELETE SET NULL
uploaded_as           text, not null, default 'student'
storage_path          text, not null
doc_type              text, not null
subject_id            uuid, nullable, references subjects.id
campus_id             uuid, nullable, references campuses.id
exam_type             text, nullable
paper_year            integer, nullable
topic                 text, nullable
status                text, not null, default 'pending'
questions_extracted   integer, not null, default 0
questions_failed      integer, not null, default 0
created_at            timestamptz, not null, default now()
```

`questions.source_pdf_id` references this table. Deleting a `subjects` or `campuses` row referenced here is blocked (`NO ACTION`) while uploads still reference it.

#### `test_attempts` table **(schema only)**

```
id                uuid, primary key, default gen_random_uuid()
test_id           uuid, not null, references published_tests.id ON DELETE CASCADE, unique
user_id           uuid, not null, references users.id ON DELETE CASCADE, unique
subject_id        uuid, nullable, references subjects.id
attempt_number    smallint, not null, default 1, unique
total_marks       integer, not null, default 0
obtained_marks    integer, not null, default 0
completed_at      timestamptz, not null, default now()
```

> `test_id`, `user_id`, and `attempt_number` are each declared as independent `UNIQUE` constraints rather than a single composite uniqueness rule across all three. As written, this restricts the table to at most one row per test, one row per user, and one row per attempt number globally — worth confirming against the actual intent (likely a composite `UNIQUE (test_id, user_id, attempt_number)`) before this table is used beyond a single test/user pairing.

#### `question_results` table **(schema only)**

Per-question outcome within a single test attempt.

```
id                  uuid, primary key, default gen_random_uuid()
attempt_id          uuid, not null, references test_attempts.id ON DELETE CASCADE
question_id         uuid, not null, references questions.id
topic               text, nullable
is_correct          boolean, nullable
marks_available     integer, not null, default 0
marks_obtained      numeric, not null, default 0
self_rating         smallint, nullable
ai_evaluation_id    uuid, nullable, references ai_evaluations.id ON DELETE SET NULL
created_at          timestamptz, not null, default now()
```

`question_id` does not cascade — a `questions` row cannot be deleted while results reference it.

#### `ai_evaluations` table **(schema only)**

AI-graded evaluation of a student's photographed/handwritten answer against the model answer.

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

`question_id` does not cascade — same restriction as `question_results`.

PYQ entries are uploaded via `/upload-pyq`. The `college` field on every row ensures complete data isolation between colleges.

### Cascade Behavior Summary

| Parent deleted | Cascades to | Effect |
|---|---|---|
| `users` | `ai_evaluations`, `post_votes`, `study_plans`, `test_attempts`, `user_subjects` | hard delete |
| `institutions` | `campuses`, `custom_subjects`, `subjects` | hard delete |
| `subjects` | `user_subjects` | hard delete — but blocked by `NO ACTION` from `questions`, `test_attempts`, `uploaded_pdfs` if any reference the subject |
| `user_subjects` | `study_plans` | hard delete |
| `published_tests` | `post_votes`, `test_attempts` | hard delete |
| `test_attempts` | `question_results` | hard delete |
| `question_results` | `ai_evaluations` | hard delete |
| `users` (as `published_by` / `uploaded_by`) | `published_tests`, `questions`, `uploaded_pdfs` | `SET NULL` — content kept, authorship orphaned |
| `custom_subjects` | `user_subjects.custom_subject_id` | `SET NULL` — enrollment kept, custom-subject link cleared |
| `ai_evaluations` | `question_results.ai_evaluation_id` | `SET NULL` |
| `questions` | `ai_evaluations`, `question_results` | `NO ACTION` — delete blocked while referenced |
| `subjects` / `campuses` / `uploaded_pdfs` | `questions`, `test_attempts`, `uploaded_pdfs` (various) | `NO ACTION` — delete blocked while referenced |

In practice, a `subjects` row can only be deleted while it has zero questions, test attempts, or PDF uploads against it — once any exist, the catalog row is effectively permanent via plain `DELETE`.

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

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Sanity check |
| `GET` | `/stats` | Bank stats scoped by college |
| `GET` | `/questions` | Browse/filter the question bank |
| `POST` | `/generate` | One open-ended question |
| `POST` | `/generate-batch` | N MCQs in parallel (Compre Part A) |
| `POST` | `/generate-open-batch` | N open questions + model answers, auto-saves to `published_tests` |
| `POST` | `/upload-pyq` | PDF → extract questions → insert into Supabase |
| `POST` | `/extract-plan` | Handout PDF → topic list + weekly study plan → insert into `study_plans` |

#### `POST /extract-plan` — Request body

```json
{
  "user_subject_id": "<uuid>",
  "user_id": "<uuid>",
  "subject_name": "Operating Systems",
  "handout_url": "https://..."
}
```

#### `POST /generate-batch` — Request body

```json
{
  "subject": "Artificial Intelligence",
  "college": "BPHC",
  "count": 8,
  "exam_type": "compre",
  "year_from": 2022,
  "year_to": 2025,
  "k": 5
}
```

#### `POST /generate-open-batch` — Request body

```json
{
  "subject": "Artificial Intelligence",
  "college": "BPHC",
  "count": 5,
  "exam_type": "midsem",
  "with_answers": true,
  "k": 5
}
```

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
| `domain/entities/feed_post_entity.dart` | `examType`, `questionIds` fields; `bankIndices` removed |
| `presentation/providers/feed_provider.dart` | College read from `userProvider`, not hardcoded |
| `presentation/pages/feed_page.dart` | College from `userProvider` (hardcoded fallback removed) |
| `presentation/widgets/feed_post_card.dart` | Attempt button wired to `loadExistingTest`, vote buttons wired to Supabase via `post_votes` |

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

### Subject Retrieval Fix

Subject retrieval was corrected and user-selected subjects are now wired end-to-end — from `user_subjects` through to the mock test setup screen, which previously used a hardcoded subject list. This also surfaced and fixed a related pipeline bug where a null `exam_type` from Supabase caused an `AttributeError` during question filtering.

### Supabase Storage

Bucket: `handouts` (public)

RLS policies:
- `INSERT` — authenticated users only, `bucket_id = 'handouts'`
- `SELECT` — authenticated users only, `bucket_id = 'handouts'` (required for post-upload URL resolution)

### Flutter Files

| File | Role |
|---|---|
| `data/datasources/subjects_datasource.dart` | `uploadHandout` — uploads to Storage, updates `user_subjects`, triggers plan extraction; subject retrieval logic corrected |
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

> Schema is live in Supabase; no Flutter or FastAPI code description exists yet for this flow. Documented here from the database only so the data model is tracked ahead of implementation.

A `test_attempts` row represents one student's attempt at a `published_tests` entry. Each question answered within that attempt becomes a `question_results` row, capturing correctness, marks, and an optional self-rating. For written/photographed answers, a `question_results` row can link to an `ai_evaluations` row, which stores the answer photo, OCR-extracted text, the model answer it was graded against, the AI-awarded score, and structured feedback.

```
published_tests
      ↓ (student attempts)
test_attempts  (total_marks, obtained_marks, completed_at)
      ↓ (one row per question)
question_results  (is_correct, marks_obtained, self_rating)
      ↓ (optional, for photographed/handwritten answers)
ai_evaluations  (answer_photo_url → extracted_text → score_awarded, feedback_json)
```

See the [Supabase Schema](#supabase-schema) section for full column definitions, and Tech Debt for the `test_attempts` uniqueness constraint issue that needs resolving before this flow can support multiple users/attempts.

---

## PDF Upload Pipeline

> Schema is live in Supabase (`uploaded_pdfs` table); no corresponding Flutter/FastAPI description exists yet.

`uploaded_pdfs` tracks any PDF (PYQ paper, handout, etc.) through ingestion independent of which feature triggered the upload, including extraction status (`pending` / etc.) and a count of questions successfully extracted vs. failed. `questions.source_pdf_id` links generated/extracted questions back to the source upload.

---

## Folder Structure

```
lib/
├── core/
│   ├── ai/
│   │   ├── data/                    # PYQ PDF files
│   │   └── rag_llms/                # Python backend
│   │       ├── main.py              # FastAPI app (all endpoints)
│   │       ├── pipeline.py          # DICL pipeline + study plan extraction
│   │       ├── evaluate.py          # Pipeline evaluation
│   │       └── .env                 # GROQ_API_KEY, SUPABASE_URL, SUPABASE_KEY
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
│   │   ├── presentation/
│   │   │   └── pages/               # auth_page.dart — magic link flow
│   │   └── providers/               # authSessionProvider, _justLoggedIn flag
│   │
│   ├── onboarding/
│   │   ├── data/
│   │   │   └── datasources/         # onboarding_remote_datasource.dart
│   │   ├── presentation/
│   │   │   └── pages/               # onboarding_page.dart
│   │   └── providers/               # onboarding_provider.dart
│   │
│   ├── subjects/
│   │   ├── data/
│   │   │   ├── datasources/         # subjects_datasource.dart — getSubjects, addCustom, delete, uploadHandout
│   │   │   ├── dtos/                # subject_dto.dart — handout_url, handout_filename fields
│   │   │   └── repository_impl/     # subjects_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/            # subject_entity.dart — handoutUrl, handoutFilename fields
│   │   │   ├── repositories/        # subjects_repository.dart
│   │   │   └── usecases/            # get_subjects_usecase.dart
│   │   └── presentation/
│   │       └── pages/               # subjects_pages.dart — handout chip, upload flow
│   │
│   ├── analytics/
│   ├── dashboard/
│   ├── colleges/
│   ├── syllabus/
│   ├── pyq_upload/
│   │
│   ├── exam_prediction/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── dtos/
│   │   │   └── repository_impl/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── pages/
│   │       └── providers/
│   │
│   ├── feed/
│   │   ├── data/
│   │   │   ├── datasources/         # feed_remote_datasource.dart
│   │   │   ├── dtos/
│   │   │   └── repository_impl/
│   │   └── presentation/
│   │       ├── pages/
│   │       └── widgets/
│   │
│   ├── focus_session/
│   │   ├── controllers/
│   │   ├── data/
│   │   │   └── models/
│   │   ├── presentation/
│   │   │   └── pages/
│   │   └── widgets/
│   │
│   ├── mock_tests/
│   │   ├── data/
│   │   │   ├── datasources/         # mock_test_datasource.dart
│   │   │   ├── dtos/                # mock_test_dto.dart
│   │   │   └── repository_impl/     # mock_test_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/            # mock_test_entity.dart + .freezed.dart
│   │   │   ├── repositories/        # mock_test_repository.dart
│   │   │   └── usecases/            # mock_test_usecases.dart
│   │   └── presentation/
│   │       ├── pages/               # mock_tests_pages.dart
│   │       └── providers/           # mock_tests_provider.dart
│   │
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
  - `_isNewUser()` check routes new users to onboarding, returning users to app
  - `authSessionProvider` listener with `_justLoggedIn` flag prevents spurious redirects on app resume
- **Onboarding** — full flow wired to Supabase
  - `EmailParser` utility parses BITS email → extracts `roll_number`, `academic_year`, `subdomain`
  - Campus resolved from `campuses` table via subdomain (`hyderabad` → BPHC)
  - Writes to `users` table: `full_name`, `branch`, `college`, `campus_id`, `institution_id`, `academic_year`, `roll_number`, `plan`
  - Writes selected subjects to `user_subjects` table
  - Subject selection step UI exists — not yet wired to real subjects from DB
- **Real user data via `userProvider`**
  - `StateNotifierProvider` fetches from Supabase on load
  - `UserModel` extended with `email`, `campusId`, `institutionId`, `placeholder()` factory
- **Subjects feature** — full Clean Architecture
  - Fetches subjects filtered by `institution_id` and `academic_year`
  - Subject retrieval corrected; user-selected subjects wired end-to-end into mock tests
  - Credit ring showing total enrolled credits vs semester target
  - Long-press to enter edit mode, tap to mark for deletion
  - Add custom subject via bottom sheet (now backed by the `custom_subjects` table)
  - **Handout upload** per subject — PDF picker, Supabase Storage upload, chip UI
  - Fire-and-forget study plan generation via `/extract-plan`
- **Routing** — GoRouter with auth guard
  - Auth guard redirect, dev menu at `/`, `context.push()` for stack-based navigation
- **Scrollable analytics dashboard**
  - Donut ring chart, weekly line chart, task list, recent activity feed
- **Dark theme** with custom color palette
- **Full AI pipeline** (DICL + MMR + Supabase)
  - PDF parsing and question extraction
  - Semantic embedding stored in Supabase pgvector
  - MMR-based diverse example selection
  - Exam type filtering (quiz / midsem / compre scope), with defensive handling of null `exam_type` values from Supabase
  - LLM MCQ generation with 4 options + correct answer
  - LLM open question generation with structured model answers
  - Thread-safe parallel generation (3 concurrent Groq calls)
  - Auto-save generated written practice tests to `published_tests`
  - **Study plan generation** from handout PDF — topic extraction + weekly schedule
- **FastAPI backend** — 8 endpoints, fully Supabase-backed, deployed on Railway
- **Mock test platform** — full Clean Architecture
  - `ExamType` enum as single source of truth
  - 4 exam types: Quiz, Midsem, Compre Part A, Compre Part B
  - MCQ Blitz mode (Compre Part A): timed quiz, score tracking, confetti
  - Written Practice mode (Quiz / Midsem / Compre Part B): flashcard + paper views
  - Model answers with structured markdown rendering
  - `loadExistingTest` — reconstruct written practice test from Supabase question IDs
  - Subject list sourced dynamically from `user_subjects`, replacing the previous hardcoded list
- **Exam prediction** / question bank browser
  - Filter by subject, year, exam type, question type
- **Focus session timer**
  - Preset chips: Pomodoro (25 min), 45 min, 1 hr
  - Custom duration picker (5 min to 3 hr)
  - Slide-to-start track with spring physics
  - Animated wave background
  - Give Up confirmation sheet
  - Auto-reset if user leaves app mid-session
- **Community feed** — live from Supabase
  - Backed by `published_tests` table via `FeedRemoteDataSourceImpl`
  - Feed cards with subject, difficulty badge, upvotes, attempt count
  - Attempt button wired to `loadExistingTest` on `MockTestNotifier`
  - College read from `userProvider`
  - **Vote state persisted to Supabase** (`post_votes` table) with optimistic UI

### Schema Live, No UI/Code Description Yet

These tables exist and are populated/usable in Supabase but have no corresponding Flutter or FastAPI implementation documented:

- **Test attempts, question results, AI evaluation** (`test_attempts`, `question_results`, `ai_evaluations`) — see [Test Attempts, Question Results, and AI Evaluation](#test-attempts-question-results-and-ai-evaluation)
- **PDF upload tracking** (`uploaded_pdfs`) — see [PDF Upload Pipeline](#pdf-upload-pipeline)
- **Custom subjects** (`custom_subjects`) — referenced by `user_subjects.custom_subject_id`; add-custom-subject UI in the subjects feature may already write here, needs confirming

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
- Personal learning goal mode (daily AI question plan with lives/streaks)
- Focus session history and streak tracking
- Compre Part A (MCQ Blitz) published to feed and loadable from feed

---

## Dashboard -- How It Works

The dashboard is the most complete feature. Understanding it explains how every other feature will work too.

### Data Source

All dashboard data lives in a single JSON file:

```
assets/data/analytics.json
```

To change what appears on screen, edit this file and hot-restart the app.

### Data Flow

```
assets/data/analytics.json
        ↓
AnalyticsLocalDataSourceImpl     reads file with rootBundle.loadString()
        ↓
AnalyticsDataDto.fromJson()      converts JSON → Dart DTO objects
        ↓
dto.toDomain()                   converts DTO → clean domain entity (AnalyticsData)
        ↓
AnalyticsRepositoryImpl          wraps result in Either<Failure, AnalyticsData>
        ↓
GetAnalyticsUseCase              single callable entry point
        ↓
DashboardNotifier                AsyncNotifier — holds loading/error/data state
        ↓
dashboardProvider                widgets that watch this rebuild when data changes
        ↓
DashboardPage                    state.when(loading, error, data)
        ↓
DonutProgressChart / WeeklyLineChart / TaskListTile / RecentActivityTile
```

---

## Running the App

```bash
# Install dependencies
flutter pub get

# Generate code (required before first run and after any model change)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

The app opens to a Dev Menu listing all features. Tap any feature to navigate to it directly.

---

## Code Generation

Skolar uses two code generation tools.

### What gets generated

| File suffix | Generated by | Purpose |
|---|---|---|
| `.freezed.dart` | `freezed` | Immutable value classes: `copyWith`, `==`, `hashCode`, pattern matching |
| `.g.dart` | `json_serializable` | `fromJson` / `toJson` methods |

These files are committed to git. Never edit them manually.

### When to run it

Run `build_runner` after any of these:
- Adding a new `@freezed` class
- Adding or removing a field on a `@freezed` class
- Adding a new `@JsonSerializable` DTO
- After a `git pull` that touched any model files

### Commands

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode — auto-rebuilds on file save
dart run build_runner watch --delete-conflicting-outputs

# Clean and rebuild from scratch
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

Always use `--delete-conflicting-outputs`.

---

## Running the Backend

```bash
cd lib/core/ai/rag_llms

# Create and activate environment
python -m venv myenv311
myenv311\Scripts\activate          # Windows
source myenv311/bin/activate       # macOS / Linux

# Install dependencies
pip install fastapi uvicorn pdfplumber sentence-transformers numpy groq python-dotenv supabase requests

# Create .env file with all three keys
echo GROQ_API_KEY=your_key_here > .env
echo SUPABASE_URL=your_url_here >> .env
echo SUPABASE_KEY=your_key_here >> .env

# Start the server
uvicorn main:app --reload --port 8000
```

The server starts at `http://0.0.0.0:8000`. Interactive API docs at `http://localhost:8000/docs`.

The backend is deployed on Railway. The base URL is defined in `mock_tests_provider.dart` as `_kBaseUrl`. When running locally on a physical device, replace with your machine's LAN IP (e.g. `192.168.29.196`).

---

## Adding a New Feature

Order to stay consistent with the architecture:

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

Use the `analytics` feature as the reference implementation. Features with no persistence or backend requirement (like focus session) can skip steps 2–7 and use a `ChangeNotifier` directly in the presentation layer.

---

## Tech Debt

### Compre Part A (MCQ Blitz) — not published or loadable from feed

- `/generate-batch` does not save to `published_tests` (only `/generate-open-batch` does)
- `options` and `correct_index` columns exist on the `questions` table but the backend does not populate them on save yet
- `loadExistingTest` in the provider has no MCQ Blitz path — it would need to reconstruct `McqQuestion` objects from `options` / `correct_index`
- The feed page's Attempt button always routes to written practice mode regardless of `examType`

**When to fix:** After Phase 5 ships. Save `options` + `correct_index` on generation → insert into `published_tests` → fetch with options on load → route to MCQ Blitz mode in feed.

---

### Study plan display UI — not yet built

`study_plans` rows are generated and persisted correctly. There is no Flutter page to display them yet. The next step is a `StudyPlanPage` per subject that reads from `study_plans` where `user_subject_id = <id> AND is_active = true` and renders the topic list and weekly schedule.

**When to fix:** Phase 5 personalisation — the plan is the foundation for the daily question scheduler.

---

### `_triggerPlanExtraction` — needs real FastAPI URL

Currently calls a Supabase Edge Function named `extract-plan-proxy`. This needs to either point to the deployed Railway URL directly via `http.post`, or the Edge Function needs to be created as a thin proxy.

**When to fix:** Before study plan display UI is built — the plan won't exist in `study_plans` until this is wired.

---

### `test_attempts` uniqueness constraints likely wrong

`test_id`, `user_id`, and `attempt_number` on `test_attempts` are each independently `UNIQUE` rather than jointly unique. As declared, this caps the table at one row per test, one row per user, and one row per attempt number — system-wide. Needs to be a composite `UNIQUE (test_id, user_id, attempt_number)` (or similar) before the attempts/results/AI-evaluation flow can support more than a single user attempting a single test once.

**When to fix:** Before building any Flutter UI or FastAPI logic on top of `test_attempts` / `question_results` / `ai_evaluations` — currently these tables can't be used for real multi-user data without this fix.

---

### `academic_year` filtering (exam prediction + pipeline)

`academic_year` exists on the `questions` table and in `UserModel` but is not yet used as a filter anywhere in the Flutter app or the FastAPI pipeline.

**What's missing:**
- `pipeline.py` — add `academic_year` to the Supabase select and returned dict
- `GET /questions` — add `academic_year` query param to `main.py`
- Datasource → repository → usecase → provider chain — `academicYear` param missing from all four layers in the exam prediction feature
- UI — no academic year filter chip; simplest fix is to read silently from `userProvider.academicYear` in `QuestionsNotifier.build()`

**When to fix:** Before Phase 5 personalisation — the daily question plan needs to scope questions to the student's academic year.

---

### Full DICL: top-15 cosine retrieval → MMR over those 15 → pick 5

Currently MMR runs over the entire question bank. The correct DICL implementation first retrieves the top-15 most relevant questions via cosine similarity, then runs MMR over just those 15 to pick 5. This gives better relevance at the same diversity level.

**When to fix:** Phase 6. Requires a meaningful question bank (100+ per subject) before the improvement is measurable.

---

### Onboarding subject selection — not wired to DB

The subject selection step in onboarding shows UI but does not fetch real subjects from the `subjects` table. The `subjects` provider and datasource are complete — this is just a wiring task.

**When to fix:** Before real user onboarding goes live.

---

### Focus session — minor issues

- **Duplicate controller file** — `widgets/focus_timer_controller.dart` duplicates `controllers/focus_timer_controller.dart`. Delete the widgets copy and update imports.
- **`resume()` is a no-op** — only calls `notifyListeners()`. Either remove or re-start the ticker if pause is introduced later.
- **`paused` state is unused** — `FocusTimerStatus.paused` is defined but never set.
- **No session persistence** — add `StorageService.saveSession(duration, completedAt)` inside `_onTick` when Phase 5 streak tracking lands.

---

### `published_tests.question_ids` is not a real foreign key

`question_ids` is a plain `uuid[]` array column, not a DB-enforced FK to `questions.id`. Deleting a `questions` row will silently leave a dangling ID in any `published_tests.question_ids` array that referenced it — no error, no cleanup. Relevant if a question-deletion or moderation feature is ever added.

**When to fix:** Before any admin/moderation tooling that deletes individual questions is built.

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
    LLM MCQ generation with 4 options + correct index
    LLM open question generation with structured model answers
    Exam type filtering (quiz / midsem / compre scope)
    Thread-safe parallel generation
    FastAPI backend with 7 endpoints
    Supabase integration (replaces question_bank.json + embeddings.npy)
    Railway deployment

Phase 3 — Core Features (complete)
    Mock test platform — full Clean Architecture
        ExamType enum as single source of truth
        4 exam types: Quiz, Midsem, Compre Part A, Compre Part B
        MCQ Blitz mode with timed quiz UI
        Written Practice mode with flashcard + paper views
        Model answers with structured markdown rendering
        loadExistingTest — reconstruct test from Supabase question IDs
    Exam prediction / question bank browser
    Community feed — live from Supabase (published_tests table)
        Attempt button wired to loadExistingTest
        College name read from userProvider
    Focus session timer (countdown, wave background, slide-to-start, custom duration picker)
    Auto-save written practice tests to published_tests on generation

Phase 4 — Auth and Backend (complete)
    ✅ Magic link auth via BITS college email (Supabase Auth)
    ✅ _isNewUser() routing — new → onboarding, returning → app
    ✅ Onboarding → Supabase write (users + user_subjects tables)
    ✅ EmailParser — roll_number, academic_year, subdomain from BITS email
    ✅ Campus resolution from campuses table via subdomain
    ✅ Real userProvider — fetches from Supabase, replaces hardcoded mock
    ✅ Subjects feature — full Clean Architecture
    ✅ Handout upload per subject — Supabase Storage, chip UI, fire-and-forget plan trigger
    ✅ study_plans table — AI-generated topic list + weekly schedule from handout PDF
    ✅ GoRouter migration — auth guard, named routes, context.push()
    ✅ RLS policies on users table and storage.objects
    ✅ PYQ upload through app UI
    ✅ Vote state persistence → Supabase write (post_votes table, optimistic UI)
    ✅ Subject retrieval corrected, user-selected subjects wired end-to-end into mock tests
    ✅ Null exam_type handled defensively in pipeline question filtering
    ⬜ _triggerPlanExtraction wired to real FastAPI URL
    ⬜ Study plan display UI per subject
    ⬜ Compre Part A → published_tests pipeline + feed (deferred to post-Phase 5)

Phase 5 — Personalisation
    Study plan display page per subject
    Personal learning goal mode
    AI daily question plan (current_topic from study_plans → MMR anchor)
    Lives and streak system
    Coin economy (earn by studying, spend to protect streaks)
    Daily college-wide brain puzzle
    College leaderboard (resets each semester)
    Dashboard integration with mock test scores
    Focus session history and streak tracking
    academic_year filter across pipeline + exam prediction
    Wire test_attempts / question_results / ai_evaluations into the app (composite uniqueness fix required first)

Phase 6 — ML Extension
    Full DICL: top-15 cosine retrieval → MMR over those 15 → pick 5
    Fine-tune FLAN-T5 on generated question-answer pairs
    Experiment comparing MMR vs random vs top-k selection
    Distractor quality analysis for MCQ options
```

---

*Built by Krishna — BITS Pilani Hyderabad, B.Tech CSE 2024–2028*
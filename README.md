# Skolar

An AI-powered exam preparation platform built with Flutter. Helps students track syllabus progress, attempt mock tests, get AI-driven predictions, and visualize their performance — all in one place.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Mock Test Platform](#mock-test-platform)
- [Exam Prediction Feature](#exam-prediction-feature)
- [Focus Session](#focus-session)
- [Community Feed](#community-feed)
- [Folder Structure](#folder-structure)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Dashboard -- How It Works](#dashboard--how-it-works)
- [Running the App](#running-the-app)
- [Code Generation](#code-generation)
- [Running the Backend](#running-the-backend)
- [Adding a New Feature](#adding-a-new-feature)
- [Tech Debt](#tech-debt)
- [Roadmap](#roadmap)

---

## Project Overview

This is an AI-powered study platform designed for college exam preparation. It offers personalized mock tests calibrated to a student's college difficulty level using Diverse In-Context Learning (DICL), along with PYQ analysis, performance analytics, goal tracking, and distraction-free focus sessions. Students can also access a community feed of AI-generated tests shared across subjects within their college ecosystem. Authentication through college email ensures secure, college-specific access to resources and data isolation.

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
| `data/datasources/mock_test_datasource.dart` | Calls `/generate-batch`, `/generate-open-batch`, fetches by IDs from Supabase |
| `data/repository_impl/mock_test_repository_impl.dart` | Wraps datasource in `Either<Failure, T>` |
| `presentation/providers/mock_tests_provider.dart` | `MockTestNotifier` — state, API calls, exam mode routing, `loadExistingTest` |
| `presentation/pages/mock_tests_pages.dart` | Full UI: setup screen, loading, error, MCQ flow, written practice flow, result screen |
| `shared/models/exam_type.dart` | `ExamType` enum — single source of truth used across mock tests and feed |

### `ExamMode` Mapping

```dart
ExamType.compreA  →  ExamMode.mcqBlitz      →  POST /generate-batch
ExamType.quiz     →  ExamMode.writtenPractice  →  POST /generate-open-batch
ExamType.midsem   →  ExamMode.writtenPractice  →  POST /generate-open-batch
ExamType.compreB  →  ExamMode.writtenPractice  →  POST /generate-open-batch
```

### Load Existing Test

`loadExistingTest(questionIds, examType)` fetches questions by their Supabase IDs and reconstructs the test state. Used by the community feed Attempt button. Currently only supports written practice exam types — see Tech Debt for Compre Part A limitation.

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
| Quiz        | quiz only                          |
| Midsem      | midsem + quiz1                     |
| Quiz 2      | quiz2 + midsem + quiz1             |
| Compre      | compre + quiz2 + midsem + quiz1    |

If no questions match the filter, the pipeline falls back to the full bank so generation never hard-fails.

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

### MMR Algorithm

At every step, MMR picks the candidate that maximises:

```
score = alpha * relevance_to_query - (1 - alpha) * max_similarity_to_already_selected
```

Alpha = 0.7 means 70% relevance, 30% diversity. Greedy algorithm that builds selection one item at a time.

### Supabase Schema

#### `questions` table

```
id              uuid, primary key
question_text   text
marks           integer
question_type   text  — mcq | short_answer | long_answer | numerical
subject         text
paper_year      integer
exam_type       text  — quiz | midsem | compre | generated
college         text  — used to scope all queries
embedding       vector(384)  — all-MiniLM-L6-v2 embedding of question_text
options         jsonb  — MCQ options array (null for open questions)
correct_index   smallint  — correct option index 0–3 (null for open questions)
```

#### `published_tests` table

```
id              uuid, primary key
subject         text
college         text
exam_type       text
question_ids    uuid[]  — references questions.id
created_at      timestamptz
student_name    text
attempt_count   integer
upvotes         integer
```

PYQ entries are uploaded via `/upload-pyq`. The `college` field on every row ensures complete data isolation between colleges.

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
  pipeline.py          — DICL pipeline: parsing, embedding, MMR, generation, bank I/O
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

### Known Issues and Next Steps

**Duplicate controller file** — `widgets/focus_timer_controller.dart` duplicates `controllers/focus_timer_controller.dart`. Delete the widgets copy and update imports.

**`resume()` is a no-op** — `FocusTimerController.resume()` only calls `notifyListeners()`. Either remove it or have it re-start the ticker if a pause state is introduced later.

**`paused` state is unused** — `FocusTimerStatus.paused` is defined but never set.

**No session persistence** — completed sessions are not written anywhere. When streak and history tracking land in Phase 5, add a `StorageService.saveSession(duration, completedAt)` call inside `_onTick` when `_secondsLeft` reaches zero.

---

## Community Feed

The community feed surfaces AI-generated tests created by students on college subjects. It is backed by a live Supabase query against the `published_tests` table.

### How a Test Gets Published

```
Student generates a written practice test (Quiz / Midsem / Compre B)
        ↓
Backend auto-saves questions to Supabase and inserts row into published_tests
        ↓
published_tests row contains: subject, college, exam_type, question_ids[], student_name
        ↓
GET /questions?published_only=true returns the questions
        ↓
Community feed shows the test with student name, subject, question count
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

### Flutter Files

| File | Role |
|---|---|
| `data/datasources/feed_remote_datasource.dart` | Queries `published_tests` from Supabase |
| `data/dtos/feed_post_dto.dart` | `fromSupabase` factory, `questionIds`, `examType` fields |
| `data/repository_impl/feed_repository_impl.dart` | Wraps remote datasource in `Either<Failure, T>` |
| `domain/entities/feed_post_entity.dart` | `examType`, `questionIds` fields; `bankIndices` removed |
| `presentation/providers/feed_provider.dart` | College read from `userProvider`, not hardcoded |
| `presentation/pages/feed_page.dart` | College from `userProvider` (hardcoded fallback removed) |
| `presentation/widgets/feed_post_card.dart` | Attempt button wired to `loadExistingTest` |

---

## Folder Structure

```
lib/
├── core/
│   ├── ai/
│   │   ├── data/                    # PYQ PDF files
│   │   └── rag_llms/                # Python backend
│   │       ├── main.py              # FastAPI app (all endpoints)
│   │       ├── pipeline.py          # DICL pipeline
│   │       └── .env                 # GROQ_API_KEY, SUPABASE_URL, SUPABASE_KEY
│   ├── config/
│   ├── di/
│   ├── errors/
│   ├── network/
│   ├── routing/
│   ├── services/
│   │   └── activity_log_service.dart   # stub — pending implementation
│   ├── storage/
│   ├── theme/
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
│   ├── analytics/
│   ├── dashboard/
│   ├── auth/
│   ├── onboarding/
│   ├── colleges/
│   ├── subjects/
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
| Code generation | `build_runner` |

### AI Backend

| Purpose | Tool |
|---|---|
| PDF text extraction | `pdfplumber` |
| Question extraction | Groq API — LLaMA 3.3 70B |
| Semantic embeddings | `sentence-transformers` — all-MiniLM-L6-v2 |
| Diversity selection | MMR algorithm (numpy) |
| MCQ + open question generation | Groq API — LLaMA 3.3 70B |
| Model answer generation | Groq API — LLaMA 3.3 70B |
| Parallel generation | `concurrent.futures.ThreadPoolExecutor` (3 workers) |
| Backend API | FastAPI + uvicorn |
| Deployment | Railway |
| Data store | Supabase (PostgreSQL + pgvector) |

---

## Features

### Built

- Scrollable analytics dashboard
  - Donut ring chart (task progress breakdown)
  - Weekly line chart (performance over 7 days)
  - Task list with assignee avatars and due dates
  - Recent activity feed
- Dark theme with custom color palette
- Clean Architecture scaffold for all features
- Dev menu for navigating between pages during development
- Full AI pipeline (DICL + MMR + Supabase)
  - PDF parsing and question extraction
  - Semantic embedding stored in Supabase pgvector
  - MMR-based diverse example selection
  - Exam type filtering (quiz / midsem / compre scope)
  - LLM MCQ generation with 4 options + correct answer
  - LLM open question generation with structured model answers
  - Thread-safe parallel generation (3 concurrent Groq calls)
  - Auto-save generated written practice tests to `published_tests`
- FastAPI backend with 7 endpoints, fully Supabase-backed, deployed on Railway
- Mock test platform — full Clean Architecture
  - `ExamType` enum as single source of truth (`shared/models/exam_type.dart`)
  - 4 exam types: Quiz, Midsem, Compre Part A, Compre Part B
  - MCQ Blitz mode (Compre Part A): timed quiz, score tracking, confetti
  - Written Practice mode (Quiz / Midsem / Compre Part B): flashcard + paper views
  - Model answers with structured markdown rendering
  - `loadExistingTest` — reconstruct written practice test from Supabase question IDs
- Exam prediction / question bank browser
  - Filter by subject, year, exam type, question type
- Focus session timer
  - Preset chips: Pomodoro (25 min), 45 min, 1 hr
  - Custom duration picker (5 min to 3 hr)
  - Slide-to-start track with spring physics
  - Animated wave background
  - Give Up confirmation sheet
  - Auto-reset if user leaves app mid-session
- Community feed — live from Supabase
  - Backed by `published_tests` table via `FeedRemoteDataSourceImpl`
  - Feed cards with student name, subject, difficulty badge, upvotes, attempt count
  - Attempt button wired to `loadExistingTest` on `MockTestNotifier`
  - College read from `userProvider`

### Planned

- Authentication flow with college email (Firebase Auth)
- Firestore / Supabase Auth integration
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
pip install fastapi uvicorn pdfplumber sentence-transformers numpy groq python-dotenv supabase

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
10. Add a route in `main.dart`
11. Run `dart run build_runner build --delete-conflicting-outputs`

Use the `analytics` feature as the reference implementation. Features with no persistence or backend requirement (like focus session) can skip steps 2–7 and use a `ChangeNotifier` directly in the presentation layer.

---

## Tech Debt

### Compre Part A (MCQ Blitz) — not published or loadable from feed

- `/generate-batch` does not save to `published_tests` (only `/generate-open-batch` does)
- `options` and `correct_index` columns exist on the `questions` table but the backend does not populate them on save yet
- `loadExistingTest` in the provider has no MCQ Blitz path — it would need to reconstruct `McqQuestion` objects from `options` / `correct_index`
- The feed page's Attempt button always routes to written practice mode regardless of `examType`

**When to fix:** When the backend is updated to save MCQ options on generation, wire the full path: save `options` + `correct_index` to `questions` → insert into `published_tests` → fetch with options on load → route to MCQ Blitz mode in feed.

---

### `academic_year` filtering (exam prediction + pipeline)

`academic_year` exists on the `questions` table and in `UserModel` but is not yet used as a filter anywhere in the Flutter app or the FastAPI pipeline.

**What's missing:**

- `pipeline.py` — `load_bank_and_embeddings` selects and returns `paper_year` but not `academic_year`. Add it to the Supabase select and the returned dict.
- `GET /questions` — no `academic_year` query param. Add it to `main.py` and the filter chain in `get_questions`.
- Datasource → repository → usecase → provider chain — `academicYear` param missing from all four layers in the exam prediction feature.
- UI — no academic year filter chip on the question bank browser. Simplest fix is to read it silently from `userProvider.academicYear` in `QuestionsNotifier.build()` so students see only their year by default.

**Why it's safe to defer:** Clean Architecture means each layer is independent. Adding the param is mechanical — no existing behaviour changes.

**When to fix:** Before Phase 5 personalisation, since the daily question plan needs to scope questions to the student's academic year.

---

### Full DICL: top-15 cosine retrieval → MMR over those 15 → pick 5

Currently MMR runs over the entire question bank. The correct DICL implementation first retrieves the top-15 most relevant questions via cosine similarity, then runs MMR over just those 15 to pick 5. This gives better relevance at the same diversity level.

---

### Focus session — minor issues

- **Duplicate controller file** — `widgets/focus_timer_controller.dart` duplicates `controllers/focus_timer_controller.dart`. Delete the widgets copy and update imports.
- **`resume()` is a no-op** — only calls `notifyListeners()`. Either remove or re-start the ticker if pause is introduced later.
- **`paused` state is unused** — `FocusTimerStatus.paused` is defined but never set.
- **No session persistence** — add `StorageService.saveSession(duration, completedAt)` inside `_onTick` when Phase 5 streak tracking lands.

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

Phase 4 — Auth and Backend
    College email authentication (Firebase Auth / Supabase Auth)
    PYQ upload through the app UI
    Vote state persistence → Supabase write on auth
    Compre Part A → published_tests pipeline + feed load support

Phase 5 — Personalisation
    Personal learning goal mode
    AI daily question plan
    Lives and streak system
    Dashboard integration with mock test scores
    Focus session history and streak tracking
    academic_year filter across pipeline + exam prediction

Phase 6 — ML Extension
    Full DICL: top-15 cosine retrieval → MMR over those 15 → pick 5
    Fine-tune FLAN-T5 on generated question-answer pairs
    Experiment comparing MMR vs random vs top-k selection
    Distractor quality analysis for MCQ options
```

---

*Built by Krishna — BITS Pilani Hyderabad, B.Tech CSE 2024–2028*
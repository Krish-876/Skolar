# Skolar

An AI-powered exam preparation platform built with Flutter. Helps students track syllabus progress, attempt mock tests, get AI-driven predictions, and visualize their performance — all in one place.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [AI Pipeline](#ai-pipeline)
- [Mock Test Platform](#mock-test-platform)
- [Exam Prediction Feature](#exam-prediction-feature)
- [Community Feed](#community-feed)
- [Folder Structure](#folder-structure)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Dashboard -- How It Works](#dashboard--how-it-works)
- [Running the App](#running-the-app)
- [Code Generation](#code-generation)
- [Running the Backend](#running-the-backend)
- [Adding a New Feature](#adding-a-new-feature)
- [Roadmap](#roadmap)

---

## Project Overview

Skolar is built for students preparing for college exams. The app combines:

- A scrollable analytics dashboard showing task progress, weekly performance, and recent activity
- AI-generated MCQ mock tests calibrated to the student's college difficulty standard using Diversity-based In-Context Learning (DICL)
- A community feed where AI-generated tests on college subjects are auto-published and can be attempted by other students
- PYQ (Previous Year Question) upload and analysis
- College and subject management
- Personal learning goal tracking with AI-generated daily question plans

Students authenticate with their college email. This automatically scopes them to their college's PYQ data, ensures data isolation across colleges, and provides implicit authorization to access those resources.

---

## Architecture

Skolar follows **Clean Architecture** with a **feature-first** folder structure. Every feature is fully isolated across three layers.

```
Presentation  ->  Domain  ->  Data
```

- **Presentation**: Riverpod providers, pages, widgets. Knows nothing about data sources.
- **Domain**: Pure Dart. Entities, repository interfaces, use cases. No Flutter imports.
- **Data**: DTOs, data sources, repository implementations. Talks to JSON files, APIs, or storage.

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
DataSource (local file / FastAPI / Firebase)
```

### Error Handling

- Data layer catches exceptions, returns `Either<Failure, Data>`
- Domain layer defines `Failure` types
- Presentation layer handles `Either` results with `state.when(loading, error, data)`

---

## AI Pipeline

The AI pipeline powers all question generation. It is a Python FastAPI service that the Flutter app calls over HTTP.

### Core Idea

Instead of generating generic questions, Skolar uses the college's own Previous Year Questions (PYQs) as a reference. The generated questions match that specific college's difficulty level, question style, and topic distribution. No manual labeling or tagging is required — the system infers difficulty from context.

### DICL — Diversity-based In-Context Learning

The pipeline is based on the paper *"Exploring the Role of Diversity in Example Selection for In-Context Learning"* published at SIGIR 2025. The key finding is that selecting diverse examples for the LLM prompt produces better outputs than selecting the most similar examples.

Naive example selection picks the most similar PYQs to the query. This causes topical bias — the LLM sees only one subtopic and generates repetitive questions. DICL uses MMR (Maximal Marginal Relevance) to pick examples that are both relevant and diverse, spreading coverage across different topics.

Token efficiency: instead of sending all PYQs to the LLM (~50,000 tokens), MMR selects 5 diverse examples (~2,000 tokens). This is a 95% reduction in token usage with better output quality.

### Self-Expanding RAG

Every AI-generated MCQ batch is automatically saved back to `question_bank.json` after generation. This means:

- The bank starts with 59 PYQ-extracted questions
- Every mock test run adds 5–10 new community-validated questions
- Future generation calls draw from a richer, larger pool
- The system improves with usage without any manual intervention

Only questions from college subjects are published to the community feed (see [Community Feed](#community-feed)), providing an additional quality filter on what re-enters the pool.

### Pipeline Steps

```
PDF Files (PYQs)
      ↓
pdfplumber — extract raw text
      ↓
Groq LLM (LLaMA 3.3 70B) — extract clean questions → question_bank.json
      ↓
sentence-transformers (all-MiniLM-L6-v2) — convert questions to vectors → embeddings.npy
      ↓
MMR Algorithm — select k diverse examples from question bank
      ↓
Groq LLM (LLaMA 3.3 70B) — generate MCQ with 4 options + correct_index
      ↓
MCQ returned to Flutter app
```

### MMR Algorithm

At every step, MMR picks the candidate that maximises:

```
score = alpha * relevance_to_query - (1 - alpha) * max_similarity_to_already_selected
```

Alpha = 0.7 means 70% relevance, 30% diversity. Greedy algorithm that builds selection one item at a time.

### Question Bank Schema

Every entry in `question_bank.json` uses a unified schema whether it came from a PYQ PDF or was AI-generated:

```json
{
  "question_text": "...",
  "marks": 2,
  "question_type": "mcq | short_answer | long_answer | numerical",
  "subject": "Artificial Intelligence",
  "year": 2025,
  "exam_type": "compre | midsem | generated",
  "source": "pyq | generated",
  "options": ["A", "B", "C", "D"],
  "correct_index": 1,
  "generated_by": "user_firebase_uid",
  "published": false,
  "upvotes": 0
}
```

PYQ entries have `options: null` and `correct_index: null`. Generated MCQs have all fields populated. MMR uses only `question_text` for embeddings — the extra fields are metadata and do not affect selection.

### FastAPI Endpoints

The backend runs at `http://<LAN_IP>:8000`. Start it with:

```bash
uvicorn main:app --reload --port 8000
```

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Sanity check |
| `GET` | `/stats` | Bank stats: total questions, subjects, years, source breakdown |
| `GET` | `/questions` | Browse/filter the question bank |
| `POST` | `/generate` | One open-ended question (original endpoint, unchanged) |
| `POST` | `/generate-batch` | N MCQs in parallel for a mock test session |
| `POST` | `/publish` | Mark a batch as published to the community feed |
| `POST` | `/upload-pyq` | PDF → extract questions → add to bank |

#### `POST /generate-batch` — Request body

```json
{
  "subject": "Artificial Intelligence",
  "count": 5,
  "year_from": 2024,
  "year_to": 2026,
  "k": 5,
  "user_id": "firebase_uid",
  "save_to_bank": true
}
```

Response includes `bank_indices` — the positions in the bank where the generated questions were saved. Pass these to `/publish`.

#### `POST /publish` — Request body

```json
{
  "bank_indices": [59, 60, 61, 62, 63],
  "user_id": "firebase_uid"
}
```

### Thread Safety

Multiple concurrent generation requests are safe. A `threading.Lock` (`_bank_lock`) guards all bank read-write operations. The `ThreadPoolExecutor` for parallel MCQ generation is capped at 5 workers to stay within Groq free-tier rate limits.

### Pipeline Location

```
lib/core/ai/rag_llms/
  main.py              — FastAPI app and all endpoints
  pipeline.py          — DICL pipeline: parsing, embedding, MMR, generation, bank I/O
  question_bank.json   — Unified question store (PYQ + generated)
  embeddings.npy       — (59+N, 384) embedding matrix
  .env                 — GROQ_API_KEY (not committed)
```

---

## Mock Test Platform

The mock test feature lets students take AI-generated MCQ tests calibrated to their subject and college difficulty.

### User Flow

1. Student opens Mock Test → sees a **Setup Screen** (subject dropdown + question count slider 3–10)
2. Taps **Start Test** → Flutter calls `POST /generate-batch`
3. **Loading screen** shown while the DICL pipeline runs (~4s per question in parallel)
4. Quiz UI launches with the generated questions
5. On completion → **Result screen** with score, grade, confetti if ≥ 70%
6. If the subject is a college subject → `/publish` is called automatically in the background
7. **New Test** button resets to the setup screen

### Flutter Files

| File | Role |
|---|---|
| `mock_tests_pages.dart` | Full UI: setup screen, loading, error, quiz flow, result screen |
| `mock_test_provider.dart` | `MockTestNotifier` — state management, API calls, publish logic |

### College Subject Detection

`mock_test_provider.dart` exports `kCollegeSubjects` — a `Set<String>` of subject names that trigger auto-publish. `isCollegeSubject(subject)` checks membership. Extend this set as subjects are added to the bank.

### State Machine

```
idle → loading → ready (quiz running) → idle (after New Test)
                       ↓ on last answer
                 publishing (background, non-blocking)
                       ↓
                 ready (published=true)
```

Publish failure is **silent and non-fatal** — the quiz result is never affected by a failed publish call.

### `MockTestState` Fields

| Field | Type | Description |
|---|---|---|
| `questions` | `List<QuizQuestion>` | The active quiz questions |
| `bankIndices` | `List<int>` | Positions in the backend bank for this batch |
| `subject` | `String` | Subject used to generate this test |
| `status` | `MockTestStatus` | `idle / loading / ready / publishing / error` |
| `published` | `bool` | Whether this batch has been published to the feed |
| `error` | `String?` | Error message if generation failed |

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

Questions can be filtered by `subject`, `year`, `exam_type`, `question_type`, `source` (`pyq` or `generated`), and `published_only`.

---

## Community Feed

The community feed is the social layer of Skolar. It surfaces AI-generated tests created by students on college subjects.

### How a Test Gets Published

```
Student generates a test on "Artificial Intelligence"
        ↓
isCollegeSubject("Artificial Intelligence") == true
        ↓
After quiz completion, Flutter calls POST /publish with bank_indices
        ↓
Backend sets published=true on those questions in question_bank.json
        ↓
Questions appear in GET /questions?published_only=true
        ↓
Community feed shows the test with student name, subject, question count
```

### What Appears in the Feed

Each card represents one student's completed AI-generated test. It shows student name + year + branch, subject, year range, question count, difficulty badge, upvote/downvote counts, attempt count, and an Attempt button.

### Key Design Property

The feed **is** the AI output made public — no separate upload flow. Generation → completion → auto-publish is the entire pipeline.

### Feed Architecture

The feed follows the same Clean Architecture pattern as every other feature. The datasource swap from local mock data to the real API touches exactly one file:

```
FeedLocalDataSourceImpl  →  FeedRemoteDataSourceImpl
        (mock JSON)               (GET /questions?published_only=true)
```

Everything above — `FeedRepositoryImpl`, `GetFeedUseCase`, `FeedNotifier`, `FeedPage`, `FeedPostCard` — stays identical. The provider chain is:

```
feedDataSourceProvider   (FeedLocalDataSource)
        ↓
feedRepositoryProvider   (FeedRepositoryImpl)
        ↓
getFeedUseCaseProvider   (GetFeedUseCase)
        ↓
feedProvider             (AsyncNotifier<List<FeedPostEntity>>)
        ↓
sortedFeedProvider       (derived, cached — sort logic fully decoupled)
        ↓
FeedPage                 feedAsync.when(loading, error, data)
        ↓
FeedPostCard             .select() on vote state — only affected card rebuilds
```

`refresh()` uses `ref.invalidateSelf()` which works correctly for both local and remote sources — no change needed when the datasource swaps.

### Feed Open Ends (pre-API checklist)

These are the specific things that need to be wired up before or during the API connection. The UI and architecture do not need to change.

**1. Attempt button — add `onTap`**

`_CardFooter` renders the Attempt button as a static `Container` with no gesture handler. When connecting, wrap it in a `GestureDetector` that calls `MockTestNotifier.fetchQuestions()` with the post's subject and navigates to the mock test flow. `FeedPostEntity` already has `subject`, `questionCount`, and `yearRange` — everything needed to build a `MockTestRequest`.

```dart
// What needs to be added to _CardFooter
GestureDetector(
  onTap: () {
    ref.read(mockTestProvider.notifier).fetchQuestions(
      MockTestRequest(subject: post.subject, count: post.questionCount),
    );
    context.push('/mock-test');
  },
  child: /* existing Attempt container */,
)
```

**2. Add `bankIndices` to `FeedPostEntity` now**

The entity needs a `bankIndices: List<int>` field so the Attempt button can re-serve the exact same questions that were originally generated. Add it now with `@Default([])` so existing mock data still compiles:

```dart
// Add to FeedPostEntity
final List<int> bankIndices; // positions in question_bank for this batch
```

This is the only entity change needed before the API connection.

**3. Vote state — add persistence**

`upvotedPostsProvider` and `downvotedPostsProvider` are `StateProvider<Set<String>>` — in-memory only, reset on restart. The optimistic update logic in `toggleUpvote` / `toggleDownvote` is already correct. When Firebase lands, add a Firestore write alongside the local state update:

```dart
void toggleUpvote(String postId) {
  // existing local toggle logic — keep as-is
  ...
  // add:
  FirestoreService.setUpvote(postId, userId, isUpvoted);
}
```

**4. College name — read from `userProvider`**

`'BITS Pilani · Hyderabad'` is a hardcoded string literal in `_TopBar`. When auth lands, replace with:

```dart
// _TopBar becomes a ConsumerWidget
final user = ref.watch(userProvider);
Text(user.college)
```

`userProvider` in `shared/providers/` already returns a `UserModel` with a `college` field — the plumbing exists, just needs to be read.

**5. `generate_sheet.dart` — commented out import**

`// import '../widgets/generate_sheet.dart'` suggests a "generate test from feed" flow was started. This is intentionally deferred — wire it up when the Attempt flow is working.

### Firestore Migration

Currently `question_bank.json` is the data store. When Firebase is integrated:

- Each question becomes a Firestore document in a `questions` collection
- `embeddings.npy` moves to Firestore vector fields or Pinecone
- The feed reads from Firestore in real time
- Upvotes and attempt counts become live Firestore counters

`pipeline.py` does not change — only `load_bank_and_embeddings` / `save_bank_and_embeddings` get swapped for Firestore reads/writes.

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
│   │       ├── question_bank.json   # Unified question store
│   │       ├── embeddings.npy       # Embedding matrix (59+N, 384)
│   │       └── .env                 # GROQ_API_KEY
│   ├── config/
│   ├── di/
│   ├── errors/
│   ├── network/
│   ├── routing/
│   ├── services/
│   ├── storage/
│   ├── theme/
│   └── widgets/
│
├── shared/
│   ├── components/
│   ├── extensions/
│   ├── models/
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
│   ├── exam_prediction/             # Question bank browser + stats (rebuilt)
│   │   ├── data/
│   │   │   ├── datasources/         # exam_prediction_datasource.dart
│   │   │   ├── dtos/
│   │   │   └── repository_impl/     # exam_prediction_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/            # exam_prediction_entity.dart
│   │   │   ├── repositories/
│   │   │   └── usecases/            # exam_prediction_usecases.dart
│   │   └── presentation/
│   │       ├── pages/               # exam_prediction_pages.dart
│   │       └── providers/           # exam_prediction_provider.dart
│   │
│   ├── feed/                        # Community feed
│   │   └── presentation/
│   │       ├── pages/               # feed_page.dart
│   │       └── widgets/             # feed_post_card.dart
│   │
│   ├── mock_tests/                  # AI-generated MCQ quiz platform
│   │   └── presentation/
│   │       ├── pages/               # mock_tests_pages.dart
│   │       └── providers/           # mock_test_provider.dart
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
| Code generation | `build_runner` |

### AI Backend

| Purpose | Tool |
|---|---|
| PDF text extraction | `pdfplumber` |
| Question extraction | Groq API — LLaMA 3.3 70B |
| Semantic embeddings | `sentence-transformers` — all-MiniLM-L6-v2 |
| Diversity selection | MMR algorithm (numpy) |
| MCQ generation | Groq API — LLaMA 3.3 70B |
| Parallel generation | `concurrent.futures.ThreadPoolExecutor` |
| Thread-safe bank writes | `threading.Lock` |
| Backend API | FastAPI + uvicorn |

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
- Full AI pipeline (DICL + MMR)
  - PDF parsing and question extraction
  - Semantic embedding of question bank
  - MMR-based diverse example selection
  - LLM MCQ generation with 4 options + correct answer
  - Year range filtering
  - Self-expanding RAG (generated questions saved back to bank)
  - Thread-safe parallel generation (up to 5 concurrent Groq calls)
- FastAPI backend with 6 endpoints
- Mock test platform
  - Setup screen (subject picker + question count slider)
  - Loading screen with generation status
  - Full quiz UI (timer, progress bar, animated option tiles)
  - Result screen with grade, score, confetti
  - Auto-publish to community feed on completion for college subjects
- Exam prediction / question bank browser (rebuilt)
  - Filter by subject, year, exam type, source, published status
- Community feed
  - Feed cards with student name, subject, difficulty badge, upvotes, attempt count
  - Attempt button to take any published test

### Planned

- Community feed (`feed_page.dart`, `feed_post_card.dart`) — cards showing published tests with upvotes, attempt counts, difficulty badges, and Attempt button
- Authentication flow with college email
- Firebase integration (Firestore for question bank, Auth for users)
- Syllabus progress tracking
- PYQ upload through the app UI
- Personal learning goal mode (daily AI question plan with lives/streaks)

---

## Dashboard -- How It Works

The dashboard is the most complete feature. Understanding it explains how every other feature will work too.

### Data Source

All dashboard data lives in a single JSON file:

```
assets/data/analytics.json
```

To change what appears on screen, edit this file and hot-restart the app.

### What Each Field Controls

| Field in JSON | What changes on screen |
|---|---|
| `total_tasks_completed` | Big number in the center of the ring chart |
| `todo_percent` | Blue segment of ring + "To Do" percentage label |
| `in_progress_percent` | Teal segment + "In Progress" label |
| `completed_percent` | Grey segment + "Completed" label |
| `weekly_progress` | Points on the line chart (label = day, value = 0–100) |
| `tasks` | Rows in the Tasks list (title, due date, avatar initials) |
| `recent_activities` | Rows in Recent Activity (time, title, subtitle, date) |

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
DonutProgressChart               reads todoPercent, inProgressPercent, completedPercent
WeeklyLineChart                  reads weeklyProgress list
TaskListTile                     reads tasks list
RecentActivityTile               reads recentActivities list
```

### How It Will Connect to Mock Tests

When mock test results are complete:

1. The result screen writes scores to `StorageService`
2. The datasource is swapped to read from `StorageService` instead of the JSON file
3. After writing, mock test calls `ref.invalidate(dashboardProvider)`
4. The dashboard automatically rebuilds with the new data

No dashboard code changes needed — only the datasource implementation changes.

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

Skolar uses two code generation tools. Understanding when and how to run them saves a lot of confusion.

### What gets generated

`build_runner` produces two types of files:

| File suffix | Generated by | Purpose |
|---|---|---|
| `.freezed.dart` | `freezed` | Immutable value classes: `copyWith`, `==`, `hashCode`, pattern matching |
| `.g.dart` | `json_serializable` | `fromJson` / `toJson` methods |

These files are committed to git. Never edit them manually — they get overwritten on the next build.

### When to run it

Run `build_runner` after any of these:
- Adding a new `@freezed` class
- Adding or removing a field on a `@freezed` class
- Adding a new `@JsonSerializable` DTO
- Adding or removing a `@JsonKey` annotation
- After a `git pull` that touched any model files (if the `.freezed.dart` or `.g.dart` is out of sync you'll get immediate compile errors)

### Commands

```bash
# One-time build (use this normally)
dart run build_runner build --delete-conflicting-outputs

# Watch mode — auto-rebuilds on file save (use during active model work)
dart run build_runner watch --delete-conflicting-outputs

# Clean all generated files and rebuild from scratch (use when things are broken)
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

Always use `--delete-conflicting-outputs`. Without it, build_runner refuses to overwrite existing generated files and fails with a conflict error.

### How `@freezed` is used in this codebase

Domain entities use `@freezed`. DTOs use `@JsonSerializable` only (no freezed). This is intentional — DTOs are data-layer objects that get converted to domain entities via `.toDomain()`, so they don't need immutability guarantees.

```dart
// Domain entity — uses @freezed (lib/features/*/domain/entities/)
@freezed
class QuestionItem with _$QuestionItem {
  const factory QuestionItem({
    required String questionText,
    required int marks,
    required String questionType,
    required String subject,
    required int year,
    required String examType,
  }) = _QuestionItem;
}

// DTO — uses @JsonSerializable only (lib/features/*/data/dtos/)
@JsonSerializable()
class QuestionItemDto {
  @JsonKey(name: 'question_text')
  final String questionText;
  // ...
  factory QuestionItemDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionItemDtoFromJson(json);
  QuestionItem toDomain() => QuestionItem(...);
}
```

### Adding a new field to a freezed class

1. Add the field to the `const factory` constructor
2. If it has a default value, use `@Default(value)` not `= value`
3. Run `dart run build_runner build --delete-conflicting-outputs`
4. The generated `.freezed.dart` updates automatically — `copyWith`, `==`, and `hashCode` all include the new field

```dart
// Before
@freezed
class FeedPostEntity with _$FeedPostEntity {
  const factory FeedPostEntity({
    required String id,
    required int upvotes,
  }) = _FeedPostEntity;
}

// After adding a field
@freezed
class FeedPostEntity with _$FeedPostEntity {
  const factory FeedPostEntity({
    required String id,
    required int upvotes,
    @Default([]) List<int> bankIndices,  // ← new field, default keeps old call sites compiling
  }) = _FeedPostEntity;
}
```

### Common errors and fixes

**`part 'some_file.freezed.dart'` — file not found**
The generated file doesn't exist yet. Run `build_runner build`.

**`The name '_$SomeClass' isn't defined`**
Same cause — generated file missing or stale. Run `build_runner build --delete-conflicting-outputs`.

**`Couldn't read file` or `existing file differs`**
A generated file exists but conflicts with what build_runner wants to write. The `--delete-conflicting-outputs` flag handles this automatically. If it still fails, run `build_runner clean` first.

**Build succeeds but app still has errors after a git pull**
Someone on another branch changed a model. Run `build_runner build --delete-conflicting-outputs` — the generated files in your working tree are stale.

**`withOpacity` or other method missing on a freezed class**
You're trying to call a method that only exists on the concrete class, not the interface. Add a private constructor: `const FeedPostEntity._();` between the `@freezed` line and the `const factory`.

---

## Running the Backend

```bash
cd lib/core/ai/rag_llms

# Create and activate environment
python -m venv myenv311
myenv311\Scripts\activate          # Windows
source myenv311/bin/activate       # macOS / Linux

# Install dependencies
pip install fastapi uvicorn pdfplumber sentence-transformers numpy groq python-dotenv

# Create .env file
echo GROQ_API_KEY=your_key_here > .env

# Start the server
uvicorn main:app --reload --port 8000
```

The server starts at `http://0.0.0.0:8000`. Interactive API docs at `http://localhost:8000/docs`.

**Testing from Flutter on a physical device:** replace `localhost` with your machine's LAN IP (e.g. `192.168.29.196`). The base URL is defined in `mock_test_provider.dart` as `_kBaseUrl`.

### Generating Questions (Notebook)

The original Jupyter notebook (`data_extraction_llms.ipynb`) is still available for exploratory work and initial question extraction from new PDFs. For everything else, use the FastAPI server.

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

Use the `analytics` feature as the reference implementation — it is the most complete example.

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
    Year range filtering
    Self-expanding RAG (generated questions saved to bank)
    Thread-safe parallel generation
    FastAPI backend with 6 endpoints

Phase 3 — Core Features (complete)
    Mock test platform (setup, quiz, result, auto-publish)
    Exam prediction / question bank browser (rebuilt)
    Community feed (feed_page, feed_post_card, upvotes, attempt counts)
    Community feed backend (publish endpoint, published_only filter)

Phase 4 — Auth and Backend
    College email authentication (Firebase Auth)
    Firebase Firestore integration (replace question_bank.json + embeddings.npy)
    PYQ upload through the app UI

Phase 5 — Personalisation
    Personal learning goal mode
    AI daily question plan
    Lives and streak system
    Dashboard integration with mock test scores

Phase 6 — ML Extension
    Fine-tune FLAN-T5 on generated question-answer pairs
    Experiment comparing MMR vs random vs top-k selection
    Distractor quality analysis for MCQ options
```

---

*Built by Krishna — BITS Pilani Hyderabad, B.Tech CSE 2024–2028*
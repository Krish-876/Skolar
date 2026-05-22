# Skolar — Architecture

Skolar follows Clean Architecture with a feature-first folder structure, optimised for scalability and maintainability.

---

## Core Principles

1. **Separation of Concerns** — each layer has distinct responsibilities
2. **Dependency Rule** — dependencies always point inward (toward domain)
3. **Testability** — all layers are independently testable
4. **Feature Isolation** — features are completely self-contained
5. **Extensibility** — new features can be added without modifying existing code

---

## Layers

```
Presentation  →  Domain  →  Data
```

| Layer | Responsibility | Allowed dependencies |
|---|---|---|
| Domain | Entities, repository interfaces, use cases | `freezed_annotation`, `dartz` only |
| Data | DTOs, datasources, repository implementations | Domain + `dio`, `json_annotation`, storage |
| Presentation | Pages, widgets, Riverpod providers | Domain + Flutter + Riverpod |

Dependencies always point **inward**. Data depends on domain. Presentation depends on domain. Nothing depends on presentation or data directly.

---

## Folder Structure

```
lib/
├── core/                              # App-wide infrastructure
│   ├── ai/
│   │   ├── data/                      # PYQ PDF source files
│   │   └── rag_llms/                  # Python backend (FastAPI + DICL pipeline)
│   │       ├── main.py                # FastAPI app — all endpoints
│   │       ├── pipeline.py            # DICL: parsing, MMR, generation, bank I/O
│   │       ├── question_bank.json     # Unified question store (PYQ + generated)
│   │       ├── embeddings.npy         # Embedding matrix (N, 384)
│   │       └── .env                   # GROQ_API_KEY (not committed)
│   ├── config/                        # Environment and app constants
│   ├── di/                            # GetIt service locator setup
│   ├── errors/                        # Failure types and exception classes
│   ├── network/                       # Dio HTTP client with interceptors
│   ├── routing/                       # GoRouter configuration
│   ├── services/                      # Logging, analytics services
│   ├── storage/                       # Local storage abstraction
│   ├── theme/
│   │   ├── app_theme.dart             # Base theme, color tokens
│   │   ├── app_animated_mesh_theme.dart
│   │   └── app_static_mesh_theme.dart
│   └── widgets/
│       ├── glass_background.dart
│       └── animated_profile_gradient.dart
│
├── shared/
│   ├── components/                    # LoadingButton, AppTextField, etc.
│   ├── extensions/                    # String, List, Num extensions
│   ├── models/                        # Base entity and DTO classes, UserModel
│   └── providers/                     # Global providers: userProvider, isLoadingProvider
│
├── features/
│   ├── analytics/                     # Dashboard data layer
│   │   ├── data/
│   │   │   ├── datasources/           # Reads analytics.json via rootBundle
│   │   │   ├── dtos/                  # AnalyticsDataDto, TaskItemDto, etc.
│   │   │   └── repository_impl/
│   │   ├── domain/
│   │   │   ├── entities/              # AnalyticsData, TaskItem, WeeklyDataPoint
│   │   │   ├── repositories/
│   │   │   └── usecases/              # GetAnalyticsUseCase
│   │   └── presentation/
│   │
│   ├── auth/                          # Authentication (college email)
│   ├── onboarding/                    # Onboarding flow
│   ├── colleges/                      # College search and management
│   ├── subjects/                      # Subject management
│   ├── syllabus/                      # Syllabus content and progress
│   ├── pyq_upload/                    # PYQ PDF upload
│   │
│   ├── dashboard/                     # Main dashboard screen
│   │   └── presentation/
│   │       ├── pages/                 # DashboardPage
│   │       ├── providers/             # DashboardNotifier (AsyncNotifier)
│   │       └── widgets/               # DonutProgressChart, WeeklyLineChart,
│   │                                  # TaskListTile, RecentActivityTile,
│   │                                  # AnimatedMeshBg
│   │
│   ├── exam_prediction/               # Question bank browser + stats (rebuilt)
│   │   ├── data/
│   │   │   ├── datasources/           # exam_prediction_datasource.dart
│   │   │   ├── dtos/                  # exam_prediction_dto.dart (@JsonSerializable)
│   │   │   └── repository_impl/      # exam_prediction_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/              # exam_prediction_entity.dart (@freezed)
│   │   │   ├── repositories/
│   │   │   └── usecases/              # GetQuestionsUseCase, GetStatsUseCase
│   │   └── presentation/
│   │       ├── pages/                 # exam_prediction_pages.dart
│   │       └── providers/             # exam_prediction_provider.dart
│   │
│   ├── feed/                          # Community feed
│   │   ├── data/
│   │   │   ├── datasources/           # FeedLocalDataSource (swap → FeedRemoteDataSource for API)
│   │   │   ├── dtos/
│   │   │   └── repository_impl/      # FeedRepositoryImpl
│   │   ├── domain/
│   │   │   ├── entities/              # FeedPostEntity (plain Dart class, no @freezed)
│   │   │   ├── repositories/          # FeedRepository (abstract)
│   │   │   └── usecases/              # GetFeedUseCase
│   │   └── presentation/
│   │       ├── pages/                 # feed_page.dart
│   │       ├── providers/             # feed_provider.dart, feed_sort_option.dart
│   │       └── widgets/               # feed_post_card.dart, feed_colors.dart,
│   │                                  # feed_sort_sheet.dart
│   │
│   ├── mock_tests/                    # AI-generated MCQ quiz platform
│   │   └── presentation/
│   │       ├── pages/                 # mock_tests_pages.dart
│   │       └── providers/             # mock_test_provider.dart
│   │
│   └── profile/                       # User profile
│       └── presentation/
│           ├── pages/                 # profile_pages1.dart, profile_page2.dart
│           └── widgets/               # settings_glass.dart
│
└── main.dart                          # App entry point, GoRouter, ProviderScope
```

---

## State Management

All async state uses `AsyncNotifier` (Riverpod 2.x). Sync state uses `Notifier`. The older `StateNotifier` pattern is not used.

### Standard async flow

```
UI Widget (ConsumerWidget / ConsumerStatefulWidget)
   ↓  ref.watch(someProvider)
AsyncNotifierProvider
   ↓  calls
UseCase
   ↓  calls
Repository (abstract interface)
   ↓  implemented by
RepositoryImpl
   ↓  calls
DataSource (local JSON / FastAPI / Firebase)
```

### Standard sync flow (e.g. vote state, sort state)

```
UI Widget
   ↓  ref.watch(someProvider)
NotifierProvider / StateProvider
   ↓  direct state mutation via notifier methods
```

### Derived providers (cached, no recompute on rebuild)

```dart
final sortedFeedProvider = Provider<List<FeedPostEntity>>((ref) {
  final feedAsync = ref.watch(feedProvider);
  final sort = ref.watch(feedSortProvider);
  return feedAsync.maybeWhen(
    data: (posts) => _sort(posts, sort),
    orElse: () => [],
  );
});
```

Derived providers are the correct place for any transformation of existing state (sorting, filtering, mapping). Never sort/filter inside a widget's `build` method.

### Selective rebuild

```dart
// Only this card rebuilds when its own vote state changes
final upvoted = ref.watch(
  upvotedPostsProvider.select((s) => s.contains(post.id)),
);
```

Use `.select()` whenever you watch a collection but only care about one element.

---

## Error Handling

| Layer | Behaviour |
|---|---|
| Domain | Defines `Failure` types. Use cases receive `Either<Failure, T>` from repositories |
| Data | Catches all exceptions, converts to `Failure`, returns `Either<Failure, T>` |
| Presentation | `AsyncNotifier.build()` throws (Riverpod catches it); `state.when(error:)` shows UI |

Never swallow exceptions silently. Never expose raw exceptions to the UI — convert to a human-readable `Failure.message` at the data layer.

---

## Code Generation

Two tools run via `build_runner`:

| Output | Tool | Used on |
|---|---|---|
| `.freezed.dart` | `freezed` | Domain entities |
| `.g.dart` | `json_serializable` | Data DTOs |

**Rule:** domain entities use `@freezed`. DTOs use `@JsonSerializable` only. Never `@freezed` a DTO.

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run after any model change, and after any `git pull` that touched entity or DTO files.

---

## AI Backend

The Python FastAPI backend lives at `lib/core/ai/rag_llms/`. It is a separate process — run with `uvicorn main:app --reload --port 8000`.

### DICL Pipeline

```
PDF Files (PYQs)
      ↓
pdfplumber — raw text extraction
      ↓
Groq LLM (LLaMA 3.3 70B) — structured question extraction → question_bank.json
      ↓
sentence-transformers (all-MiniLM-L6-v2) — embed questions → embeddings.npy
      ↓
MMR Algorithm — select k diverse examples
      ↓
Groq LLM — generate MCQ (question + 4 options + correct_index)
      ↓
Returned to Flutter via POST /generate-batch
```

### Self-Expanding RAG

Every generated MCQ batch is saved back to `question_bank.json` immediately after generation (`save_to_bank: true` by default). The bank grows with usage, making future generation richer. Published questions (college subject tests) are marked `published: true` via `POST /publish` and appear in the feed via `GET /questions?published_only=true`.

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Sanity check |
| `GET` | `/stats` | Bank stats |
| `GET` | `/questions` | Browse/filter bank |
| `POST` | `/generate` | One open-ended question |
| `POST` | `/generate-batch` | N MCQs in parallel |
| `POST` | `/publish` | Mark batch as published |
| `POST` | `/upload-pyq` | PDF → extract → add to bank |

### Thread Safety

A `threading.Lock` (`_bank_lock`) guards all bank read/write operations. `ThreadPoolExecutor` (max 5 workers) handles parallel MCQ generation without hitting Groq rate limits.

---

## Feed — Open Ends (pre-Firebase checklist)

The feed architecture is complete. These are the specific wiring steps before the API connection:

| # | What | Where | Depends on |
|---|---|---|---|
| 1 | Attempt button `onTap` → `MockTestNotifier.fetchQuestions()` + navigate | `feed_post_card.dart` `_CardFooter` | Mock test navigation being stable |
| 2 | Vote persistence → Firestore write alongside local state update | `feed_provider.dart` `toggleUpvote/Down` | Firebase Auth |
| 3 | College name → read from `userProvider` instead of hardcoded string | `feed_page.dart` `_TopBar` | Firebase Auth |
| 4 | Datasource swap → `FeedRemoteDataSourceImpl` calling `GET /questions?published_only=true` | `feed/data/datasources/` | Backend deployed |

`FeedPostEntity.bankIndices` is already added — that was the only structural change needed before the API connection.

---

## Dependency Injection

GetIt service locator is configured in `core/di/`. Features register their datasources, repositories, and use cases there. Riverpod providers reference GetIt-registered instances where needed, keeping the two systems loosely coupled.

---

## Adding a New Feature

1. Create folder structure under `lib/features/your_feature/`
2. Define domain entities in `domain/entities/` using `@freezed`
3. Define repository interface in `domain/repositories/`
4. Write use cases in `domain/usecases/`
5. Create DTOs in `data/dtos/` using `@JsonSerializable`
6. Implement datasource in `data/datasources/`
7. Implement repository in `data/repository_impl/`
8. Create `AsyncNotifierProvider` in `presentation/providers/`
9. Build page and widgets in `presentation/pages/` and `presentation/widgets/`
10. Add route in `main.dart`
11. Run `dart run build_runner build --delete-conflicting-outputs`

Use the `analytics` feature as the reference implementation — it is the most complete and cleanest example in the codebase.

---

## Future Migration Points

| Current | Target | Trigger |
|---|---|---|
| `question_bank.json` + `embeddings.npy` | Firestore + Pinecone/pgvector | Firebase integration |
| `FeedLocalDataSourceImpl` (mock data) | `FeedRemoteDataSourceImpl` (API) | Backend deployed |
| `userProvider` (hardcoded `UserModel`) | Firebase Auth user stream | Auth feature complete |
| Groq free tier | Paid LLM provider or job queue | 50+ concurrent users |
| Vote state (`StateProvider<Set<String>>`) | Firestore counters | Firebase integration |
# Skolar — Flutter App

Feature-by-feature reference for the Flutter client: architecture, folder
structure, every shipped feature, and how to run/generate code. Backend
services are documented in [BACKEND.md](BACKEND.md) and [NOVA.md](NOVA.md);
schema in [DATABASE.md](DATABASE.md).

Back to [README](README.md).

---

## Table of Contents

- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Tech Stack](#tech-stack)
- [Running the App](#running-the-app)
- [Code Generation](#code-generation)
- [Adding a New Feature](#adding-a-new-feature)
- [Mock Test Platform](#mock-test-platform)
- [Exam Prediction (Question Bank Browser)](#exam-prediction-question-bank-browser)
- [Focus Session](#focus-session)
- [Community Feed](#community-feed)
- [Subjects and Handout Upload](#subjects-and-handout-upload)
- [Profile](#profile)
- [Dashboard](#dashboard)
- [Math Game](#math-game)
- [Authentication](#authentication)
- [Tech Debt](#tech-debt)

---

## Architecture

Follows **Clean Architecture** with a **feature-first** folder structure.
Every feature is fully isolated across three layers.

```
Presentation  ->  Domain  ->  Data
```

- **Presentation**: Riverpod providers, pages, widgets. Knows nothing about
  data sources.
- **Domain**: Pure Dart. Entities, repository interfaces, use cases. No
  Flutter imports.
- **Data**: DTOs, data sources, repository implementations. Talks to
  Supabase, APIs, or local storage.

Dependencies always point **inward** — data depends on domain, presentation
depends on domain, nothing depends on presentation or data directly. See
also [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full write-up of these
principles.

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

## Folder Structure

```
lib/
├── core/
│   ├── ai/
│   │   └── ai_service.dart          # thin client, not the pipeline itself — see BACKEND.md/NOVA.md
│   ├── config/
│   │   └── environment.dart         # apiBaseUrl per environment — see BACKEND.md's port table
│   ├── di/
│   ├── errors/
│   ├── network/
│   │   └── dio_http_client.dart     # has AuthInterceptor/setBearerToken() — currently unused by any feature
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
│   ├── auth/                        # real — see Authentication below
│   ├── onboarding/
│   ├── subjects/
│   ├── analytics/
│   ├── dashboard/                   # real widgets, dummy in-memory data — see Dashboard below
│   ├── colleges/
│   ├── syllabus/
│   ├── pyq_upload/
│   ├── exam_prediction_with_bank/   # renamed/restructured from the old exam_prediction — see below
│   ├── feed/
│   ├── focus_session/
│   ├── math_game/                   # new — see Math Game below
│   ├── mock_tests/
│   ├── nova_chat/                   # real, shipped — see NOVA.md
│   └── profile/                     # real, Supabase-backed — see Profile
│
└── main.dart
```

Python backend layout (`backend/app`, `backend/nova`, `backend/pyq`) is
documented in [BACKEND.md](BACKEND.md) and [NOVA.md](NOVA.md), not here —
none of it lives under `lib/` anymore.

## Tech Stack

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| Immutable models | `freezed` + `freezed_annotation` |
| JSON serialization | `json_serializable` + `json_annotation` |
| Functional error handling | `dartz` (Either type) — see [Tech Debt](#tech-debt) re: `CONTRIBUTING.md` saying `fpdart` |
| HTTP client | `dio` |
| Dependency injection | `get_it` |
| Local storage | `hive` + `shared_preferences` |
| Charts | `fl_chart` |
| Quiz confetti | `confetti ^0.8.0` |
| Markdown rendering | `flutter_markdown_plus` |
| File picker | `file_picker ^11.0.2` |
| Onboarding success animation | `lottie ^3.5.1` (`onboarding_success.lottie`) |
| SVG rendering (Profile avatar) | `flutter_svg ^2.3.0` |
| Mock test / quiz success animation | Custom PNG frame-sequence player (`assets/animations/tick_frames/`) |
| Code generation | `build_runner` |

## Running the App

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Code Generation

| File suffix | Generated by | Purpose |
|---|---|---|
| `.freezed.dart` | `freezed` | Immutable value classes |
| `.g.dart` | `json_serializable` | `fromJson` / `toJson` methods |

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

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

## Mock Test Platform

Lets students take AI-generated tests calibrated to subject, college, and
exam type. Full Clean Architecture across all layers.

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
ExamType.compreA  →  ExamMode.mcqBlitz        →  POST /generate-batch
ExamType.quiz     →  ExamMode.writtenPractice  →  POST /generate-open-batch
ExamType.midsem   →  ExamMode.writtenPractice  →  POST /generate-open-batch
ExamType.compreB  →  ExamMode.writtenPractice  →  POST /generate-open-batch
```

Both `/generate-batch`/`/generate-open-batch` calls need `persist: true` to
actually save to `published_tests` — see [BACKEND.md](BACKEND.md#question-generation-pipeline-backendpyqrag).

### Load Existing Test

`loadExistingTest(questionIds, examType)` fetches questions by their
Supabase IDs and reconstructs test state. Used by the community feed
Attempt button. Currently only supports written practice exam types.

### Dynamic Subject Sourcing

The setup screen pulls the student's subject list from their actual
`user_subjects` enrollment rather than a hardcoded list.

## Exam Prediction (Question Bank Browser)

Lets students browse and filter the college question bank. Directory is
`lib/features/exam_prediction_with_bank/` (renamed from the earlier flat
`exam_prediction_*` layout), with files now under a `questions_feature/`
subfolder and an explicit `exam_prediction_repository.dart` interface split
out from `exam_prediction_repository_impl.dart`.

### Flutter Files

| File | Role |
|---|---|
| `questions_feature/exam_prediction_pages.dart` | Main page with tabs: Question Bank browser |
| `questions_feature/exam_prediction_datasource.dart` | Calls generation/upload/stats/questions endpoints |
| `questions_feature/exam_prediction_repository.dart` | Abstract repository interface |
| `questions_feature/exam_prediction_repository_impl.dart` | Wraps datasource in `Either<Failure, T>` |
| `questions_feature/exam_prediction_provider.dart` | Riverpod notifier for question bank state |
| `questions_feature/exam_prediction_usecases.dart` | Use cases |
| `questions_feature/exam_prediction_entity.dart` | `QuestionEntity`, `StatsEntity` domain models |

### Available Filters

`college`, `subject`, `paper_year`, `exam_type`, `question_type` — note
there's no `source` filter in the actual query params today, despite a
plausible expectation there would be.

> **Port inconsistency** — `ExamPredictionRemoteDataSourceImpl` hardcodes
> `http://localhost:8090` as its base URL, calling `POST /generate`,
> `POST /upload-pyq`, `GET /stats`, `GET /questions`. That's a **third**,
> independent, hardcoded port that doesn't match the documented `8000` for
> `backend/pyq/rag` (which owns those exact endpoints) or `8080` for Nova.
> See [Tech Debt](#tech-debt).

## Focus Session

A distraction-free countdown timer for structured study blocks. Grown well
beyond its original scope — now a real Pomodoro engine with a services
layer, not just a presentation-only timer.

### Architecture

`FocusTimerController` (a `ChangeNotifier`) now implements a Pomodoro
focus/break cycle (`pomodoroFocusDuration` = 25 min / `pomodoroBreakDuration`
= 5 min, unless `kTestMode`), phase transitions on tick, wall-clock resync
via `syncWithSystemTime()` for backgrounding, and a `_completionNotified`
guard so `onComplete` fires exactly once. `FocusTimerStatus` is now
`{idle, running, complete}` — there is no `paused` value at all (the old
pause concept was replaced by the focus/break phase system,
`FocusPhase {focus, breakTime}`).

### Flutter Files

| File | Role |
|---|---|
| `controllers/focus_timer_controller.dart` | Pomodoro state machine, countdown ticker, wall-clock resync |
| `presentation/focus_timer_page.dart` | Main timer screen |
| `presentation/focus_setup_page.dart` | Custom duration picker: hero time, preset chips, slider, session card |
| `widgets/focus_background.dart` | Custom painter background |
| `widgets/analog_clock_painter.dart` | Analog clock face |
| `widgets/glow_thumb_shape.dart` | Custom `SliderComponentShape` with glow halo |
| `widgets/present_chip.dart` | Animated preset-selection chip |
| `widgets/phase_takeover.dart` | Full-screen phase-transition takeover |
| `widgets/focus_tutorial_overlay.dart`, `focus_tutorial_sheet.dart`, `focus_tutorial_callout.dart` | First-run tutorial |
| `data/models/focus_present.dart` | `FocusPreset` value type |
| `services/focus_haptic_service.dart` | Haptic feedback |
| `services/focus_notification_service.dart` | Local notifications |
| `services/focus_pip_service.dart` | Picture-in-picture |
| `services/focus_preferences_service.dart` | Persisted preferences |
| `services/focus_sound_service.dart` | Sound cues |
| `services/focus_wakelock_service.dart` | Screen wakelock (incl. AMOLED-mode screen-timeout fix) |

Previously documented issues here — a duplicate controller file in
`widgets/` vs `controllers/`, a no-op `resume()`, an unset
`FocusTimerStatus.paused` — no longer apply; that whole subsystem was
rebuilt. Session-history/streak persistence readiness wasn't re-verified as
part of this pass despite `focus_preferences_service.dart` now existing —
check it directly before assuming it covers that.

## Community Feed

Surfaces AI-generated tests created by students, backed by a live query
against `published_tests`.

### How a Test Gets Published

```
Student generates a written practice test (Quiz / Midsem / Compre B) with persist: true
        ↓
Backend saves questions to Supabase and inserts a row into published_tests
        ↓
published_tests row contains: subject, college, exam_type, question_ids[], published_by
        ↓
Community feed shows the test with subject, question count, upvotes, attempts
        ↓
Attempt button calls loadExistingTest(questionIds, examType) on MockTestNotifier
```

Compre Part A (MCQ Blitz) tests are not currently published or displayed in
the feed — see [Tech Debt](#tech-debt).

### Vote Persistence

Upvote/downvote persisted to Supabase via `post_votes`, with optimistic UI
updates on the client.

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

## Subjects and Handout Upload

Students view enrolled subjects for the current semester and upload a course
handout PDF per subject, which triggers background AI study plan
generation.

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
_triggerPlanExtraction() → Edge Function extract-plan-proxy →
study plan generated and saved to study_plans
```

See [BACKEND.md](BACKEND.md#study-plan-generation) for what actually runs
the extraction. Storage bucket/RLS: [DATABASE.md](DATABASE.md#supabase-storage).

### Flutter Files

| File | Role |
|---|---|
| `data/datasources/subjects_datasource.dart` | `uploadHandout`, `_triggerPlanExtraction` |
| `data/repository_impl/subjects_repository_impl.dart` | Wraps `uploadHandout` in `Either<Failure, SubjectEntity>` |
| `presentation/pages/subjects_pages.dart` | `_SubjectsNotifier.uploadHandout`, `_HandoutChip`, `_pickAndUploadHandout` |

### `_HandoutChip` States

| State | Appearance |
|---|---|
| No handout | "Upload handout" with upload icon, dimmed border |
| Uploading | Spinner + "Generating plan…" text |
| Handout uploaded | Filename + ↺ icon, primary color border |

## Profile

A real, Supabase-backed screen — read-only, with no separate profile-edit
form. Editing re-enters onboarding, which writes through
`save_onboarding_seed_context` (see [NOVA.md](NOVA.md#onboarding-seed-context))
with a partial payload.

### Cards

| Card | Data source |
|---|---|
| User header — avatar, name, plan badge, roll number, campus | `userProvider` (`users` table); avatar rendered from `avatar_data` SVG via `flutter_svg`, falls back to a text initial |
| Academic details — branch, dual branch, academic year, current semester | `userProvider` |
| Study strategy — study pace + weekly hour range, endgame goal, prep style | `profileDetailsProvider` — `standing_flags` (endgame) + `nova_history` (prep style), both filtered to `source = 'onboarding'` |
| Career interests | `profileDetailsProvider` — `career_units` filtered to `source = 'onboarding'` |
| Account & actions — email, "Update Profile & Preferences" (routes to onboarding), sign out | `userProvider` |

### `profileDetailsProvider`

A `FutureProvider` in `lib/features/profile/presentation/providers/profile_provider.dart`
that queries `standing_flags`, `career_units`, and `nova_history` directly,
each scoped to the current `auth.uid()` and `source = 'onboarding'`. Each
query is wrapped in its own try/catch — a failure in one doesn't blank out
the other two.

### Flutter Files

| File | Role |
|---|---|
| `presentation/pages/profile_page.dart` | Full UI — five staggered-entrance cards, pull-to-refresh, sign-out confirmation dialog |
| `presentation/providers/profile_provider.dart` | `ProfileDetails`, `profileDetailsProvider` |

## Dashboard

> **This section replaces the old `assets/data/analytics.json` /
> `AnalyticsLocalDataSourceImpl` description** — that whole pipeline no
> longer exists in the codebase. The dashboard was rebuilt.

Current structure (`lib/features/dashboard/`): a full Clean Architecture
stack (`data/`, `domain/`, `presentation/`) with two `DashboardDataSource`
implementations:

- **`DashboardDummyDataSource`** — what actually runs today. In-memory fake
  data: a deterministic 30-day task-completion pattern, an empty task list
  (deliberately empty, not fake placeholder tasks — it drives the
  `expandable_progress_card.dart` "Today's Tasks" empty-state Lottie
  animation), and 6 hardcoded development-radar axes (Technical Depth,
  Communication, Leadership, Research Aptitude, Problem Solving, Domain
  Breadth). No Supabase, no HTTP, no JSON file.
- **`DashboardRemoteDataSource`** — every method `throw UnimplementedError()`.
  Code comment: *"TODO: swap for a real client hitting `POST /reasoning/{user_id}/run`
  once Nova is wired up. Kept as the documented future seam — not
  implemented."* This is the intended real data source once Nova's
  reasoning endpoint has auth (see [NOVA.md](NOVA.md#auth--the-real-gap)).

### Flutter Files

| File | Role |
|---|---|
| `data/datasources/dashboard_datasource.dart` | `DashboardDataSource` interface, `DashboardDummyDataSource`, `DashboardRemoteDataSource` (stub) |
| `data/dtos/dashboard_dto.dart` | `ProgressStatsDto`, `DashboardPlanDto`, `DevelopmentAxisDto`, `DashboardTaskDto` |
| `data/repository_impl/dashboard_repository_impl.dart` | Wraps datasource in `Either<Failure, T>` |
| `domain/{entities,repositories,usecases}/` | Standard Clean Architecture layers |
| `presentation/pages/dashboard_page.dart`, `dashboard_pages.dart` | Main screen |
| `presentation/providers/dashboard_provider.dart` | `DashboardNotifier` |
| `presentation/widgets/` | `cg_pull_card`, `development_radar_chart`, `donut_progress_chart`, `weekly_bar_chart`, `streak_strip`, `expandable_progress_card`, `task_list_tile`, and more |

## Math Game

New, undocumented-until-now feature. Flat structure, no Clean Architecture
layers, no backend calls.

A 60-second arithmetic speed drill. Player types digit answers on a custom
numeric keypad (`math_keypad.dart`); `_maybeAutoAdvance()` checks input
against the current question's answer on every keystroke — there's no
submit button, a correct answer auto-advances immediately. Scoring: `100`
base + a speed bonus (`(50 - elapsedSeconds*12).clamp(0, 50)`) + a streak
bonus (`streak * 15`); tracks current/highest streak and total
answered/correct. Physical keyboard input is also supported (digits,
backspace, escape opens a quit-confirm dialog).

Best score persists locally via `SharedPreferences`
(`MathGameHighScoreService`, key `math_game_best_score`) — no Supabase, no
backend involvement anywhere in this feature.

### Flutter Files

| File | Role |
|---|---|
| `logic/question_generator.dart` | Generates arithmetic questions |
| `models/math_question.dart` | Question model |
| `presentation/pages/math_game_page.dart` | Main game screen, keystroke-driven auto-advance |
| `presentation/widgets/math_keypad.dart` | Custom numeric keypad |
| `presentation/widgets/math_grid_painter.dart` | Background grid painter |
| `presentation/widgets/math_game_stats_bar.dart` | Live score/streak/timer bar |
| `presentation/widgets/math_game_results_view.dart` | Game-over screen: play-again/exit |
| `presentation/widgets/cg_pull_intro_overlay.dart` | Intro overlay |
| `services/math_game_high_score_service.dart` | `SharedPreferences`-backed best-score persistence |

## Authentication

`lib/features/auth/` supports more than the magic-link description this
section used to carry: `AuthDataSource` implements `sendMagicLink`
(`signInWithOtp`), **plus** `signInWithPassword`, `signUpWithPassword`,
`sendPasswordReset`, and `signInWithGoogle` (OAuth) — full email+password
auth exists alongside magic link, not instead of it. `fetchEmailPatterns`
still queries `institutions.email_patterns` for college-email validation, so
the college-scoping claim holds regardless of which auth method is used.

The feature also carries a substantial UI surface not previously
documented: `auth_preview_page.dart` plus a `presentation/widgets/preview/`
subfolder (`auth_mode.dart`, `auth_mode_toggle.dart`, `auth_preview_sheet.dart`,
`drifting_circles.dart`, `preview_text_field.dart`, `rocket_carryover.dart`,
`skolar_wordmark.dart`), and an animated mascot (`nova_mascot.dart`,
`mascot_state.dart` — the latter is shared with `nova_chat_provider.dart`
too, not auth-exclusive).

**No request anywhere in the app attaches a Supabase session token to an
outgoing HTTP call.** `DioHttpClient`'s `AuthInterceptor`/`setBearerToken()`
exist but are never invoked by any feature — this matters most for
[NOVA.md's auth gap](NOVA.md#auth--the-real-gap), since fixing Nova's
backend auth requires this to change too.

## Tech Debt

- **Compre Part A (MCQ Blitz) — not published or loadable from feed.**
  `/generate-batch` results don't reach `published_tests` today even with
  `persist: true` wired through the batch endpoint the same way open
  questions are — `loadExistingTest` has no MCQ Blitz path, and the feed's
  Attempt button always routes to written practice regardless of
  `examType`.
- **Study plan display UI — not yet built.** `study_plans` rows are
  generated and persisted; no Flutter page displays them yet.
- **Onboarding subject selection — not wired to DB.** The subject-selection
  step's UI exists but doesn't fetch real subjects from the `subjects`
  table.
- **`exam_prediction_with_bank` hardcodes `localhost:8090`.** A third,
  inconsistent backend port — reconcile with the documented `8000` for
  `backend/pyq/rag`, which owns the endpoints this datasource calls.
- **`dartz` vs `fpdart` — `CONTRIBUTING.md` doesn't match the codebase.**
  `CONTRIBUTING.md`'s architecture guidelines still mandate `fpdart` and
  explicitly say not to introduce `dartz`; the app depends on `dartz`
  (confirmed still true in `pubspec.yaml`) and that's what every layer
  actually uses. Either correct the doc or migrate — low priority
  functionally, but a new contributor following `CONTRIBUTING.md` literally
  imports a package the codebase doesn't use.
- **Profile — unused Clean Architecture scaffold.** `lib/features/profile/domain/`
  and `lib/features/profile/data/` (~10 files) exist but are entirely
  unused; `profile_page.dart` only calls `userProvider` and
  `profileDetailsProvider`, both querying Supabase directly from the
  presentation layer. Violates this project's own Clean Architecture rule.
- **No feature attaches an auth bearer token to outgoing requests.**
  `DioHttpClient`'s interceptor exists and is unused everywhere — blocks
  fixing [Nova's auth gap](NOVA.md#auth--the-real-gap) from the client side.

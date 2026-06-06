## Skolar - Complete Architecture Index

###  Completed (Phases 1–3)

#### Core Infrastructure
- [x] Error handling (`core/errors/`) — Failure model, Either type, exception classes
- [x] Network layer (`core/network/`) — Dio HTTP client, interceptors, response wrapper
- [x] Dependency Injection (`core/di/`) — GetIt service locator, Riverpod provider exports
- [x] Configuration (`core/config/`) — AppConfig, AppConstants
- [x] Theme (`core/theme/`) — Material 3, color palette, typography, animated + static mesh themes
- [x] Routing (`core/routing/`) — GoRouter, named routes
- [x] Services (`core/services/`) — `activity_log_service.dart` stub (replaced `services.dart`)
- [x] Storage (`core/storage/`) — Storage service abstraction
- [x] Widgets (`core/widgets/`) — GlassBackground, AnimatedProfileGradient

#### AI Backend (`core/ai/rag_llms/`)
- [x] `main.py` — FastAPI app, 7 endpoints, deployed on Railway
- [x] `pipeline.py` — DICL pipeline: PDF parsing, embedding, MMR, generation, Supabase I/O
- [x] Supabase integration — PostgreSQL + pgvector (replaces question_bank.json + embeddings.npy)
- [x] PDF parsing — pdfplumber → raw text extraction
- [x] Question extraction — Groq LLaMA 3.3 70B → structured questions with marks, type, paper_year
- [x] Semantic embeddings — sentence-transformers all-MiniLM-L6-v2 → vector(384)
- [x] MMR algorithm — diverse example selection (alpha=0.7)
- [x] Exam type filtering — quiz / midsem / compre scoping with graceful fallback
- [x] MCQ generation — 4 options + correct index
- [x] Open question generation — with marks-calibrated structured model answers
- [x] Thread-safe parallel generation — ThreadPoolExecutor (3 workers, Groq free-tier safe)
- [x] Auto-save written practice tests to `published_tests` on generation

#### Supabase Schema
- [x] `questions` table — `options jsonb`, `correct_index smallint` columns added
- [x] `published_tests` table — `id`, `subject`, `college`, `exam_type`, `question_ids[]`, `student_name`, `attempt_count`, `upvotes`, `created_at`
- [x] Dev RLS policies on `questions` and `published_tests`

#### Shared Modules
- [x] Models (`shared/models/`) — Entity base, DTO base, UserModel, pagination, `ExamType` enum
- [x] Extensions (`shared/extensions/`) — String, List, Num
- [x] Components (`shared/components/`) — LoadingButton, AppTextField
- [x] Providers (`shared/providers/`) — userProvider, isLoadingProvider

#### Features

1. **Auth** — scaffold ready — pending Firebase/Supabase Auth integration (Phase 4)
2. **Onboarding** — scaffold ready
3. **Dashboard** — fully implemented
   - Donut ring chart, weekly line chart, task list, recent activity feed
   - Backed by analytics.json via AnalyticsLocalDataSourceImpl
4. **Colleges** — scaffold ready
5. **Subjects** — scaffold ready
6. **Syllabus** — scaffold ready
7. **PYQ Upload** — scaffold ready — app UI pending (Phase 4), API endpoint working
8. **Exam Prediction** — fully implemented
   - Question bank browser, filters by subject/year/exam_type/question_type
   - Full Clean Architecture: datasource → repo → usecase → notifier
9. **Analytics** — fully implemented (see Dashboard)
10. **Mock Tests** — fully implemented, full Clean Architecture
    - `ExamType` enum in `shared/models/exam_type.dart` — single source of truth
    - Domain: `mock_test_entity.dart` (freezed), `mock_test_repository.dart`, `mock_test_usecases.dart`
    - Data: `mock_test_dto.dart`, `mock_test_datasource.dart`, `mock_test_repository_impl.dart`
    - 4 exam types: Quiz, Midsem, Compre Part A, Compre Part B
    - MCQ Blitz mode + Written Practice mode (flashcard + paper views)
    - Model answers with markdown rendering
    - `loadExistingTest` — reconstruct written practice test from Supabase question IDs
    - Base URL points to Railway (not LAN IP)
11. **Feed** — fully implemented, live from Supabase
    - `FeedRemoteDataSourceImpl` queries `published_tests` table
    - `feed_post_dto.dart` — `fromSupabase` factory, `questionIds`, `examType` fields; `bankIndices` removed
    - `feed_post_entity.dart` — `examType`, `questionIds` added
    - `feed_repository_impl.dart` — uses remote datasource
    - `feed_provider.dart` — college read from `userProvider`
    - `feed_page.dart` — hardcoded college replaced with `userProvider`
    - `feed_post_card.dart` — Attempt button wired to `loadExistingTest`
12. **Focus Session** — fully implemented
    - Countdown timer, wave background, slide-to-start, custom duration picker
    - Presentation-layer only, no backend dependency
13. **Profile** — scaffold ready
14. **Loading Screen** — implemented

---

###  In Progress (Phase 4)

- [ ] College email authentication (Firebase Auth / Supabase Auth)
- [ ] PYQ upload through app UI
- [ ] Vote state persistence → Supabase write on auth
- [ ] Compre Part A (MCQ Blitz) → save to `published_tests` + `loadExistingTest` MCQ path + feed routing

---

###  Planned (Phase 5 — Personalisation)

- [ ] Personal learning goal mode (e.g. DSA every day for 90 days)
- [ ] AI daily question plan
- [ ] Lives and streak system
- [ ] Coin economy: earn 1 coin per completed daily task, spend to protect streaks
- [ ] Daily college-wide brain puzzle (LinkedIn-style, same for all students that day)
- [ ] College leaderboard (ranked by coins, streak, tests attempted)
- [ ] Mock test scores on dashboard
- [ ] Focus session history and streak tracking
- [ ] `academic_year` filter across pipeline + exam prediction (see Tech Debt)

---

###  Planned (Phase 6 — ML Extension)

- [ ] Full DICL: top-15 cosine retrieval → MMR over those 15 → pick 5 (tech debt fix)
- [ ] Fine-tune FLAN-T5 on generated question-answer pairs
- [ ] MMR vs random vs top-k experiment
- [ ] Distractor quality analysis for MCQ options

---

###  Tech Debt

**Compre Part A — not published or loadable from feed**
- `/generate-batch` does not write to `published_tests`
- `options` + `correct_index` not saved by backend on MCQ generation
- `loadExistingTest` has no MCQ Blitz reconstruction path
- Feed Attempt button always routes to written practice regardless of `examType`
- Fix: save options on generation → insert into `published_tests` → reconstruct `McqQuestion` on load → route to MCQ Blitz in feed

**`academic_year` filtering**
- Exists in `questions` table and `UserModel` but unused everywhere
- Missing from `pipeline.py` select, `GET /questions` params, all four layers of exam prediction, and the UI
- Fix before Phase 5 personalisation

**Full DICL pipeline**
- MMR currently runs over entire question bank; should run over top-15 cosine results first

**Focus session minor issues**
- Duplicate controller file in `widgets/` — delete and update imports
- `resume()` is a no-op
- `paused` status defined but never set
- No session persistence — add `StorageService.saveSession()` when Phase 5 lands

---

###  Backlog (Brainstormed — Not Yet Scheduled)

- [ ] Weakness Tracker: flag weak topics after mock test, correlate with real exam marks, weight generation toward gaps ⭐
- [ ] Quick Revision mode: flashcard session over flagged weak areas before compre
- [ ] Clean Subject Discussion Feed: replace college WhatsApp groups, searchable and permanent
- [ ] Peer-to-Peer Doubt Solving: post doubt → batchmates answer → upvote → earn coins
- [ ] User Growth Card / Resume Export: one-tap shareable card with Skolar branding
- [ ] B2B Professor Portal: web UI over /upload-pyq → institutional licensing model

---

###  File Count

- Core infrastructure: ~15 files
- Shared modules: ~7 files (added `exam_type.dart`)
- Feature implementations: ~190+ files (mock tests clean arch: +7 new, feed remote datasource: +1)
- AI backend: 2 files (main.py, pipeline.py)
- Documentation: README.md, ARCHITECTURE.md, CONTRIBUTING.md, NOTES.md, INDEX.md

---

###  Quick Start

```bash
# Flutter app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run

# Python backend (local)
cd lib/core/ai/rag_llms
source myenv311/bin/activate
uvicorn main:app --reload --port 8000

# Backend is also deployed on Railway — see _kBaseUrl in mock_tests_provider.dart
```

---

*Skolar — Built by Krishna, BITS Pilani Hyderabad, B.Tech CSE 2024–2028*
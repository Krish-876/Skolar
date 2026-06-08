## Skolar - Complete Architecture Index

---

### ✅ Completed (Phases 1–4)

#### Core Infrastructure
- [x] Error handling (`core/errors/`) — Failure model, Either type, exception classes
- [x] Network layer (`core/network/`) — Dio HTTP client, interceptors, response wrapper
- [x] Dependency Injection (`core/di/`) — GetIt service locator, Riverpod provider exports
- [x] Configuration (`core/config/`) — AppConfig, AppConstants
- [x] Theme (`core/theme/`) — Material 3, color palette, typography, animated + static mesh themes
- [x] Routing (`core/routing/`) — GoRouter, auth guard redirect, named routes, `context.push()`
- [x] Services (`core/services/`) — `activity_log_service.dart` stub (replaced `services.dart`)
- [x] Storage (`core/storage/`) — Storage service abstraction
- [x] Widgets (`core/widgets/`) — GlassBackground, AnimatedProfileGradient
- [x] Utils (`core/utils/`) — `EmailParser` — parses BITS email → `roll_number`, `academic_year`, `subdomain`

#### AI Backend (`core/ai/rag_llms/`)
- [x] `main.py` — FastAPI app, 7 endpoints, deployed on Railway
- [x] `pipeline.py` — DICL pipeline: PDF parsing, embedding, MMR, generation, Supabase I/O
- [x] `evaluate.py` — Pipeline evaluation: accuracy and diversity scoring
- [x] Supabase integration — PostgreSQL + pgvector
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
- [x] `institutions` table — id, name, short_name, email_patterns, website, created_at
- [x] `campuses` table — id, institution_id, name, short_name, subdomain, location, created_at
- [x] `users` table — id, email, full_name, roll_number, college, institution_id, campus_id, academic_year, avatar_url, branch, plan, created_at, updated_at
- [x] `subjects` table — id, institution_id, name, short_name, academic_year, created_at
- [x] `user_subjects` table — user_id, subject_id, semester, composite primary key
- [x] `questions` table — id, question_text, marks, question_type, subject, college, paper_year, academic_year, exam_type, embedding, published, published_by, published_at, created_at, options, correct_index
- [x] `published_tests` table — id, published_by, college, subject, exam_type, question_ids[], upvotes, attempts, created_at
- [x] RLS policies on `users` table — insert, update, select scoped to `auth.uid()`
- [x] Dev RLS policies on `questions` and `published_tests`

#### Shared Modules
- [x] Models (`shared/models/`) — Entity base, DTO base, UserModel (with email, campusId, institutionId, placeholder()), pagination, `ExamType` enum
- [x] Extensions (`shared/extensions/`) — String, List, Num
- [x] Components (`shared/components/`) — LoadingButton, AppTextField
- [x] Providers (`shared/providers/`) — userProvider (live Supabase fetch), isLoadingProvider

#### Features

1. **Auth** — fully implemented
   - Magic link via BITS college email (Supabase Auth)
   - `_isNewUser()` routing: new → onboarding, returning → app
   - `authSessionProvider` with `_justLoggedIn` flag (prevents spurious redirects on resume)

2. **Onboarding** — fully implemented (Supabase write)
   - `EmailParser` extracts roll_number, academic_year, subdomain from BITS email
   - Campus resolved from `campuses` table via subdomain
   - Writes to `users` table and `user_subjects` table on completion
   - Subject selection step UI exists — not yet wired to real subjects from DB (see Tech Debt)

3. **Dashboard** — fully implemented
   - Donut ring chart, weekly line chart, task list, recent activity feed
   - Backed by analytics.json via AnalyticsLocalDataSourceImpl

4. **Colleges** — scaffold ready

5. **Subjects** — fully implemented (provider + data layer), no UI screen yet
   - 8 files: entity, DTO, datasource, repository, repository impl, usecase, provider
   - Fetches subjects filtered by `institution_id` and `academic_year`

6. **Syllabus** — scaffold ready

7. **PYQ Upload** — scaffold ready — app UI pending, API endpoint (`/upload-pyq`) working

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
    - Base URL points to Railway

11. **Feed** — fully implemented, live from Supabase
    - `FeedRemoteDataSourceImpl` queries `published_tests` table
    - `feed_post_dto.dart` — `fromSupabase` factory, `questionIds`, `examType` fields
    - `feed_post_entity.dart` — `examType`, `questionIds` fields; `bankIndices` removed
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

### ⬜ Remaining (Phase 4)

- [ ] PYQ upload through app UI
- [ ] Vote state persistence → Supabase write
- [ ] Compre Part A (MCQ Blitz) → published_tests + loadExistingTest MCQ path + feed routing (deferred to post-Phase 5)

---

### 🔲 Planned (Phase 5 — Personalisation)

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

### 🔲 Planned (Phase 6 — ML Extension)

- [ ] Full DICL: top-15 cosine retrieval → MMR over those 15 → pick 5 (tech debt fix)
- [ ] Fine-tune FLAN-T5 on generated question-answer pairs
- [ ] MMR vs random vs top-k experiment
- [ ] Distractor quality analysis for MCQ options

---

### ⚠️ Tech Debt

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

**Onboarding subject selection — not wired to DB**
- Subject selection step shows UI but does not fetch from `subjects` table
- Subjects provider and datasource are complete — this is a wiring task only
- Fix before real user onboarding goes live

**Full DICL pipeline**
- MMR currently runs over entire question bank; should run over top-15 cosine results first
- Fix in Phase 6 — requires 100+ questions per subject before improvement is measurable

**Focus session minor issues**
- Duplicate controller file in `widgets/` — delete and update imports
- `resume()` is a no-op
- `paused` status defined but never set
- No session persistence — add `StorageService.saveSession()` when Phase 5 lands

**Eval scores not meaningful yet**
- Current bank: 33 questions, 1 subject (BPHC / AI)
- Scores reflect data sparsity, not pipeline quality
- Re-run eval when bank reaches 100+ questions per subject

---

### 📋 Backlog (Brainstormed — Not Yet Scheduled)

- [ ] Weakness Tracker: flag weak topics after mock test, correlate with real exam marks, weight generation toward gaps ⭐
- [ ] Quick Revision mode: flashcard session over flagged weak areas before compre
- [ ] Clean Subject Discussion Feed: replace college WhatsApp groups, searchable and permanent
- [ ] Peer-to-Peer Doubt Solving: post doubt → batchmates answer → upvote → earn coins
- [ ] User Growth Card / Resume Export: one-tap shareable card with Skolar branding
- [ ] B2B Professor Portal: web UI over /upload-pyq → institutional licensing model
- [ ] Live Study Rooms: up to 5 students attempt same AI paper in real time

---

### 📁 File Count

- Core infrastructure: ~16 files (added email_parser.dart)
- Shared modules: ~7 files
- Feature implementations: ~200+ files
- AI backend: 3 files (main.py, pipeline.py, evaluate.py)
- Documentation: README.md, INDEX.md, ARCHITECTURE.md, CONTRIBUTING.md, NOTES.md

---

### ⚡ Quick Start

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
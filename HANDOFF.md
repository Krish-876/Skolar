# Skolar Handoff

Generated 2026-10-03 from a **read-only** audit of `D:\Projects\Skolar`. This file is untracked and was deliberately not committed.

Every claim is tagged **VERIFIED** (read in code, a migration, or command output), **INFERRED** (deduced from code), or **UNKNOWN**. Paths are repo-relative. No secrets, keys, emails, or user IDs appear here; env vars are named only.

> Docs in the repo (`README.md`, `NOVA.md`, `BACKEND.md`, `FLUTTER.md`, `DATABASE.md`) are mostly accurate but have stale spots. These are called out inline as **DOC-DRIFT**.

---

## 13. Quick-start for the next agent (read this first)

Skolar has three parts:

- A Flutter app (`lib/`).
- Three independent FastAPI services under `backend/`:
  - `pyq/rag` on :8000, which does question generation.
  - `nova` on :8080, which runs the AI mentor (chat, facts, reasoning, proposals, subjects).
  - `app` on :8001, which does the Nova trigger-check.
- One Supabase project (`supabase/migrations/`).

`backend/bench/` plus `paper/` is a separate research track (Diverse-ICL / MMR example selection).

**Read in this order:**

1. This file: §5 (Nova), §10 (bugs), §11 (next steps).
2. `spec.md`, the Nova design source of truth.
3. `CONTRIBUTING.md`: PR title regex, squash-merge, migrations via the CLI only.
4. `supabase/migrations/` in timestamp order.
5. `backend/nova/api/routers/*.py`, then `backend/nova/services/*.py`.
6. `lib/core/routing/app_routes.dart`, then the feature you're touching.
7. `DASHBOARD_TIME_AUDIT.md` before any dashboard work.

**Do not touch:**

- Never run `supabase db push`. Migrations go straight to production; there is no preview DB (`.github/PULL_REQUEST_TEMPLATE.md`).
- Never edit an existing migration file.
- Never commit `.env` (it holds a **secret-type** Supabase key plus LLM keys) or anything in `backend/bench/.cache/` or `backend/bench/results/raw/`.
- Never run `RUN_NOVA_E2E=1` tests, `backend/tests/test_rls.py`, or `backend/tests/test_subject_match_log_rls.py` without explicit owner approval. They make real writes and billed Groq calls.
- Don't run bench sweeps without `--estimate` first.

**Biggest landmines:**

- The Nova API is mostly unauthenticated and does IDOR by path `user_id` (§5.6).
- `nova_why_log` inserts always fail (§10 #2).
- Confirming a `situation_flag` proposal will fail (§10 #3).
- `.env` (with the secret key) is bundled into the Flutter app (§10 #1).

---

## 1. Project overview

Skolar is a college exam-prep app for BITS Pilani (VERIFIED from its README and the onboarding RPC's campus mapping). It has:

- mock tests generated from the college's own past papers (PYQs) using Diverse In-Context Learning (DICL)
- a question-bank browser and "exam prediction"
- a Pomodoro focus timer
- a community feed of published tests
- subject and handout management
- a mental-math game
- a dashboard
- **Nova**, an LLM "mentor" that reasons over a per-student facts snapshot to produce study plans and chat

| Component | Path | What it is | Status |
|---|---|---|---|
| Flutter app | `lib/` | Riverpod + GoRouter + Clean Architecture (partially), Supabase Auth | VERIFIED |
| pyq/rag service | `backend/pyq/rag/` | FastAPI :8000, PDF ingest, embeddings (`all-MiniLM-L6-v2`), top-k retrieval → MMR → Groq generation | VERIFIED |
| Nova API | `backend/nova/api/` | FastAPI :8080: chat, facts, reasoning, proposals, subjects, health | VERIFIED |
| Nova trigger-check | `backend/app/` | FastAPI :8001, `POST /nova/trigger/check` → RPC `get_nova_triggers` | VERIFIED |
| Nova CLI | `backend/nova/__main__.py` | `python -m nova <user_id>` REPL with a Realtime listener | VERIFIED (has a crash bug, §10) |
| bench | `backend/bench/` | ICL example-selection measurement harness (SST2/COLA/RTE/TREC) | VERIFIED |
| paper | `paper/` | Write-up of the DICL model-substitution study | VERIFIED |
| Supabase | `supabase/migrations/` | Postgres, RLS, RPCs, Storage (`handouts`), Edge Function `extract-plan-proxy` (source not in repo) | VERIFIED / UNKNOWN (function) |

```
                         ┌───────────────────────────── Flutter app (lib/) ─────────────────────────────┐
                         │ auth / onboarding / subjects / feed / profile ──supabase_flutter (anon key)──┼──┐
                         │ nova_chat ──Dio, NO bearer──► http://localhost:8080                          │  │
                         │ mock_tests, exam_prediction ──http──► http://localhost:8090  (port mismatch!) │  │
                         │ subjects ──functions.invoke('extract-plan-proxy')─────────────────────────────┼──┤
                         │ dashboard ──► DashboardDummyDataSource (no I/O)                              │  │
                         └──────────────────────────────────────────────────────────────────────────────┘  │
                                                                                                           ▼
 ┌─────────── backend/ (each loads repo-root .env; SUPABASE_KEY is a secret-type key → bypasses RLS) ──┐  ┌──────────────┐
 │ nova/api  :8080  chat·facts·reasoning·proposals (no auth) · subjects (bearer) ──► Groq (+Cerebras/   │─►│  Supabase    │
 │                   OpenRouter shadow)                                                                 │  │  Postgres+RLS│
 │ app       :8001  /nova/trigger/check (bearer) ──rpc get_nova_triggers─────────────────────────────── │─►│  Auth        │
 │ pyq/rag   :8000  /generate* /upload-pyq /questions /stats (no auth, CORS *) ──► Groq, SBERT          │─►│  Storage     │
 │ bench/           offline harness, imports pyq.rag.core.{retrieval,mmr,features} ──► Groq              │  │  Edge Fn     │
 └────────────────────────────────────────────────────────────────────────────────────────────────────┘  └──────────────┘
```

---

## 2. Repo and git state

### 2.1 Working tree (VERIFIED, `git status`)

- Branch: `master` @ `cadc0a7`, even with `origin/master`. **Clean** (no modified or untracked tracked-path files).
- Stash: one entry, `stash@{0}: On feat/paper-download-script: wip: file reorg into Diverse ICL`.
- Worktrees:
  - `D:/Projects/Skolar/.claude/worktrees/dreamy-beaming-peacock` on branch `worktree-dreamy-beaming-peacock` (fully merged).
  - `D:/Projects/Skolar-tasks-schema` on branch `feat/dashboard-activity-log`.
- Notable ignored local artifacts:
  - `.env`: var names `GROQ_API_KEY`, `GROQ_API_KEY_2`, `SUPABASE_URL`, `SUPABASE_KEY`, `OPENROUTER_API_KEY`, `CEREBRAS_API_KEY`.
  - `backend/venv` (Python 3.14.2).
  - `backend/bench/.cache/` (2,412 cached Groq responses plus `.npy` embeddings).
  - `backend/bench/results/raw/` (12 result files).
  - `CLAUDE-SECURITY-20260820-094118/` (prior security scan output).
  - Many `android/hs_err_pid*.log` and `*.hprof` JVM crash dumps.
- Tracked oddities:
  - `supabase/.temp/*` is committed (project ref, pooler URL; issue #59).
  - `.gitignore` line 1 is a literal `@"`, a PowerShell here-string artifact. Harmless, but sloppy.
  - `.github/workflows/ci.yml` and `backend/tests/test_rls.py` start with a UTF-8 BOM.

### 2.2 Branches

"Ahead/behind" is relative to `master` (`git rev-list --left-right --count master...<b>`). Because PRs are **squash-merged**, "unmerged by ancestry" does not mean the work is unmerged. The PR state column is authoritative.

| Branch | Last commit | Behind/Ahead | PR / state | Purpose (one line) |
|---|---|---|---|---|
| `docs/dicl-report` (local) | 2026-10-03 | 0/3 | #114 merged | DICL paper notes. **Tree identical to master**, safe to delete |
| `origin/docs/dicl-report` | 2026-10-03 | 1/2 | #114 merged | same |
| `fix/bench-select-rename` (+origin) | 2026-09-10 | 2/1 | #110 merged | rename `bench/select.py` → `selection.py` |
| `docs/add-nova-audits` (+origin) | 2026-09-09 | 4/1 | #109 merged | added `backend/nova/{MODEL_TIERS_AUDIT,UI_INTEGRATION_PREREQS}.md`, **later deleted by #107's squash** (§10 #13) |
| `origin/feat/ai-subject-matching` | 2026-09-09 | 3/12 | #107 merged | AI subject matching |
| `origin/feat/nova-proposals` | 2026-09-09 | 5/8 | #105 merged | proposal confirmation gate |
| `fix/ci-lint-job-disk-space` (+origin) | 2026-09-09 | 6/2 | #108 merged | slim python-lint deps |
| `feature/auto-advance-ui-refresh` (+origin) | 2026-09-05 | 7/1 | #106 merged | math game results/services |
| `feat/dashboard-tasks-schema` (+origin) | 2026-09-03 | 9/6 | **#98 OPEN** | `activity_log` migration + RLS test |
| `feat/dashboard-activity-log` (local, worktree) | 2026-09-02 | 25/1 | none | older single-commit variant of #98 (stale duplicate) |
| `fix/issue-57-rpc-user-id-hardening` (+origin) | 2026-09-03 | 10/6 (origin 9/7) | **#91 OPEN** | `auth.uid()` checks in `handle_vote` / `get_nova_triggers` |
| `fix/issue-63-nova-untrusted-chat-prompt-separation` (+origin) | 2026-09-03 | 10/3 | **#93 OPEN** | prompt isolation in `chat_service.py` |
| `origin/fix/issue-51-rls-review-nova-auth` | 2026-09-03 | 9/3 | **#90 OPEN, CHANGES_REQUESTED** | CLI auth, seed test users, CI pytest |
| `origin/fix/issue-60-rag-service-auth` | 2026-08-28 | 44/3 | **#72 CLOSED, not merged** (2026-08-28) | auth for pyq/rag routes (stale, 44 behind); useful reference for issue #60 |
| `origin/feat/focus-spotlight-implementation` | 2026-09-03 | 10/3 | #101 merged | focus spotlight/spacing |
| `feat/focus-timer-theme-match` (+origin) | 2026-09-03 | 14/0 | #99 merged | fully merged |
| `feat/dashboard-cg-pull-card` | 2026-09-03 | 16/5 | #97 merged | CG pull card |
| `origin/Nova_Endpoints` | 2026-09-02 | 25/4 | #83 merged (+4 later commits) | Nova FastAPI endpoints; extra commits = tiktoken compression tiers (INFERRED already on master: `_compress_snapshot` exists in `reasoning_service.py`) |
| `docs/ONBOARDING-DICL` | 2026-09-01 | 30/1 | #94 merged | pyq ONBOARDING.md |
| `feat/onboarding-ui-polish` | 2026-09-01 | 29/0 | #92 merged | fully merged |
| `feat/dashboard-ui-preview`, `backup/dashboard-ui-preview` | 2026-08-30/31 | 33/3, 34/1 | #87 merged | dashboard preview / backup |
| `fix/expand-card-first-frame-delay` (+origin) | 2026-08-31 | 33/4 | none found | expand-card first-frame fix (stale) |
| `worktree-dreamy-beaming-peacock` | 2026-08-30 | 34/0 | merged | worktree branch |
| `feat/focus-overhaul`, `feat/onboarding-screen` | 2026-08-29/30 | 39/4, 38/3 | #84 / #80 merged | |
| `fix/feed-and-mock-test-wiring` | 2026-08-29 | 39/1 | #79 merged | |
| `fix/groq-model-deprecation` | 2026-08-28 | 41/1 | merged (INFERRED; model now `openai/gpt-oss-120b`) | |
| `feat/bench-harness` | 2026-08-28 | 42/1 | merged (INFERRED; bench/ exists) | |
| `ci/semgrep` | 2026-08-28 | 45/1 | none | adds semgrep CI job + `.semgrep/rules.yml`. **Not on master** |
| `fix/rls-test-payload-constraints`, `test/rls-isolation-suite`, `origin/test/rls-data-isolation` | 2026-07-29 – 08-27 | 46–58 behind | merged (INFERRED) | RLS test suite history |
| `feat/paper-download-script`, `docs/README-update`, `profile-page-overhaul` | 2026-07-30 – 08-08 | 55–58 behind | UNKNOWN | stale |
| 4× local `dependabot/*` | 2026-08-02 | 58/1 | remote gone | stale, delete |
| 3× `origin/dependabot/pub/dart-patch-minor-*` | 2026-08-31 – 09-06 | — | closed | stale remote branches |

### 2.3 PRs and issues (`gh` available, v2.97.0)

**Open PRs (VERIFIED, `gh pr view`)**

| # | Title | Checks | Review state / blocking notes |
|---|---|---|---|
| 113 | chore(deps): bump dart-patch-minor (19 updates) | **format, codegen, analyze, test FAIL** | REVIEW_REQUIRED. Dependabot bump breaks the Flutter build |
| 98 | schema: add tasks table with RLS for dashboard progress tracking | python-lint FAIL (reviewer: "ignore the python lint") | REVIEW_REQUIRED. Reviewer found PGRST205 because `activity_log` is not pushed to the shared DB; the author said it resolves after merge + `db push`. **The title says "tasks table" but the content is `activity_log`.** |
| 93 | fix(security): isolate confidential facts and sanitize untrusted chat prompts (#63) | python-lint FAIL | REVIEW_REQUIRED |
| 91 | fix(security): enforce session auth verification in RPC functions (#57) | python-lint FAIL | REVIEW_REQUIRED. **Will break `/nova/trigger/check`**: the new `get_nova_triggers` raises `Not authenticated` when `auth.uid()` is NULL, and `backend/app/main.py:20` calls it with the server key, where `auth.uid()` is NULL (INFERRED, high confidence) |
| 90 | fix(nova): authenticate CLI entrypoint and wire backend test suite (#51) | only "Supabase Preview" reported | **CHANGES_REQUESTED**. `ci.yml` and `backend/requirements.txt` were committed wrapped in PowerShell here-string syntax (`@' ... '@ \| Set-Content`), which breaks YAML and pip |

**Open issues (VERIFIED, `gh issue list`):**

- #64: Supabase URL/key hardcoded in `main.dart`.
- #63: prompt isolation.
- #62: RLS policy debt.
- #61: **rotate leaked secrets, stop bundling `.env`**.
- #60: auth for the rag service. The issue body cites an old path, `lib/core/ai/rag_llms/main.py`; the code now lives at `backend/pyq/rag/main.py`.
- #59: test/dev hygiene.
- #58: `_DevMenu` in production.
- #57: RPCs trusting `p_user_id`.
- #56: solution-sheet upload overwrite.
- #51: backend follow-ups / Nova CLI auth / CI pytest.
- #50: unused profile Clean Architecture scaffold.
- #34: persist onboarding completion.
- #15: Nova CLI follow-ups.

### 2.4 Last ~30 commits on master, by area (VERIFIED, `git log --oneline -40`)

- **Nova backend**:
  - #83 Nova FastAPI endpoints (merge `872444f`).
  - `55f7ad6` CORS + structured plan schema.
  - #105 proposals confirmation gate (`2e6e258`).
  - #107 AI subject matching (`6b55f39`).
  - #109 Nova audit docs (`d30d1c8`), deleted again by #107.
- **bench/DICL**:
  - #89 response cache + sweep runner + report (`89ca1d1`).
  - #110 rename `select.py` (`43a7d6b`).
  - #114 DICL paper notes + `paper/` (`cadc0a7`).
  - #94 pyq ONBOARDING.md (`bdc10eb`).
  - #78 embedding dedup (`fe57552`).
- **Flutter**:
  - Dashboard: #87 dashboard progress card (`ea6d934`), #97 CG pull card.
  - Focus: #84 focus overhaul, #99 analog clock/theme (`b5212dd`), focus tutorial (`2fb07aa`), wakelock fix (`71b6070`), #101 spacing.
  - Auth/onboarding: #88 auth UI + Brevo email verification, #80 / #92 onboarding.
  - Other features: #96 Nova chat window, #86 mock test/feed overhaul, #85 subjects, #103 / #106 math game.
  - Dev routes: #82 dummy auth preview + dev-menu route.
  - #102 "last moment fixes".
- **CI**:
  - #108 lint job installs nova/dev deps only (`3dbf00f`).
- **Fixes**:
  - #79 feed college filter / GoRouter / mock test timeout / lazy scipy.

---

## 3. Conventions and workflow

| Convention | Source | Status |
|---|---|---|
| PR title must match `^(feat\|fix\|schema\|refactor\|test\|docs\|style\|chore\|perf\|ci)(\([a-z0-9_-]+\))?: .+$`, ≤100 chars, no trailing period or space | `.github/workflows/ci.yml` job `pr-title` | VERIFIED |
| Squash-merge every PR into `master`; no develop branch; rebase (not merge) onto master; `--force-with-lease` only | `CONTRIBUTING.md:42-58` | VERIFIED (but many branches show master merged *into* them, e.g. `27a3da0`, `5be0bea`) |
| `branch-up-to-date` CI job fails if master isn't an ancestor | `ci.yml` | VERIFIED |
| Branch naming `feat/…`, `fix/…`, `docs/…`, `fix/issue-NN-…` | observed in branch list; not codified in CONTRIBUTING | INFERRED |
| `dart format --output=none --set-exit-if-changed .` enforced in CI (`format` job) and by `.githooks/pre-push`. The hook must be enabled with `git config core.hooksPath .githooks` (INFERRED; not auto-installed) | `ci.yml`, `.githooks/pre-push` | VERIFIED |
| Codegen must be committed (`build_runner build --delete-conflicting-outputs`, then a clean tree) | `ci.yml` job `codegen` | VERIFIED |
| Migrations only via `npx supabase migration new <name>`; never edit live in the SQL editor | `CONTRIBUTING.md:345-357`, PR template | VERIFIED |
| `supabase db push` is **manual, after merge**; no auto-deploy or preview DB. "Supabase Preview" check = syntax only | PR template, `CONTRIBUTING.md:353` | VERIFIED |
| RLS must be enabled and tested on every new user-owned table (add it to `USER_TABLES_TO_TEST` in `backend/tests/test_rls.py`) | PR template; `test_rls.py:24-30` | VERIFIED |
| Live-test gating: `RUN_NOVA_E2E=1` enables `test_nova_proposals_e2e.py` and `test_career_unit_ilike_regression.py`. `test_rls.py` / `test_subject_match_log_rls.py` run whenever `SUPABASE_URL`/`SUPABASE_KEY` are present (they are, via `load_dotenv`) | test files | VERIFIED |
| Pre-commit: gitleaks + ruff `--select S --fix` + ruff-format | `.pre-commit-config.yaml` | VERIFIED |

### Local setup

| Piece | Command | Env vars (names only) |
|---|---|---|
| Flutter | `flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter run` (Flutter 3.44.0 stable, matching CI) | None read at runtime. Supabase URL/key are **hardcoded** in `lib/main.dart:19-22`. `--dart-define=ENVIRONMENT` is read by `Environment.currentEnvironment()` but Nova chat ignores it (`nova_chat_remote_datasource.dart:55`). The repo-root `.env` is listed as a Flutter asset (`pubspec.yaml` flutter.assets), so it **must exist** for builds (CI creates an empty one). |
| pyq/rag | `cd backend && pip install -r requirements.txt && uvicorn pyq.rag.main:app --reload --port 8000` | `SUPABASE_URL`, `SUPABASE_KEY`, `GROQ_API_KEY`, optional `GROQ_TPM_LIMIT`, `GROQ_COMPLETION_TOKENS_ESTIMATE`, `GROQ_MAX_WORKERS`. `load_dotenv()` runs at import (`backend/pyq/rag/__init__.py:8-10`) |
| Nova API | `cd backend && pip install -r nova/requirements.txt && uvicorn nova.api.main:app --reload --port 8080` (add `--host 0.0.0.0` for a device; NOVA.md suggests `adb reverse`) | `SUPABASE_URL`, `SUPABASE_KEY`, `GROQ_API_KEY`, optional `GROQ_API_KEY_2`, `CEREBRAS_API_KEY`, `OPENROUTER_API_KEY` (`backend/nova/services/clients.py:16-64`) |
| Trigger-check | `cd backend && uvicorn app.main:app --reload --port 8001` | `SUPABASE_URL`, `SUPABASE_KEY` (`backend/app/dependencies.py:10-14`) |
| Nova CLI | `cd backend && python -m nova <user_id>` | as Nova API (**crashes after the first answer**, §10 #6) |
| Backend tests (safe subset) | `cd backend && ./venv/Scripts/python.exe -m pytest tests -q --ignore=tests/test_rls.py --ignore=tests/test_subject_match_log_rls.py` with `RUN_NOVA_E2E` unset | none needed |
| Lint (CI-exact) | from repo root: `ruff check backend/`, `ruff check --select S backend/`, `mypy backend/nova --ignore-missing-imports` | — |
| RLS tests (live, writes) | `pytest backend/tests/test_rls.py` | `SUPABASE_URL`, `SUPABASE_KEY` (**should be a publishable key**, see §8), `TEST_STUDENT_A_EMAIL`, `TEST_STUDENT_A_PASSWORD`, `TEST_STUDENT_B_EMAIL`, `TEST_STUDENT_B_PASSWORD` (the file has hardcoded fallbacks; issue #59) |
| bench | `cd backend && python -m bench.sweep --estimate`, then run | `GROQ_API_KEY` (via `pyq.rag.llm.client.get_groq_client`, `backend/bench/run.py:33,306`) |

---

## 4. Supabase schema

Source: `supabase/migrations/` (13 files). The baseline is a `pg_dump`-style snapshot, `00000000000000_baseline.sql`, which sets `search_path=''` file-wide (line 15).

### 4.1 Tables

The "Writers/Readers" column lists code paths found by grep (VERIFIED unless marked).

| Table | Purpose / key columns | FKs | RLS policies | Indexes | Writers / readers |
|---|---|---|---|---|---|
| `users` | profile: `email, full_name, roll_number, college, institution_id, campus_id, academic_year (1-5), branch, dual_branch, current_semester (1\|2), study_capacity, avatar_data, plan, role (student/admin/super_admin), semester_credits` | `id`→auth (INFERRED) | **duplicate policies**: 3× SELECT-own, 3× UPDATE-own, 2× INSERT-own (baseline 1405-1825) | pk | W: `save_onboarding_seed_context` RPC, Flutter subjects datasource. R: Nova facts, subject_matcher, router `_isNewUser` |
| `institutions`, `campuses` | catalog; `email_patterns jsonb`, `subdomain` | campus→institution | read-all | `idx_campuses_subdomain` | R: onboarding RPC, subjects datasource |
| `subjects` | catalog: `institution_id, campus_id, name, short_name, academic_year, semester, credits` | institution, campus | read-all; **INSERT to any authenticated user** (`subjects_insert_auth WITH CHECK (true)`) | — | R: subject_matcher, Flutter subjects |
| `custom_subjects` | user-added: `institution_id, course_code, name, credits` | institution | read-all-auth; insert-auth `true`; **UPDATE-auth `USING(true) WITH CHECK(true)`**, so any user can edit any row (`20260830163226_…sql`) | — | W: Nova `subject_enrollment.create_custom_subject`, Flutter subjects |
| `user_subjects` | enrollment: `user_id, subject_id XOR custom_subject_id, semester text ("YYYY-S#"), handout_url, handout_filename` | users, subjects, custom_subjects | own (ALL) | unique `(user_id, subject_id) WHERE subject_id NOT NULL` | W: Flutter subjects, Nova `create_user_subject`. R: Nova facts |
| `user_subject_exams` | `user_subject_id, exam_type, exam_date` | user_subjects | own via subquery | — | R: Nova facts, `get_nova_triggers` |
| `topics` | `subject_id XOR custom_subject_id, name` | | **RLS not enabled in any migration** (VERIFIED by grep) | unique ci name per subject | R: Nova facts |
| `user_topic_weights` | `user_id, subject_id XOR custom_subject_id, topic, topic_id, weight 0..1` | | own | `(user_id, subject_id)` | R: Nova facts. W: none found |
| `questions` | PYQ bank + generated: `question_text, marks, question_type, subject, college, embedding vector(384), published, model_answer, answer_source, topic_id, …` | users (published_by, CASCADE) | `questions_read_all` (authenticated), `questions_write_admin`, **plus `"dev read all questions" USING(true)` = unauthenticated read** (issue #62) | ivfflat embedding, college/subject/exam_type | W: pyq/rag (server key). R: Flutter mock tests, rag |
| `published_tests` | feed posts: `college, subject, exam_type, question_ids uuid[], upvotes, downvotes, attempts` | users CASCADE | read-all-auth, campus-scoped read, insert-own ×2, **plus `"dev read all published_tests" USING(true)`** | `(college, created_at)` | W: pyq/rag `save_generated_test`. R: Flutter feed |
| `post_votes` | `user_id, post_id, vote ±1` | | own CRUD | — | W: `handle_vote` RPC |
| `uploaded_pdfs` | upload tracking | users CASCADE | insert-own, read-all-auth | — | W: pyq/rag upload |
| `test_attempts` | `test_id, user_id, subject_id, total_marks, obtained_marks, completed_at, exam_type` | | own | user_id, test_id, subject_id | R: Nova facts, triggers. **W: none found in app code** (README: "schema live, no UI") |
| `question_results` | per-question: `attempt_id, question_id, is_correct, marks_*, error_category (concept_gap/practice_gap/careless), topic_id` | | own via attempt | attempt_id, question_id, `(topic_id, created_at)` | R: Nova facts, triggers. W: none found |
| `ai_evaluations` | photo-answer grading | | own | — | none found |
| `study_plans` | per-subject handout plan: `user_subject_id, subject_name, handout_url, topics jsonb, weekly_plan jsonb, is_active` | | own ALL | unique active per user_subject | W: Edge Fn `extract-plan-proxy` (UNKNOWN source). R: Nova facts |
| `career_units` | `name, description, industry_relevance_text/score/updated_at, confirmed_at, paused_at, source` | users CASCADE | own | unique `(user_id, name) WHERE paused_at IS NULL` | W: onboarding RPC, proposals confirm. R: Nova facts, triggers |
| `standing_flags` | `instruction_text, user_subject_id, career_unit_id, confirmed_at, superseded_at, supersedes_id, source` | users CASCADE | own | — | W: onboarding RPC, proposals confirm |
| `situation_flags` | `flag_text, starts_at, expires_at, user_subject_id, career_unit_id, confirmed_at, superseded_at, supersedes_id`. **No `source` column** | users CASCADE | own | — | W: proposals confirm (**breaks**, §10 #3) |
| `nova_history` | `content, user_subject_id, career_unit_id, confirmed/superseded, source` | users CASCADE | own | — | W: onboarding RPC, proposals confirm |
| `nova_capacity_log` | `capacity (light/normal/packed), logged_for_date` | users CASCADE | own | — | R: Nova facts, triggers. W: none found |
| `staleness_tracker` | `last_meaningfully_touched`, exactly one of user_subject/topic/career_unit | users CASCADE | own | `idx_staleness_user` | R only; **no writer found** |
| `nova_config` | key/value settings; `user_id NULL` = global default. Seeds: `staleness_days_academic=14`, `staleness_days_career=21`, `time_left_buckets=[7,3,1]`, `academic_pressure_buckets=[10,3]` | users CASCADE | select own-or-global, insert/update own | unique `(user_id,key)`, unique global key | W: onboarding RPC (`capacity_hour_mapping`). R: `get_nova_triggers` |
| `nova_why_log` | audit: `entry_type (full_pass/minor_trigger/one_off_override), facts_snapshot, plan_output, reasoning_summary NOT NULL, unit FKs, supersedes_id`. CHECK: full_pass needs a snapshot | users CASCADE | SELECT own only | `(user_id, created_at)`, per-unit indexes | W: reasoning router (**wrong columns, always fails**, §10 #2). R: `get_nova_triggers` |
| `nova_unconfirmed_proposals` | staging for chat-proposed facts: `turn_id, proposal_type, payload, proposed_summary, status, resulting_row_id`, consistency CHECKs | users/user_subjects/career_units CASCADE | SELECT own | `(user_id,status,created_at)`, `turn_id` | W/R: Nova proposals_service |
| `subject_match_log` | AI subject-match misses: `query_text, status, candidates, resolved_*` | users CASCADE, subjects/custom SET NULL | SELECT own | `(institution_id,status,created_at)`, `(user_id,created_at)` | W: subject_matcher, subject_enrollment |
| `_integration_test` | CI smoke table (`20260710102752`) | — | **no RLS** | — | none |
| `activity_log` | **not on master** (PR #98): `user_id, completed_on date, duration_seconds >0` | users CASCADE | SELECT/INSERT own | `(user_id, completed_on) INCLUDE (duration_seconds)` | none yet |

### 4.2 RPC / SQL functions

| Function | Purpose | Security | search_path | Auth check | Status |
|---|---|---|---|---|---|
| `handle_vote(p_post_id, p_user_id, p_vote)` | toggle/switch feed votes, update counters | **SECURITY DEFINER** | **not set on the function** (only the dump's session setting) | **none**: trusts `p_user_id`, so any user can vote as anyone (issue #57); Flutter passes it from the client (`feed_remote_datasource.dart:52-55`) | VERIFIED |
| `set_updated_at()` | trigger | invoker | — | — | VERIFIED |
| `get_nova_triggers(p_user_id)` | trigger layer: new_test_score, time_left_threshold, error_type_shift, staleness_academic/career, flag_confirmed, industry_relevance_refreshed, capacity_changed, career_unit_new | INVOKER, STABLE | not set | none (trusts `p_user_id`). Safe today only because `backend/app` derives it from a verified bearer token | VERIFIED (latest def in `20260716115056`) |
| `save_onboarding_seed_context(...15 args)` | upsert profile + seed flags/history/career units/capacity mapping; maps campus by email domain/`college` ILIKE (hardcoded BITS Hyderabad/Goa/Pilani, then falls back to the **first campus/institution in the table**) | **SECURITY DEFINER** | `public, pg_temp` | `auth.uid()`, raises if NULL | VERIFIED (`20260830163226`) |
| `save_onboarding_seed_context(...6 args)` | older overload from `20260716115056`. `CREATE OR REPLACE` with a different signature **adds an overload, it doesn't replace**, so both exist (INFERRED) | INVOKER | not set | `auth.uid()` | INFERRED |

### 4.3 Migration push state

I did not run `supabase migration list` this session, because it contacts the remote project. What is known:

- **As of 2026-09-09, from an earlier session's `supabase migration list` output:** every migration through `20260909120000_nova_unconfirmed_proposals` was applied on remote. That session first found the proposals migration missing, and it was pushed before the E2E run.
- `20260909080620_add_subject_match_log` (merged the same day via #107) is **UNKNOWN**. It may not have been in that branch's local list.
- PR #98's `activity_log` is **not** pushed (PR thread).

Run `npx supabase migration list` (read-only) to confirm the current state.

---

## 5. Backend

### 5.1 pyq/rag (VERIFIED)

- **Layout:**
  - `core/`: `features.py` (SBERT `all-MiniLM-L6-v2` backend), `retrieval.py` (`retrieve_top_k`, O(n) Python loop), `mmr.py` (`alpha*rel - (1-alpha)*div`).
  - `ingest/`: `extract.py` (PDF/docx/OCR), `chunking.py`.
  - `llm/`: `client.py` (Groq `openai/gpt-oss-120b`, TPM limiter), `extraction.py`, `generation.py`.
  - `services/`: `generate.py`, `upload.py`.
  - `store/supabase.py`.
  - `pipeline.py`: a re-export shim.
  - `evaluate.py`.
  - `scripts/cleanup_generated_questions.py`.
  - Separately: `backend/pyq/batch_upload.py`.
- **Endpoints** (`backend/pyq/rag/main.py`): `/health`, `/stats`, `/questions`, `/generate`, `/generate-batch`, `/generate-open-batch` (now `persist` defaults to False), `/upload-pyq`. **None have auth; CORS is `*`** (lines 43-48). Issues #60 and #56.
- **Generation path:** load the college/subject bank with embeddings → exclude generated docs → optional exam-type cascade filter → embed `current_topic` or subject → `retrieve_top_k` pool of `max(10k, 50)` → `mmr` to k → Groq (`services/generate.py:164-285`).
- **MMR status:** implemented as the full two-stage top-k-then-MMR.
  - **DOC-DRIFT:** README's roadmap still lists "full top-15→MMR DICL" as planned Phase 6.
- **Hardcoded params:**
  - `alpha=0.7` default in every `run_generate*` (`services/generate.py:246,298,373`). The API routes don't expose it.
  - Pool size is `max(10*k, 50)`. The bench uses `pool_multiplier*k = 3k`, so **bench measures a different pool size than production** (`bench/selection.py:55` vs `services/generate.py:_pool_size_for`).

### 5.2 Nova endpoints (VERIFIED, `backend/nova/api/`)

| Route | Router | Auth | Notes |
|---|---|---|---|
| `GET /health` | health.py | none | always says `supabase=True` if clients construct |
| `GET /chat/{user_id}/suggestions` | chat.py:19 | **none** | LLM call over the facts snapshot |
| `POST /chat/{user_id}` | chat.py:48 | **none** | `ask_nova` → optional proposals staged with a `turn_id` |
| `GET /facts/{user_id}` | facts.py:9 | **none** | returns the **full PII/academic snapshot of any user_id** |
| `POST /reasoning/{user_id}/run` | reasoning.py:15 | **none** | plan + why-log insert (broken) |
| `GET /proposals/{user_id}/pending` | proposals.py:35 | **none** | |
| `POST /proposals/{user_id}/{proposal_id}/confirm` and `/reject` | proposals.py:41,53 | **none** | |
| `POST /proposals/{user_id}/turn/{turn_id}/confirm` and `/reject` | proposals.py:62,72 | **none** | |
| `POST /subjects/{user_id}/add` and `/confirm` | subjects.py:37,81 | **Bearer** (`get_current_user_id`) + 403 if path ≠ token | only authenticated Nova routes |

- `main.py` has a **global exception handler that returns the full Python traceback** to clients (`backend/nova/api/main.py:14-21`).
- CORS is `*` with `allow_credentials=True` (lines 25-31).
- Sessions live in an in-memory dict, so they are single-worker only (`sessions.py`).
- **DOC-DRIFT:** NOVA.md says "no auth on any of its 5 routes". There are 6 router modules, and `subjects` is authenticated.
- **DOC-DRIFT:** README/NOVA.md say AI subject matching is "in review, not merged". It was merged in #107 on 2026-09-09.

### 5.3 Services

- `clients.py`: Groq primary/backup, plus shadow Cerebras/OpenRouter. It has a Realtime listener (CLI only). The **API app never starts Realtime**, so the API's cached snapshots only refresh via `mark_dirty` on proposal confirm.
- `facts_state.py`: per-session snapshot with dirty-table patching.
- `facts_service.py`: about 12 **separate** PostgREST queries per snapshot. Every fetch error is swallowed into `[]`/`{}`, so failures look like an empty student.
- `chat_service.py`: JSON-mode Groq, with backup key on failure. The **facts snapshot goes into the same message list as untrusted user input** (issue #63, PR #93).
- `reasoning_service.py`: tiktoken-counted 3-tier snapshot compression to fit 8000 TPM, Groq primary then `qwen/qwen3.6-27b` backup, Nemotron shadow, then a stale-plan fallback.
- `proposals_service.py`: stage, then confirm/reject. Supersession is resolved at confirm time. It is **not transactional**: insert the new row, *then* update the old row's `superseded_at`.
- `subject_matcher.py` / `subject_enrollment.py`: Groq classification with threshold 0.75, at most 2 disambiguation candidates, a miss log, and institution scoping from the caller's own profile.

### 5.4 Facts schema (`backend/nova/schemas/facts_snapshot.py`)

- **Scalars:** `full_name`, `academic_year`, `branch`, `current_semester`, `dual_branch`, `study_capacity`.
- **Lists:** `user_subjects` (with embedded subject names), `user_subject_exams`, `capacity_today`, `staleness_tracker`, `standing_flags`/`situation_flags`/`nova_history` (confirmed and unsuperseded only), `career_units` (confirmed and unpaused), `question_results` (last 200), `user_topic_weights`, `study_plans` (active), `topics`.

### 5.5 Proposals flow and subject matching

- **Proposals:**
  - Chat JSON may include `proposed_facts` → `create_proposals` inserts rows into `nova_unconfirmed_proposals` with a `turn_id`.
  - The UI shows cards; confirm or reject happens per turn.
  - On confirm: `_confirm_flag_or_history` inserts into the destination table with `source='conversation'`, then supersedes the previous active row for the same unit. `_confirm_career_unit` un-pauses or creates.
  - The session is marked dirty.
- **Subject matching:**
  - `/subjects/{id}/add` either auto-creates `user_subjects` on a confident match, or returns candidates plus a `match_log_id`.
  - `/confirm` validates institution scoping, then creates.
  - **The Flutter app does not call these endpoints.** `lib/features/subjects/data/datasources/subjects_datasource.dart` writes `user_subjects`/`custom_subjects` directly via Supabase (VERIFIED by grep; no `/subjects/` HTTP calls in `lib/`).

### 5.6 Reasoning, trigger layer, and model tiers

- **The trigger layer is SQL only** (`get_nova_triggers`). Its only caller is `backend/app` `/nova/trigger/check`, and **nothing calls that** (no Flutter call, no scheduler) (VERIFIED by grep).
- The reasoning `trigger_type` is chosen by the client (`full_pass` / `minor_trigger_rerank`). The only difference is `reasoning_effort` (high vs medium), and both re-reason over the full snapshot.
- **`model_tiers.yaml` is NOT loaded.** No code reads it (VERIFIED: no yaml import or load in `backend/nova`). Models are hardcoded constants:
  - `chat_service.py:16-19`
  - `reasoning_service.py:23-27`
  - `subject_matcher.py:39`
  - The YAML is documentation only.

### 5.7 Nova vs spec.md

| spec requirement | Status | Evidence |
|---|---|---|
| §2 facts schema (time_left, stakes, performance, error_type, capacity, history, last_touched) | **Partial** | Raw rows exist (exams, question_results.error_category, capacity_log, nova_history, staleness_tracker). `time_left`/`stakes` aren't computed; the LLM derives them. Nothing writes `staleness_tracker`, `user_topic_weights`, `nova_capacity_log`, `test_attempts`, or `question_results` (grep) |
| `academic_pressure` (derived live by the reasoner; trigger on threshold crossing §3) | **Missing** | Not in `FactsSnapshot` or the prompt. `nova_config.academic_pressure_buckets` is seeded but **unused**. `get_nova_triggers` has no academic_pressure branch |
| `industry_relevance` (periodic web lookup, weekly) | **Missing** (schema only) | Columns `career_units.industry_relevance_*` and a trigger branch exist. **Nothing writes them**; no web lookup code |
| §3 trigger layer, daily, no AI | **Partial** | SQL RPC implemented. **No scheduler** (no cron, pg_cron, Edge Fn, or worker in repo) and no caller |
| §4 reasoning, no hardcoded priorities, ranked output with why | **Partial** | `PlanItem{subject, task, priority, reason}`. No time budgets (§1 output), no stability constraint (§4 re-rank only disputed region) |
| §5 conversation feeds facts only after confirmation | **Done** (with bug) | proposals flow. situation_flag confirm broken (§10 #3). One-off override logging missing |
| §6 conversation pass re-pulls facts fresh | **Partial** | `FactsState` uses a cached snapshot plus dirty set. The API has no Realtime, so other writers' changes are missed until session restart |
| §7 why-log full snapshot + plan + summary for every plan change | **Missing (broken)** | Inserts use non-existent columns `triggered_by/snapshot_summary/reasoning_output/passed/failure_reason` (`reasoning.py:39-46,78-85`) vs schema `entry_type/facts_snapshot/plan_output/reasoning_summary NOT NULL`. Every insert fails, and the failure is only logged |
| §9 minor vs major trigger scope | **Missing** | Both trigger types send the whole snapshot. `minor_trigger_rerank` only lowers `reasoning_effort` (`reasoning_service.py:_REASONING_EFFORT`) |
| §9 fetch-then-reason atomic read (pre-launch requirement) | **Missing** | `get_facts_snapshot` does about 12 independent queries, with no single RPC or REPEATABLE READ snapshot (`facts_service.py:262-303`) |
| §10/§11 cold-start conservative mode gated on data volume | **Missing** | No data-volume computation and no alternate prompt shape |
| §6 concurrency (conversation wins, superseded passes logged) | **Missing** | No pass bookkeeping |
| §5 no-expiry on unconfirmed proposals (deferred in spec) | Deferred, as spec says | — |
| Persisting the plan for the app/dashboard | **Missing** | Plan only in memory (`sessions.py`) |

### 5.8 Security summary

- **Unauthenticated + IDOR:** all Nova chat/facts/reasoning/proposals routes (§5.2), and all pyq/rag routes. Every service uses `SUPABASE_KEY`, which in the local `.env` is a **secret-type key** that bypasses RLS (checked by prefix only).
- **Secret exposure:** `.env` is a Flutter asset (`pubspec.yaml` assets list includes `- .env`), so the secret Supabase key and Groq keys are packaged into app builds (issue #61, still open). `flutter_dotenv` is a dependency but unused in `lib/`.
- Tracebacks returned to clients (Nova `main.py:14-21`); exception strings returned in 500s (chat/reasoning routers).
- CORS `*` on Nova and rag.
- RLS debt:
  - `dev read all questions` / `dev read all published_tests` grant `USING(true)`.
  - `custom_subjects` UPDATE is open to any user.
  - `subjects` INSERT is open to any user.
  - `topics` and `_integration_test` have no RLS.
  - Duplicate `users` policies.
- `handle_vote` SECURITY DEFINER with a client-supplied user id (#57).
- `_DevMenu` at `/` is reachable by any signed-in user (`app_routes.dart:115`, issue #58).
- `download_papers.py` SSRF and decompression-bomb items (#59). Not re-verified.

---

## 6. bench/ and the DICL paper

- **Harness (VERIFIED):**
  - `datasets.py`: SST2/COLA/RTE/TREC jsonl loaders.
  - `prompts.py`.
  - `selection.py`: `zero_shot` / `few_shot` (top-k) / `mmr_few_shot` (pool `pool_multiplier*k` → MMR), **importing production `pyq.rag.core`**.
  - `run.py`: one config run with a 30 RPM / 1000 per-day limiter and `DailyCapReached`.
  - `cache.py`: response cache keyed by (model, effort, prompt) under `.cache/responses/`.
  - `sweep.py`: YAML grid with `max_calls` budget and `--estimate`.
  - `score.py`.
  - `report.py`: writes `results/REPORT.md` and `history.jsonl`.
  - `subsample_data.py`.
- **Sweeps:**
  - `sweeps/default.yaml`: sst2, k=4, alpha {0.3, 0.7}, seeds {0, 1}, limit 50, max_calls 300.
  - `sweeps/full.yaml`: 4 datasets, k {2, 4, 8}, alpha {0.3, 0.5, 0.7, 0.9}, seeds {0, 1, 2}, full split, max_calls 5000.
- **Results on disk** (`backend/bench/results/raw/`, gitignored): single seed (0), model `openai/gpt-oss-120b`, `reasoning_effort=none`, sbert.

| dataset | configs | n per config |
|---|---|---|
| cola | zero, few k4, mmr k4 a0.7 | 300 |
| rte | zero, few k7, mmr k7 a0.7 | 277 (full) |
| sst2 | zero, few k4, mmr k4 a0.7 | **20** (smoke test) |
| trec | zero, few k7, mmr k7 a0.7 | 250 / 250 / **234** |

- **Significance:** none. `REPORT.md` says each delta is "not enough evidence … only 1 seed". There is no paired test in code (`paper/04-gaps-and-drawbacks.md` item 5).
- **Integrity issue (VERIFIED):** `trec_mmr_k7_a0.7.jsonl.meta.json` claims `n_samples_written: 250, partial: false`, but the file has **234** lines.
  - `report.py:423` `compute_health` marks configs incomplete only when `meta.partial` is set or `meta.n_samples_written != meta.n_samples_total`. **It trusts the sidecar and never recounts the file**, so `REPORT.md` shows "every config completed | PASS".
  - `run.py` writes the file with `"w"` and writes meta in `finally` from its own counter (`run.py:336-410`).
  - **Root cause, from an earlier Claude Code session (2026-09-12) and not recorded anywhere in git:** two runs of the same config were writing to the same path at once (a retry/sleep loop was re-running commands). That left **8 interleaved, spliced JSON lines** (lines 49, 53, 57, 60, 62, 65, 68, 71) in `trec_mmr_k7_a0.7.jsonl`. With the owner's OK they were **deleted by hand**, taking the file from 242 to 234 lines. `trec_zero_shot.jsonl` also had **one truncated line removed by hand** in the same session.
  - So the raw files were edited after they were written, and the run-level metas no longer describe them.
  - Treat **all of trec** (and anything run in that concurrent window) as needing a clean re-run. `run.py` has no lock against two runs writing the same `--out` path.
  - `paper/04-gaps-and-drawbacks.md` item 8 documents the mismatch but **not the hand edits or the concurrency cause**. It should be updated.
- **paper/** (merged #114): `00-goal-and-scope` … `06-reproducibility`, plus a README dated 2026-09-22, which states that nothing yet answers the central question. `backend/bench/DICL_MAPPING.md` (571 lines) maps DICL onto PYQ generation and proposes topic-coverage post-processing.
  - Paper item 12 notes stale `select.py` references in `bench/README.md` and `pyq/ONBOARDING.md` (DOC-DRIFT).

---

## 7. Flutter app

### 7.1 Features

CA = Clean Architecture (domain/data/presentation).

| Feature | Purpose | CA completeness | Data source | Route |
|---|---|---|---|---|
| auth | magic link / password / Google | full | Supabase Auth (`auth_datasource.dart`) | `/auth` |
| onboarding | welcome video + profile/seed context | full | RPC `save_onboarding_seed_context` | `/onboarding-welcome`, `/onboarding-profile` |
| subjects | enroll subjects, handout upload, plan extraction | full | Supabase tables + Storage `handouts/…` + Edge Fn `extract-plan-proxy` | `/subjects` |
| dashboard | progress ring, streak, chart, tasks, radar, CG card | full | **Dummy** (`DashboardDummyDataSource`); `DashboardRemoteDataSource` throws | `/dashboard` |
| focus_session | Pomodoro timer, PiP, notifications, tutorial | **not CA** (controllers/services/widgets) | local only (SharedPreferences for tutorial flag) | `/focus-session` |
| nova_chat | chat, quizzes, flashcards, plan card, proposal cards | full | Dio → Nova :8080, **no bearer** | `/nova-chat` |
| feed | published tests + votes | full | Supabase `published_tests`, `post_votes`, RPC `handle_vote`; local `assets/data/feed.json` source exists | `/feed` |
| mock_tests | MCQ blitz / written practice | full | Supabase `questions` + HTTP `http://localhost:8090` (`mock_test_datasource.dart:35`) | `/mock-tests` |
| exam_prediction_with_bank | question bank browser | flat folder, layered by filename | HTTP `http://localhost:8090` (`exam_prediction_datasource.dart:42`) | `/exam-prediction` |
| profile | profile page | domain/data **unused scaffold** (issue #50); page queries Supabase from providers | Supabase direct | `/profile` |
| analytics | analytics page | scaffold | `assets/data/analytics.json`; provider file is 1 line | `/analytics` |
| colleges | — | scaffold | datasource returns `[]` / throws (TODO) | `/colleges` |
| pyq_upload | upload UI | mostly 1-line stubs; page reads `subjects` | not wired to `/upload-pyq` (INFERRED) | `/pyq-upload` |
| syllabus | — | **all files 1-line stubs** | none | `/syllabus` → **renders `SplashScreen`** (`app_routes.dart:170`) |
| math_game | mental-math game | logic/models/services | local, SharedPreferences high score | `/math-game` |
| splash screen | splash | single file in a folder **with a space in its name** | — | via `/syllabus` |

**Port mismatch:** `mock_tests` and `exam_prediction` call `:8090`, but pyq/rag documents and runs on `:8000`. FLUTTER.md already flags this (VERIFIED).

### 7.2 Auth flow (VERIFIED unless marked)

- **Magic link:** `signInWithOtp(email, shouldCreateUser: true)` with **no `emailRedirectTo`** (`auth_datasource.dart:25-27`). PKCE flow (`main.dart:23-25`). Android deep link `io.supabase.skolar://login-callback` is registered (`android/app/src/main/AndroidManifest.xml:32-39`). Whether the Supabase dashboard redirect URL matches is UNKNOWN. iOS was not checked.
- **"Is the user new?" is decided by `users.full_name` being empty.** This duplicated logic lives in both `app_routes.dart:48-62` (router redirect) and `auth_pages.dart:296-309` (session listener).
- **Onboarding flash bug (INFERRED cause).** Two independent navigators react to the same auth change:
  1. The GoRouter `redirect` (async DB call, `refreshListenable` on `onAuthStateChange`).
  2. `AuthScreen`'s `ref.listen` → `router.go(...)`.
  
  Also, `initialLocation` is `/onboarding-welcome`, so a signed-in user first lands on a public route and is then redirected after an awaited query. Either path can briefly show the wrong screen. Non-public routes never check `isNew`, so a new user can reach `/dashboard` directly. Completion isn't persisted beyond `full_name` (issue #34).
- **Bearer token: not attached to any backend call.** `DioHttpClient.setBearerToken` exists (`lib/core/network/dio_http_client.dart:62`), but `DioHttpClient` is never constructed (its registration in `service_locator.dart:19` is commented out). Nova chat builds its own `Dio` with no auth header.

### 7.3 Nova chat UI

| Capability | Wired? | Evidence |
|---|---|---|
| send message (`POST /chat`) | yes | provider → `sendMessage` |
| suggestions | yes | `_fetchInitialSuggestions` |
| health | yes | `checkBackendHealth` |
| study plan | yes, via **client-side keyword routing** ("study plan", "what should i study", …) to `/reasoning/run` | `nova_chat_provider.dart:103-121` |
| confirm/reject **whole turn** | yes | `nova_chat_provider.dart:237-243` |
| `GET /facts` | **datasource only, unused by UI** | grep: no presentation call |
| per-proposal confirm/reject, `GET /proposals/pending` | **datasource + repository only, unused** | grep |
| user id | `currentUser?.id`, with a **hardcoded dev placeholder fallback** in the provider (`nova_chat_provider.dart:62`) and **another, different placeholder** in every datasource method (`nova_chat_remote_datasource.dart:72,128,166,181,230,257,276,295,319`) | VERIFIED |
| base URL | `Environment.development.apiBaseUrl` always, regardless of flavor (`nova_chat_remote_datasource.dart:55,60`) | VERIFIED |

### 7.4 Focus session, dashboard, onboarding

- **Focus:** a solid local timer with wall-clock sync, Pomodoro 25/5 (`kTestMode=false`), wakelock, PiP, and notifications. **Nothing is persisted**, and the completion only plays a sound (see `DASHBOARD_TIME_AUDIT.md` §1).
- **Dashboard:** polished UI on dummy data.
  - Semester chart series is fabricated (`weekly_bar_chart.dart:53-56`).
  - Month buckets are 6-day chunks (`:45`).
  - The radar axes are hardcoded dummy labels (`dashboard_datasource.dart` `getDevelopmentAxes`).
- **Onboarding:** a single RPC at the end. If the app crashes mid-flow, the user restarts (#34). Campus/institution are assigned by hardcoded email/college patterns in SQL, with an arbitrary first-row fallback (§4.2).

### 7.5 Hardcoded values

- **Supabase URL and anon key:** `lib/main.dart:19-22`, deprecated `anonKey` param per the analyzer (issue #64).
- **API hosts:**
  - `environment.dart:18` → `http://localhost:8080`; staging/prod are placeholder `.nova.local` hosts.
  - `app_config.dart:30` → `http://127.0.0.1:8080` (unused duplicate config class).
  - `mock_test_datasource.dart:35` and `exam_prediction_datasource.dart:42` → `http://localhost:8090`.
- **Dev user-id fallbacks:** §7.3.
- **Colors outside `lib/core/theme`:** **269** `Color(0x…)` literals, plus heavy `Colors.*` use. Top offenders:
  - `nova_quiz_card.dart` (27)
  - `mock_tests_pages.dart` (22)
  - `nova_practice_problem_card.dart` (20)
  - `streak_card.dart` (19)
  - `focus_timer_page.dart` (46× `Colors.`)
- **Magic numbers:**
  - Collapsed card height `116` (`dashboard_page.dart:28`).
  - Pomodoro 25/5 min (`focus_timer_controller.dart:31-34`).
  - Fallback suggestion strings duplicated in Flutter and Python (`nova_chat_remote_datasource.dart:193-198`, `chat.py:39-44`, `chat_service.py:283-288`).
  - Sunday week-start (`streak_strip.dart:178-182`).
- **Two `routeObserver` globals:** `main.dart:8` and `app_routes.dart:31`; only the latter is used (INFERRED).

---

## 8. CI and tests

### 8.1 CI jobs (`.github/workflows/ci.yml`, VERIFIED)

| Job | Runs when | Checks |
|---|---|---|
| `changes` | always | dorny/paths-filter: `flutter` = `lib/**`, `pubspec.*`; `python` = `backend/**` |
| `gitleaks` | always | full-history secret scan |
| `env-file-check` | always | fails if any `.env` is tracked |
| `format` | flutter changed | `dart format --set-exit-if-changed` |
| `codegen` | flutter changed | build_runner, then a clean tree |
| `analyze` | flutter changed | `dart analyze` (with an empty `.env` placeholder) |
| `test` | flutter changed | `flutter test --coverage` |
| `python-lint` | python changed | `ruff check backend/`, `ruff check --select S`, a grep ban on `api_core.retry.if_transient_error`, `mypy backend/nova --ignore-missing-imports` (Python 3.14) |
| `pr-title` | PRs | regex above |
| `branch-up-to-date` | PRs | master must be an ancestor |

**No pytest job exists in CI.** No backend test runs in CI (VERIFIED; issue #51, PR #90). There's also an external "Supabase Preview" check (GitHub integration, syntax only).

- Current status: master's last merge (#114) passed (INFERRED, since it merged).
- Open PRs: #113 fails the Flutter jobs. #98, #93 and #91 fail `python-lint`. I didn't fetch the logs; possibly the PR branches predate #108's lint-deps fix (INFERRED).

### 8.2 Local runs (read-only, this session)

| Suite | Command | Result |
|---|---|---|
| pytest | `backend/venv` Python 3.14.2, `pytest tests --ignore=tests/test_rls.py --ignore=tests/test_subject_match_log_rls.py`, `RUN_NOVA_E2E` unset | **211 passed, 5 skipped, 0 failed** (105 s). The 5 skips are env-gated (`RUN_NOVA_E2E`). Two live RLS files were deliberately excluded because they write to the real project |
| ruff | `ruff check backend/` | **All checks passed** |
| ruff security | `ruff check --select S backend/` | **All checks passed** |
| mypy | `mypy backend/nova --ignore-missing-imports` | **Success: no issues in 33 files**. Note: `__main__.py:35` body is untyped and unchecked, which hides the CLI bug (§10 #6) |
| dart analyze | `dart analyze` | **0 errors, 0 warnings, 23 infos** (dangling doc comments in stubs, deprecated `anonKey`, deprecated `tolerance`, package name `Skolar` not snake_case) |
| dart format | `dart format --output=none --set-exit-if-changed .` | **0 files changed** |
| flutter test | `flutter test` | **14 passed, 0 failed** across `test/` (3 files: `dashboard_smoke_test.dart`, `widget_test.dart` for focus controller/chips, `math_game_test.dart`) |

### 8.3 Coverage gaps

- `proposals_service.py` confirm/supersede has no unit tests. Only the live E2E (`test_nova_proposals_e2e.py`, **standing_flag only**) covers it, so the situation_flag `source` bug is untested.
- `facts_service.py`, `facts_state.py`, `reasoning_service.py` (compression tiers), and the `reasoning.py` why-log insert: no tests found (grep `backend/tests`).
- `chat`/`facts`/`reasoning`/`proposals` routers: no router tests (only `subjects` and `auth_deps`).
- `backend/app` trigger-check and the `get_nova_triggers` SQL: only a manual seed script, `scripts/test_nova_triggers_seed.sql`.
- RLS suite:
  - It isn't in CI.
  - It silently **skips** if test accounts can't sign in (`test_rls.py:59`). An earlier session (2026-09-09) found that **the default `student_a`/`student_b` test accounts don't exist** in the project, so the cross-student isolation tests have effectively never run. Per that session, `public.users` held only two real people's rows. The E2E test works around this by creating a throwaway auth user via the admin API and deleting it in teardown (cascades verified).
  - It covers 5 tables only.
  - Its "anon" client uses `SUPABASE_KEY`, which locally is a secret-type key, so it gives **false coverage** (issue #62).
  - `activity_log` is only added on PR #98.
  - Tables never isolation-tested: `user_subjects`, `nova_history`, `career_units`, `study_plans`, `test_attempts`, `nova_why_log`, `nova_unconfirmed_proposals`.
- Flutter: no tests for auth, onboarding, nova_chat, subjects, feed, or mock_tests.

---

## 9. Dashboard time-tracking audit (summary; full detail in `DASHBOARD_TIME_AUDIT.md`)

- **Today:** no timed work reaches Supabase. The focus completion only plays a sound. `ActivityLogService` is a stub with zero call sites. `activity_log` exists only on open PR #98 and isn't pushed. The dashboard reads `DashboardDummyDataSource`. There's no "hours this week" value; the ring shows the tasks done/planned ratio. The semester chart series is fabricated (VERIFIED).
- **Heatmap:** derive it from `activity_log` (`COUNT(*) GROUP BY completed_on`). Don't add a table. `DailyCompletion.isActiveDay = tasksCompleted > 0` already encodes R3.
- **Semester boundaries:** there are no stored dates. The only existing source is the `SemesterUtils` month heuristic (Jan–May = S2, Jun–Dec = S1), plus `users.current_semester`. Real dates are an open question.
- **Week-start preference:** use the existing `nova_config` per-user key/value pattern (global default row + user override, RLS already in place and tested).
- **Counter vs RPC:** use an RPC `get_activity_daily(p_from, p_to)` (SECURITY INVOKER, `auth.uid()`-derived, `search_path` set) over `activity_log`, and do the bucketing in Dart domain code. A stored counter drifts, can't recompute for week-start changes, needs a reset job (and there's no scheduler), and would be client-forgeable on `users`.
- **Timezone:** none stored anywhere. Store `completed_on` as the device-local date at write time and compare dates. Don't use server `CURRENT_DATE`. (Nova separately uses a UTC date for capacity.)
- **Plan:** amend and land PR #98 (`kind`, `duration_seconds >= 0`, global `week_start_day` row, RPC), add a Supabase dashboard datasource, make `ActivityLogService` real and call it from `FocusTimerPage._onTimerComplete`, and fix the chart, streak, and week-start code. Tests: week boundary × 7 start days, local-midnight vs UTC, the May 31/Jun 1 semester split, RLS append-only + RPC isolation, and a publishable-key requirement for the RLS suite.

---

## 10. Known bugs and tech debt

| # | Severity | Bug / debt | Ref | Issue? |
|---|---|---|---|---|
| 1 | **blocking** | `.env` (secret-type Supabase key + Groq/OpenRouter/Cerebras keys) bundled as a Flutter asset. Keys must be considered leaked and rotated. `.env` itself was **never committed to git**: `git log --all --full-history -- .env` and `-S"sb_secret_"` both return nothing (VERIFIED). The leak path is built app bundles, not repo history | `pubspec.yaml` flutter.assets `- .env` | #61 |
| 2 | **blocking (for spec §7)** | `nova_why_log` inserts use columns that don't exist. Every insert fails silently, so there is no audit trail, and `get_nova_triggers`' "since last reasoned" logic never advances | `backend/nova/api/routers/reasoning.py:39-46,78-85` vs `20260710040155_add_nova_why_log.sql` | none (NOVA.md tech debt mentions it) |
| 3 | **high** | Confirming a `situation_flag` proposal inserts `source`, a column `situation_flags` doesn't have, so it fails with an error. Also an E2E coverage gap | `proposals_service.py:212`; `situation_flags` never gets `source` in any migration | none |
| 4 | **blocking (before real users)** | Nova chat/facts/reasoning/proposals unauthenticated + IDOR via path `user_id` + server key bypassing RLS | §5.2 | #51 (partly), NOVA.md |
| 5 | **high** | pyq/rag service fully unauthenticated, CORS `*`, writes with the server key; professor-answer overwrite | `backend/pyq/rag/main.py` | #60, #56 |
| 6 | **high** | Nova CLI crashes on the first successful turn: `ask_nova` returns `ParsedChatResponse` but the CLI passes it to `ChatTurn(content=...)` (str) | `backend/nova/__main__.py:47-55`, `schemas/chat.py` | none |
| 7 | **high** | PR #91 as written breaks `/nova/trigger/check` (service-key caller has no `auth.uid()`) | PR #91 migration vs `backend/app/main.py:20` | #57 |
| 8 | **high** | `handle_vote` SECURITY DEFINER trusts the client `p_user_id`, so vote forgery is possible | baseline:37; `feed_remote_datasource.dart:52-55` | #57 |
| 9 | **high** | RLS holes: `dev read all questions/published_tests` USING(true); `custom_subjects` UPDATE open to all; `subjects` INSERT open; `topics` no RLS; `_integration_test` no RLS | §4.1 | #62 (partly) |
| 10 | **high** | Nova API returns full tracebacks to clients | `backend/nova/api/main.py:14-21` | none |
| 11 | high | Fetch-then-reason not atomic; fetch errors swallowed as empty data | `facts_service.py` | none |
| 12 | high | RLS test suite gives false coverage when `SUPABASE_KEY` is a secret key; not in CI; skips silently | `backend/tests/test_rls.py` | #62, #51 |
| 13 | low | PR #107's squash deleted `backend/nova/MODEL_TIERS_AUDIT.md` and `UI_INTEGRATION_PREREQS.md` (added by #109), yet NOVA.md still links to them. Recover with `git show d30d1c8:<path>` | `git log --diff-filter=D` → `6b55f39` | none |
| 14 | low | `model_tiers.yaml` not loaded; models hardcoded in 3 places | §5.6 | none |
| 15 | high | Flutter mock_tests / exam_prediction call `:8090`; rag runs on `:8000` | §7.1 | FLUTTER.md |
| 16 | high | `_DevMenu` at `/` in production | `app_routes.dart:115,184-234` | #58 |
| 17 | high | Onboarding flash / dual navigation; completion inferred from `full_name` | `app_routes.dart:48-111`, `auth_pages.dart:296-309` | #34 |
| 18 | low | Two `save_onboarding_seed_context` overloads (6-arg INVOKER and 15-arg DEFINER) | migrations `20260716115056`, `20260830163226` | none |
| 19 | low | Onboarding RPC assigns the first campus/institution row when no pattern matches; BITS campus mapping hardcoded in SQL | `20260830163226_…sql` | none |
| 20 | low | Nova API sessions in memory (single worker); no Realtime in the API, so the snapshot goes stale | `sessions.py`, `clients.py` | #15 (CLI) |
| 21 | low | Proposal confirm not transactional (insert, then supersede) | `proposals_service.py:192-223` | none |
| 22 | low | Dashboard dummy data; `DashboardPlanDto` shape ≠ Nova reasoning response; fabricated semester chart; 6-day "weeks"; streak = 0 when today is empty | §9, `DASHBOARD_TIME_AUDIT.md` | none |
| 23 | low | `/syllabus` route renders `SplashScreen`; syllabus/pyq_upload/colleges/analytics are stubs; profile scaffold unused | §7.1 | #50 |
| 24 | low | 269 hardcoded `Color(0x…)` outside the theme | §7.5 | none |
| 25 | low | Supabase URL/key hardcoded in `main.dart`; `Environment` flavors unused by Nova chat | `main.dart:19-22` | #64 |
| 26 | low | `supabase/.temp/` committed; hardcoded test credentials fallback | — | #59 |
| 27 | low | Bench `grid_completion` trusts meta; trec_mmr 234 vs 250; single seed; no significance test; bench pool size (3k) ≠ production (max(10k,50)) | §6, §5.1 | paper/04 |
| 28 | low | Dependabot PR #113 breaks the Flutter build | PR #113 checks | — |
| 29 | low | DOC-DRIFT: README/NOVA.md "subject matching not merged", "5 routes no auth", README "top-15→MMR planned"; bench README/ONBOARDING `select.py` | §5 | none |
| 30 | low | Nova capacity uses the UTC date; triggers use DB `CURRENT_DATE`; no user timezone stored | `facts_service.py:88-89` | none |
| 31 | low | `ActivityLogService` stub claims call sites are wired, but there are none | `lib/core/services/activity_log_service.dart:1` | none |
| 32 | low | `.gitignore` starts with a literal `@"`; BOMs in `ci.yml`/`test_rls.py`; `android/` holds many JVM crash dumps (ignored) | — | none |

---

## 11. Prioritized next steps

| # | Item | Why | Files | Size | Depends on |
|---|---|---|---|---|---|
| 1 | Rotate all keys; remove `- .env` from `pubspec.yaml` assets; stop the Flutter build from needing `.env` | Secrets are shipped in builds | `pubspec.yaml`, CI `analyze`/`test` steps (the placeholder `.env` becomes unnecessary) | S (+ a dashboard rotation by the owner) | owner access to the Supabase/Groq dashboards |
| 2 | Auth on all Nova routes using the existing `get_current_user_id` + path match (as in `subjects.py`); attach the bearer in `nova_chat_remote_datasource.dart` from `currentSession.accessToken`; drop the dev user-id fallbacks; hide tracebacks; narrow CORS | IDOR of every student's facts | `backend/nova/api/routers/*.py`, `deps.py`, `main.py`, `lib/features/nova_chat/data/datasources/…` | M | — |
| 3 | Fix the why-log insert to the real schema (`entry_type`, `facts_snapshot`, `plan_output`, `reasoning_summary`) + unit test | Spec §7; the trigger layer depends on it | `reasoning.py`, new test | S | — |
| 4 | Fix situation_flag confirm (drop `source` for that kind, or add the column via a new migration) + unit tests for `proposals_service` | Runtime failure | `proposals_service.py` or a new migration, `backend/tests/` | S | — |
| 5 | Fix the Nova CLI `ChatTurn` bug (use `answer.response.message`) | Crash | `backend/nova/__main__.py` | XS | — |
| 6 | Rework PR #91 so `get_nova_triggers` allows a server-role caller (or have `backend/app` call it with the user's JWT); add `SET search_path`; fix `handle_vote` | #57 without breaking trigger-check | PR #91 branch | S | — |
| 7 | Add a CI pytest job (safe subset, as run here); make the RLS suite use a publishable key + seeded accounts, and fail rather than skip | No backend tests run in CI | `ci.yml`, `test_rls.py` (cf. PR #90, which needs its PowerShell wrapping fixed) | M | #1 (key handling) |
| 8 | RLS cleanup migration: drop `dev read all *`, scope `custom_subjects` UPDATE, scope `subjects` INSERT, enable RLS on `topics`, drop `_integration_test`, dedupe `users` policies | #62 | new migration | S–M | #7 to verify |
| 9 | Dashboard time tracking per `DASHBOARD_TIME_AUDIT.md` §8 | Product ask (R1–R4) | PR #98 + dashboard feature + `activity_log_service.dart` + focus page | M–L | decisions in §12; #7 for the RLS test |
| 10 | Auth for pyq/rag; fix the Flutter `:8090` → configurable base URL | #60, broken mock tests/exam prediction | `backend/pyq/rag/main.py`, two datasources, `environment.dart` | M | #2 pattern |
| 11 | Router: single navigation authority; gate `_DevMenu` behind `kDebugMode`; persist onboarding completion | #58, #34, flash bug | `app_routes.dart`, `auth_pages.dart`, migration for a completion flag | M | — |
| 12 | Persist Nova plans (table or `study_plans` extension, with item ids + durations) and map them to `DashboardPlan` | Dashboard tasks, `tasksPlannedThisWeek`, spec §1 output | Nova reasoning router, new migration, dashboard data layer | L | #3 |
| 13 | Spec gaps: atomic snapshot RPC, `academic_pressure`, minor/major scoping, cold-start mode, a scheduler for triggers | spec §2a/§3/§9/§11 | Nova services, SQL | L | #3, #12 |
| 14 | Restore the deleted Nova audit docs and fix DOC-DRIFT | Docs link to missing files | `backend/nova/*.md`, README, NOVA.md | XS | — |
| 15 | Bench: recount `.jsonl` lines in `grid_completion`; re-run trec_mmr; multi-seed sweep; paired significance test; align pool size with production or document it | Paper validity | `backend/bench/report.py`, sweeps | M | Groq budget |
| 16 | Clean up branches: delete `docs/dicl-report` (identical), local dependabot branches, merged feature branches; decide on `ci/semgrep`, `origin/fix/issue-60-rag-service-auth`, `fix/expand-card-first-frame-delay` | Hygiene | git | XS | owner OK |
| 17 | Close or retarget dependabot PR #113 (breaks the build) | Red PR | — | S | — |

---

## 12. Open questions (need a human)

1. **Secrets:** have the Supabase secret key and the Groq/OpenRouter/Cerebras keys already been rotated since issue #61 (2026-08-20)? UNKNOWN.
2. **Migration state:** which migrations are applied on the production project? (Run `npx supabase migration list`.) Is `activity_log` pushed anywhere?
3. **PR #98:** merge it as-is and amend later, or rework it first? Its title says "tasks table" but the content is `activity_log`.
4. **Dashboard decisions** (from `DASHBOARD_TIME_AUDIT.md` §10): untimed completions in the heatmap; which kinds count as hours; default week start (UI is currently Sunday); real semester dates vs the `SemesterUtils` heuristic; whether early-stopped sessions count, and any minimum; the source of "tasks planned this week"; streak semantics when today is empty.
5. **CLI auth threat model** (#51): is the Nova CLI a local-only dev tool, or does it need real auth?
6. **Nova trigger cadence:** who or what calls `/nova/trigger/check` (scheduler, app open, or after writes)? Should it run via pg_cron or an Edge Function?
7. **`model_tiers.yaml`:** make it the runtime config, or delete it as documentation?
8. **Does `minor_trigger_rerank` mean** an arithmetic re-rank or a scoped LLM call? (spec §9 leaves this open.)
9. **Flutter subject add:** should it move to the AI-matching endpoints (`/subjects/{id}/add`), or keep writing Supabase directly?
10. **Production API hosts:** staging/prod URLs in `environment.dart` are placeholders. Where will the services be deployed? README mentions Railway.
11. **Edge Function `extract-plan-proxy`:** where is its source, and who owns it?
12. **Branch fate:** `ci/semgrep` (adds semgrep CI), `origin/fix/issue-60-rag-service-auth` (44 behind), `fix/expand-card-first-frame-delay`, the stash on `feat/paper-download-script`.
13. **Paper scope:** which additional open-weight models to run, and what Groq budget is available (`paper/05-open-source-model-extension-plan.md`)?
14. **trec results:** re-run them cleanly, or disclose the hand-repaired raw files in the paper? (Root cause is known, see §6.)
15. **Deployment topology:** the repo has no Dockerfile, Procfile, Railway/Render/Fly config, or deploy job. An earlier README claimed only `backend/app` is deployed. Which services, if any, are reachable from the internet today? This decides how urgent the auth items are.

---

## 14. Context from earlier Claude Code sessions (not in git)

This section was added after a second pass over this project's earlier Claude Code transcripts (`~/.claude/projects/D--Projects-Skolar/*.jsonl`, 2026-09-03 → 10-03). The project memory directory is empty, so this context exists **only** in those transcripts and in the files below.

- **Prior auth research lives outside the repo.** `D:/Projects/_stash_auth/AUTH_AUDIT.md` and `AUTH_PREREQS.md` (2026-09-04, never committed). Read them before doing the auth work in §11 #2 and #10. Contents:
  - per-service, per-route auth status
  - key type per client
  - **no deployment config exists in the repo**
  - **no 401/token-refresh handling anywhere in Flutter**: `AuthInterceptor` is a no-op, and `setBearerToken` is never called (`dio_http_client.dart:62-64,127-134`)
  - non-Flutter callers that will break once auth is added: `backend/pyq/rag/evaluate.py`, `backend/tests/test_persist_flag.py`, and the curl examples in `pyq/ONBOARDING.md`
  - analysis of what the `nova_why_log` INSERT policy should be
  
  Note that `AUTH_PREREQS.md` §6 quotes the hardcoded Flutter anon key and project URL, so don't commit that file as-is. The planned "§12 PR context #72/#91/#93" section was never written.
- **Deleted Nova audit docs:** `backend/nova/UI_INTEGRATION_PREREQS.md` (the minimum path to one authenticated Nova screen) and `MODEL_TIERS_AUDIT.md`. Both were added in #109 and deleted by #107's squash. Recover them with `git show d30d1c8:backend/nova/UI_INTEGRATION_PREREQS.md`.
- **The AI subject matcher was validated live** (2026-09-09, real Groq calls). "OS", "operating systems", "prog langs" and "POPL" all resolved to the right subject with confidence ≥0.95, without relying on `short_name`. Evidence that the 0.75 threshold works for common abbreviations.
- **Bench data was hand-repaired.** See §6: concurrent duplicate runs, and lines deleted from `trec_mmr` and `trec_zero_shot`.
- **The proposals migration was pushed** (`20260909120000_nova_unconfirmed_proposals`). An earlier session confirmed it with `supabase migration list`: it was missing at first, then pushed. Both E2E tests then passed live (standing_flag path), using a throwaway admin-created auth user. See §4.3 for the full migration state.
- **The RLS test accounts don't exist** in the live project, so `test_rls.py` isolation tests skip (§8.3).
- **The owner's UI conventions**, from repeated instructions:
  - Use the **2.5D button** (the auth page button) everywhere.
  - Use **Google Sans** for text.
  - Use the **auth page** as the visual reference, not the profile page.
  - The math game should stay minimal: no transition animations, no confetti or emojis, monochrome results screen ("TIME'S UP").
  - Scope UI edits tightly: change only the element asked for.
- **Dev identities:** earlier sessions mapped several real dev/test Supabase user ids (two student accounts plus the E2E test user). They are deliberately **not** reproduced here; ask the owner.
- **Local tooling:** a "Stop" hook for desktop notifications was added to the user-level `~/.claude/settings.json` (2026-09-09). Machine-specific, not part of the repo.
- **Status audits:** the 2026-09-18 Nova-vs-spec roadmap audit and the 2026-10-03 status session wrote nothing to the repo. Their findings are superseded by §5.7 here.

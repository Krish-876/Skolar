# Dashboard Time-Tracking Audit

Audit date: 2026-10-03. Git state: `master` @ `cadc0a7`, clean tree. This was a read-only audit. Nothing was modified, migrated, or pushed.

Status tags: **VERIFIED** means I read it in code or a migration. **INFERRED** means I deduced it from code. **UNKNOWN** means I could not determine it from the repo.

This document covers §9 of `HANDOFF.md` in full.

---

## 0. Requirements being audited

| # | Requirement (from the project owner) |
|---|---|
| R1 | "Hours this week" in `expandable_progress_card` resets weekly, with a user-configurable week start day |
| R2 | Total semester hours are persisted in Supabase and update as timed work completes |
| R3 | Heatmap (`streak_strip`): a day is active if any task was completed that day |
| R4 | `weekly_bar_chart` shows weekly, monthly, and semester progress from real data |
| C1 | The work must fit the existing architecture: Clean Architecture, Riverpod, `focus_session`, `tasks`/`study_plans`/`activity_log`, and Nova plan tasks |
| C2 | No hardcoding and no standalone additions |

---

## 1. Today's timer-to-Supabase data flow and its gaps

**Short version: no timed work reaches Supabase today. Nothing at all is persisted.** (VERIFIED)

```
TaskListTile "start" button
  └─ context.push(AppRoutes.focusSession, extra: task.timerDuration)     task_list_tile.dart:81
       (only a Duration is passed. No task id, subject, or plan reference.)
FocusTimerPage(initialDuration)                                           app_routes.dart:150-158
  └─ FocusTimerController.start() ... _onTick / syncWithSystemTime
       └─ _completeSession()  → onComplete?.call()                        focus_timer_controller.dart:208-219
            └─ FocusTimerPage._onTimerComplete()                          focus_timer_page.dart:321-328
                 wakelock off, UI reset, playSessionComplete()
                 ✗ no Supabase write
                 ✗ no ActivityLogService call
                 ✗ no provider invalidation (dashboard never learns about it)
FocusTimerController.reset()                                              focus_timer_controller.dart:138
  ✗ abandons the session. Partial focus time is discarded and not recorded.
```

Gaps:

| Gap | Evidence | Status |
|---|---|---|
| G1. No write path exists. `ActivityLogService` is an interface plus a no-op stub. Its header says "call sites are wired now", but **there are no call sites**. | `lib/core/services/activity_log_service.dart:1-19`; `grep ActivityLogService lib` returns only that file | VERIFIED |
| G2. The stub API does not fit the data. `logFocusComplete(String userId)` takes no duration, and it takes `userId` as a parameter, which is client-trusted identity. | `activity_log_service.dart:4` | VERIFIED |
| G3. The `activity_log` table is **not on master**. It exists only on the unmerged branch `feat/dashboard-tasks-schema` (open PR #98) and on a stale duplicate branch `feat/dashboard-activity-log` (local worktree `D:/Projects/Skolar-tasks-schema`). A reviewer reported it is **not pushed** to the shared DB (PGRST205 in PR #98's comments). | `git show origin/feat/dashboard-tasks-schema:supabase/migrations/20260902144732_add_activity_log.sql`; `gh pr view 98` comments | VERIFIED |
| G4. The task-to-timer link is lost. The focus route receives only a `Duration`, so a completed session cannot mark a plan task done. | `task_list_tile.dart:81`, `app_routes.dart:152-157` | VERIFIED |
| G5. Nova plan tasks are not persisted anywhere. `/reasoning/{user_id}/run` keeps the plan in an in-memory session (`session.last_good_plan`). `PlanItem` has no id and no timer duration (`subject, task, priority, reason`). The why-log insert that would record the plan uses columns that don't exist (see HANDOFF §5). | `backend/nova/api/sessions.py:17-37`, `backend/nova/schemas/api.py` `PlanItem`, `backend/nova/api/routers/reasoning.py:39,78` vs `supabase/migrations/20260710040155_add_nova_why_log.sql` | VERIFIED |
| G6. `study_plans` is a per-subject *handout* plan (`weekly_plan jsonb`, `topics jsonb`). It is written by the Supabase Edge Function `extract-plan-proxy`, whose source is **not in this repo**. It is not a daily task list and has no completion state. | baseline.sql `CREATE TABLE public.study_plans`; `lib/features/subjects/data/datasources/subjects_datasource.dart:302-303` | VERIFIED (table) / UNKNOWN (function source) |
| G7. Pomodoro: the duration that should count is `_totalSeconds` (focus only). Break time is added separately in `totalSessionDurationWithBreaks`, and the controller exposes no "focused seconds elapsed" value for early stops. | `focus_timer_controller.dart:78-86` | VERIFIED |
| G8. There is no `tasks` table anywhere. PR #98 replaced its original `tasks` design with `activity_log` (commit `a62ed39`). | `git log origin/feat/dashboard-tasks-schema` | VERIFIED |

---

## 2. Dashboard widgets: current source, provider, and expected entity shape

The provider chain is the same for all of them (VERIFIED, `lib/features/dashboard/presentation/providers/dashboard_provider.dart:23-50`):

```
_dashboardDataSourceProvider = DashboardDummyDataSource()   ← hardcoded swap point (line 23-25)
  → DashboardRepositoryImpl → GetProgressStats use case → progressStatsProvider (FutureProvider<ProgressStats>)
DashboardRemoteDataSource: every method throws UnimplementedError (dashboard_datasource.dart:12-23)
```

| Widget | What it shows today | Provider | Data | Entity it consumes |
|---|---|---|---|---|
| `expandable_progress_card.dart` collapsed/expanded ring | `tasksCompletedThisWeek / tasksPlannedThisWeek` ratio (line 718); no "hours this week" value exists anywhere in the widget | `progressStatsProvider` (line 558) | Dummy values 9/14 (`dashboard_datasource.dart:48`) | `ProgressStats` (`dashboard_entity.dart:17-35`) |
| same card, stat badge | `cumulativeHoursThisSemester` rendered as "132.5h" with label "this semester" (lines 778-779, 881-882, 1165-1166) | `progressStatsProvider` | Dummy 132.5 (`dashboard_datasource.dart:50`) | `ProgressStats.cumulativeHoursThisSemester` |
| same card, "day streak" badge | `_currentStreak(dailyCompletions)` (lines 21-28) | `progressStatsProvider` | Dummy 30-day repeating pattern | `List<DailyCompletion>` |
| same card, Today's Tasks list | `DashboardPlan.remainingTasks` → `TaskListTile` | `dashboardPlanProvider` (`AsyncNotifier`) | Dummy empty list, so it shows the empty Lottie | `DashboardPlan{tasks: List<DashboardTask{id,title,subject,timerDuration,completed}>, stale, note}` |
| `streak_strip.dart` (week pills plus month heatmap) | Tint per day from `tasksCompleted` (lines 32-36, 212, 386) | `progressStatsProvider`, `streakViewModeProvider` | Dummy | `DailyCompletion{date (local midnight), tasksCompleted}`, with `isActiveDay = tasksCompleted > 0` (`dashboard_entity.dart:12`). **R3's rule already exists in the entity.** |
| `weekly_bar_chart.dart` | Week: last 7 rolling days, not a calendar week (line 42). Month: **6-day buckets labeled W1..W5** (line 45). Semester: **fabricated `8 + i*3` series** (lines 53-56) | `weeklyChartDataProvider` (line 32) derived from `progressStatsProvider` | Dummy, plus hardcoded semester values | `Map<WeeklyChartRange, List<ChartPoint{label,value}>>` |

Other mismatches (VERIFIED):

- The `DashboardPlanDto` comment says it "mirrors `POST /reasoning/{user_id}/run`", but the shapes differ. The DTO expects `{plan: [ {id,title,subject,timerMinutes,completed} ], stale, note}`. Nova returns `{plan: {items: [{subject,task,priority,reason}], summary}, stale, note, compression_tier}`. See `dashboard_dto.dart` `DashboardPlanDto.fromJson` and `backend/nova/schemas/api.py` `ReasoningRunResponse`.
- `ProgressStats.dailyCompletions` is documented as a "rolling last-30-days window", which cannot feed a semester view (about 150+ days).
- Streak bug: `_currentStreak` walks back from today and stops at the first inactive day. If today has no completion *yet*, the streak shows 0 even when yesterday and earlier were active (`expandable_progress_card.dart:21-28`). This is INFERRED as a UX bug and is a product call.

---

## 3. Heatmap: derive from existing data, or add a new table?

**Recommendation: derive it from `activity_log` (PR #98's table, landed with the small amendments in §8). Do not add a dedicated heatmap or streak table.**

| Option | Pros | Cons |
|---|---|---|
| **A. Derive from `activity_log`: `COUNT(*) GROUP BY completed_on`** (recommended) | One source of truth. The index `activity_log_user_date_idx (user_id, completed_on) INCLUDE (duration_seconds)` already serves it (PR #98). R2, R3 and R4 all come from the same rows, so the numbers can never disagree. Matches PR #98's stated design ("no stored rollup counters"). | Needs `activity_log` to record *every* task completion, including untimed ones. PR #98 has `CHECK (duration_seconds > 0)`, which forbids that (see §8, decision needed). |
| B. Derive from `test_attempts` / `question_results` / `nova_why_log` | No new writes needed | These aren't "task completed" events. A study day with only focus sessions would show as inactive. Doesn't meet R3. |
| C. New `daily_activity` / `streaks` table | Fast reads | A second source of truth that can drift from `activity_log`. Needs triggers or dual writes. Violates C2 ("no standalone additions"). |

---

## 4. Semester boundaries: is there an existing source?

**There are no stored semester start/end dates anywhere in the repo.** (VERIFIED: searched `lib`, `supabase/migrations`, `backend/nova`, `backend/app` for semester/term/start_date/end_date/academic_calendar.) I did not invent dates.

What does exist:

| Source | What it holds | Location |
|---|---|---|
| `SemesterUtils.currentSemesterNumber()` | A **month heuristic**: Jan–May means semester 2, Jun–Dec means semester 1. Its docstring says it "must be the ONLY place this logic lives" | `lib/features/subjects/domain/utils/semester_utils.dart:1-23` |
| `SemesterUtils.currentSemesterLabel()` | `"YYYY-S#"` label, stored into `user_subjects.semester` (text) | same file; `user_subjects.semester text NOT NULL` (baseline) |
| `users.current_semester` | `smallint`, CHECK 1 or 2, set by onboarding | `20260720130500_onboarding_profile_fields.sql` |
| `user_subject_exams.exam_date` | Per-subject exam dates (quiz1/midsem/quiz2/compre). Could *bound* a semester empirically, but they're optional and per-user | baseline `user_subject_exams` |

Implication: the only non-invented semester window available today is the calendar range implied by `SemesterUtils`, which gives `[Jan 1, May 31]` or `[Jun 1, Dec 31]` of the current year. Using it keeps a single source of truth (C2). Real academic-calendar dates (for example, from the institution) are an **open question** for a human.

---

## 5. Where the week-start preference should live

There is an existing per-user settings pattern: **`public.nova_config`** (VERIFIED).

- Schema: `(id, user_id uuid NULL → users ON DELETE CASCADE, key text, value jsonb, updated_at)`. It has `UNIQUE(user_id, key)` and a partial unique index on `key WHERE user_id IS NULL` for global defaults. See `20260713070100_nova_trigger_layer_schema.sql`, `20260713071934_nova_config_global_key_fix.sql`, and `20260831154137_cascade_delete_user_relations.sql`.
- RLS: SELECT `user_id = auth.uid() OR user_id IS NULL`; INSERT and UPDATE require `user_id = auth.uid()` (`20260716115056_onboarding_seed_context_and_career_coldstart.sql:28-41`).
- Precedent: global default rows such as `staleness_days_academic`, `time_left_buckets`, and `academic_pressure_buckets`, plus the per-user row `capacity_hour_mapping` written by `save_onboarding_seed_context`.
- Already covered by `test_rls.py`: `nova_config` is in `USER_TABLES_TO_TEST` (`backend/tests/test_rls.py:24-30`).

**Recommendation:** add a global default row `(NULL, 'week_start_day', <ISO weekday int>)` plus per-user override rows. Read with "user row if present, else global". No new table, no new column on `users`.

The default value is a product decision (Open question). Current UI behavior is **Sunday-start**, hardcoded in `streak_strip.dart:172-182` (`_sundayOnOrBefore`, `weekday % 7`) and the month grid (`streak_strip.dart:358`, `:470-473`).

Local-only alternative: `SharedPreferences` is used for UI prefs (`focus_preferences_service.dart`, `math_game_high_score_service.dart`). It would not sync across devices, and SQL could not see it if any server-side aggregation needs it. Not recommended.

---

## 6. Stored semester counter vs. SQL view/RPC over `activity_log`

| Criterion | Stored counter (e.g. `users.semester_seconds` or a rollup row, bumped on each completion) | View/RPC aggregating `activity_log` on read (recommended) |
|---|---|---|
| Drift | Can drift whenever an insert succeeds and the counter update fails (or the reverse), or on retries/double-fires (the focus controller guards double completion in memory only, `focus_timer_controller.dart:203-219`). Needs a trigger to be safe. | None. The sum *is* the rows. |
| Consistency with week/month/heatmap | A separate number from the per-day series, so the weekly bars could disagree with the total | Same rows feed every widget |
| Semester rollover | Needs a reset job or a per-semester key. There's no scheduler in the repo (no cron, pg_cron, or Edge Function source) | Just change the date range parameter |
| Week-start change | Can't be recomputed retroactively | Recomputed on read |
| Performance | O(1) read | O(rows in range) via a covering index scan. At realistic volume (a few rows per user per day, about 1k per semester) this is negligible |
| Fit with existing RPC patterns | No precedent for counters | Matches `save_onboarding_seed_context` (identity from `auth.uid()`, `SET search_path`) and avoids the `p_user_id` anti-pattern flagged in issue #57 / `get_nova_triggers` |
| RLS | The counter column on `users` is editable by the owner via the existing `users_update_own` policy, so the client could forge it | Insert-only `activity_log` policies (no UPDATE or DELETE) make history append-only |

**Recommendation: an RPC, not a view.** A view would need `security_invoker` handling and can't take parameters. Name it `get_activity_daily(p_from date, p_to date)`, returning one row per day `(day date, completions int, focus_seconds bigint)` for `auth.uid()` only. Declare it `SECURITY INVOKER`, `STABLE`, `SET search_path = public, pg_temp`, with no user-id parameter. Do the bucketing (week, month, semester) in Dart domain use cases, so it is unit-testable without a database.

---

## 7. Timezone: source and where day/week boundaries are computed

| Place | Behavior | Status |
|---|---|---|
| `users` table | **No timezone column.** No timezone stored anywhere in the schema | VERIFIED |
| Flutter dashboard entity | `DailyCompletion.date` is documented as a *local* calendar date (`dashboard_entity.dart:1-4`). Streak strip and chart use `DateTime.now()` local | VERIFIED |
| Nova facts | `_fetch_capacity_today` uses the **UTC** date (`backend/nova/services/facts_service.py:88-89`) | VERIFIED |
| Trigger RPC | `get_nova_triggers` uses `CURRENT_DATE` and `now()`, which is the DB session timezone (on hosted Supabase, normally UTC, INFERRED) | VERIFIED (code) / INFERRED (tz) |
| PR #98 `activity_log` | `completed_on date NOT NULL`, client-supplied, plus `created_at timestamptz DEFAULT now()` | VERIFIED |

**Recommendation:** keep `completed_on` as the **device-local date at completion time**, written by the client. Keep `created_at` as the true instant. All day, week, and semester boundaries are then plain `date` comparisons, and no timezone math is needed in SQL. This matches the entity's documented contract.

Known edge: a user who changes timezone keeps whatever local date was recorded at write time. That is arguably correct ("the day it was for me").

Don't use the server `CURRENT_DATE` for dashboard boundaries. Students in IST (UTC+5:30) completing work between 00:00 and 05:30 local would land on the previous UTC date.

Nova's UTC capacity date is a separate, pre-existing inconsistency (HANDOFF §10).

---

## 8. Implementation plan

### 8.1 Migration (amend and land PR #98, or supersede it)

Create it with `npx supabase migration new add_activity_log`. Don't hand-name it. Apply with `supabase db push` manually after merge (team convention).

Starting point: PR #98's `20260902144732_add_activity_log.sql`. It already has an append-only RLS (SELECT + INSERT only, `(select auth.uid())` initplan form), cascade on user delete, and a covering index.

Amendments (each needs a human decision, see §10):

1. `duration_seconds integer NOT NULL CHECK (duration_seconds >= 0)`. PR #98 has `> 0`, which blocks logging untimed task completions that R3 needs.
2. `kind text NOT NULL CHECK (kind IN (...))`, where the values come from the existing stub's four call types: `focus_session`, `test`, `puzzle`, `doubt` (`activity_log_service.dart:4-7`), plus `task` if untimed plan-task completions are logged. Without `kind`, R3 (any completion) and R2 (timed work only) can't be separated.
3. Optional `user_subject_id uuid REFERENCES user_subjects(id) ON DELETE SET NULL`, if per-subject hours are wanted later. Skip it if not needed (C2).
4. Keep `id uuid` client-suppliable. The client generates a UUID per completion, so retries are idempotent via `INSERT ... ON CONFLICT (id) DO NOTHING`. I believe DO NOTHING needs only the INSERT policy (INFERRED; verify on a branch DB).
5. Seed the global default: `INSERT INTO nova_config (user_id, key, value) VALUES (NULL, 'week_start_day', '<n>')`. The value is an open question.
6. RPC:

```sql
CREATE OR REPLACE FUNCTION public.get_activity_daily(p_from date, p_to date)
RETURNS TABLE (day date, completions int, focus_seconds bigint)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp AS $$
  SELECT completed_on, COUNT(*)::int,
         COALESCE(SUM(duration_seconds) FILTER (WHERE kind = 'focus_session'), 0)
  FROM activity_log
  WHERE user_id = auth.uid() AND completed_on >= p_from AND completed_on < p_to
  GROUP BY completed_on ORDER BY completed_on;
$$;
REVOKE ALL ON FUNCTION public.get_activity_daily(date, date) FROM anon;
```

The `FILTER` on `kind` defines "timed work". Whether test, puzzle, or task time also counts toward hours is an open question.

### 8.2 Domain (`lib/features/dashboard/domain/`)

- **`ProgressStats`**: add `focusSecondsThisWeek` (R1) and replace `cumulativeHoursThisSemester` with seconds or a `Duration`. Formatting belongs in presentation. Replace the "rolling 30 days" contract with a `DateRange`-scoped daily series.
- **`DailyActivity`**: rename or extend `DailyCompletion` to `{date, completions, focusSeconds}`. Keep `isActiveDay => completions > 0` (R3).
- **New pure functions or use cases**, unit-testable:
  - `weekStartFor(DateTime localDate, int isoWeekStart)`
  - `bucketByWeek(...)` and `bucketByMonth(...)` (calendar months, not 6-day chunks)
  - `semesterRange(DateTime now)`, delegating to `SemesterUtils`. Add a range method there so the month rule stays single-sourced.
- **`WeekStartPreference`**: repository interface method `getWeekStartDay()` / `setWeekStartDay(int)`.
- **`DashboardRepository`**: `getProgressStats()` stays (C1). Add `getActivityRange(DateRange)` for the chart and month heatmap paging.

### 8.3 Data (`lib/features/dashboard/data/`)

- **`DashboardSupabaseDataSource`** implements `DashboardDataSource`:
  - `getProgressStats` calls `rpc('get_activity_daily', {p_from, p_to})` over the semester range, then aggregates.
  - Plan methods keep the dummy behavior until Nova plans are persisted (G5).
  - Reads `nova_config` for `week_start_day`: user row, then global row.
- **DTO**: `DailyActivityDto.fromJson` maps the RPC rows.
- **Provider swap**: `_dashboardDataSourceProvider` (`dashboard_provider.dart:23`) points at the Supabase source. Keep the dummy source for tests.

### 8.4 Write path (`lib/core/services/activity_log_service.dart`, existing seam)

- Change the interface to derive identity from the session: `logCompletion({required String kind, required int durationSeconds, String? clientId})`. Drop the `userId` parameter. The implementation uses `Supabase.instance.client.auth.currentUser` and RLS enforces it anyway.
- Add a Riverpod `activityLogServiceProvider`. Nothing in `lib/core/di/providers.dart` registers services today; that file is mostly commented out.
- Call it from `FocusTimerPage._onTimerComplete()` (`focus_timer_page.dart:321`) with the focus-only seconds (`_totalSeconds`, G7). Then `ref.invalidate(progressStatsProvider)`.
- Early-stop (`reset()`) logging needs a "focused seconds elapsed" getter on the controller and a product decision (Open question).
- Plan-task linking (G4): pass a task id through `extra` alongside the `Duration`. This only becomes meaningful once Nova plan items get persisted ids (G5).

### 8.5 Presentation

- `expandable_progress_card.dart`: add an "hours this week" badge sourced from `focusSecondsThisWeek` (R1). Keep the semester badge (R2).
- `streak_strip.dart`: replace `_sundayOnOrBefore` and `weekday % 7` with the configurable week start (lines 172-182, 358, 470-473, and the header-letter generation at 429-437).
- `weekly_bar_chart.dart`: replace the 6-day "W" buckets and the fabricated semester series (lines 42-56) with domain bucketing.
- Settings UI for the week start day: there's no settings screen today. `AppConstants` has a `/settings` constant (`lib/core/constants/app_constants.dart:71`) but no route. Placement is an open question.

### 8.6 Tests to add

| Test | Where | What it asserts |
|---|---|---|
| Week boundary, custom start day | new `test/dashboard_week_boundary_test.dart` | For each ISO start day 1..7, a date on the start day maps to itself, and the day before it maps to the previous week |
| Timezone edge | same file / DTO test | A completion at local 00:30 on day D (UTC still D-1 for UTC+5:30) is counted on D, because `completed_on` is the local date and must not be derived from UTC |
| Semester aggregation | new `test/semester_range_test.dart` | May 31 and Jun 1 fall in different semesters per `SemesterUtils`; the sum over a range equals the sum of daily `focusSeconds` |
| Streak | existing `test/dashboard_smoke_test.dart` or a new unit test | Pins the decided behavior for "today empty, yesterday active" |
| Chart bucketing | unit | Month buckets follow calendar weeks/months, not 6-day chunks |
| RLS | `backend/tests/test_rls.py` | Add `activity_log` to `USER_TABLES_TO_TEST` (PR #98 already does). Also assert the owner **cannot UPDATE or DELETE** their own rows (append-only), and that `get_activity_daily` called by student B returns none of A's rows |
| RLS test validity | `backend/tests/test_rls.py:13-14,33-36` | The "anon" client is built from `SUPABASE_KEY`. In the local root `.env`, that is a **secret-type key** (checked by prefix only, value not printed). That would bypass RLS and make the suite vacuous (issue #62). Read a separate publishable-key env var for the anon/authenticated clients and assert its type |

---

## 9. Constraint check (C1/C2)

- Clean Architecture and Riverpod: all changes go through the existing dashboard domain, data, and presentation seams, plus `core/services/activity_log_service.dart`.
- No hardcoding: the week start comes from `nova_config`, the semester range comes from `SemesterUtils`, and the fabricated chart series are removed.
- No standalone additions: the plan reuses the planned `activity_log` (PR #98), `nova_config`, and `SemesterUtils`. The only new database object is one read RPC.
- Nova plan tasks: blocked on G5. Hours and streaks work without them. "Tasks planned this week" does not.

## 10. Decisions needed (also listed in HANDOFF §12)

1. Should untimed task completions count toward the heatmap? This decides whether the `duration_seconds > 0` CHECK is relaxed and whether `kind` is added.
2. Which activity kinds count as "hours": focus only, or also test, puzzle, and task?
3. Default week start day. Current UI is Sunday.
4. Real semester dates vs. the `SemesterUtils` month heuristic.
5. Do abandoned or early-stopped focus sessions count, and is there a minimum?
6. Where `tasksPlannedThisWeek` comes from until Nova plans are persisted.
7. Streak semantics when today has no completion yet.
8. Merge PR #98 as-is and amend in a follow-up migration, or rework it before merge? Its `python-lint` check failed on the PR (the reviewer said to ignore it).

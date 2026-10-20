# Skolar — Nova

Nova is an AI mentor that tells the student where to put their hours today.
It reasons over a fresh facts snapshot every day, weighing exam urgency,
weakness type, capacity, career relevance, and history — with no hardcoded
priority rules. Full design intent lives in [`spec.md`](spec.md); this file
documents what's actually built, where it lives, and where it still diverges
from that spec.

Back to [README](README.md). Database schema for Nova's own tables lives here;
core academic tables are in [DATABASE.md](DATABASE.md).

---

## Table of Contents

- [Core Principle](#core-principle)
- [Nova API Service (`backend/nova`)](#nova-api-service-backendnova)
- [Proposals Flow (Confirmation Gate)](#proposals-flow-confirmation-gate)
- [Nova Chat UI (`lib/features/nova_chat`)](#nova-chat-ui-libfeaturesnova_chat)
- [Nova CLI (Dev Prototype)](#nova-cli-dev-prototype)
- [Nova Trigger Layer (`backend/app`)](#nova-trigger-layer-backendapp)
- [Nova Schema Tables](#nova-schema-tables)
- [Onboarding Seed Context](#onboarding-seed-context)
- [Nova Facts Snapshot](#nova-facts-snapshot)
- [AI Subject Matching (in review, not merged)](#ai-subject-matching-in-review-not-merged)
- [Prior Audits](#prior-audits)
- [Tech Debt](#tech-debt)
- [Nova — Still To Build](#nova--still-to-build)

---

## Core Principle

Nothing about what to prioritize is hardcoded. Only the plumbing — what
triggers re-evaluation, what gets confirmed, what gets logged — is
rule-based. The actual judgment is reasoned fresh every time by an LLM
acting like an experienced senior.

## Nova API Service (`backend/nova`)

This is the real, live FastAPI service behind the chat UI, the study-plan
reasoning pass, and the proposal confirmation flow. It is a **separate
service from `backend/app`** (the trigger-check service — see
[Nova Trigger Layer](#nova-trigger-layer-backendapp)) and from
`backend/pyq/rag` (the question-generation pipeline — see
[BACKEND.md](BACKEND.md)).

### Run it locally

```bash
cd backend
pip install -r nova/requirements.txt
uvicorn nova.api.main:app --reload --port 8080
```

Port **8080** matches `Environment.development.apiBaseUrl` in
`lib/core/config/environment.dart` (`http://localhost:8080`). For testing
from a physical device on the same LAN (not an emulator, which can reach
`localhost` directly), bind to all interfaces instead and point the app's
`apiBaseUrl` at your machine's LAN IP:

```bash
uvicorn nova.api.main:app --reload --host 0.0.0.0 --port 8080
```

**Environment variables** (`backend/nova/services/clients.py`, loaded via
`python-dotenv`): `SUPABASE_URL`, `SUPABASE_KEY`, `GROQ_API_KEY` are
required; `GROQ_API_KEY_2` (backup Groq key), `CEREBRAS_API_KEY`, and
`OPENROUTER_API_KEY` are optional and gate the shadow-eval tiers (see
[Prior Audits](#prior-audits)) — missing optional keys just mean that tier
stays unavailable, not an error.

**Single-process/single-worker only today.** `backend/nova/api/sessions.py`
keeps per-user session state (facts cache, chat history, last-good plan) in
an in-memory dict — it won't survive a restart and isn't shared across
worker processes. Don't run this with `--workers > 1` or behind a
multi-instance deployment until that's swapped for shared storage (e.g.
Redis).

### Endpoints

All routers are mounted with **no `/nova` prefix** — every path is relative
to the service root (`backend/nova/api/main.py`: `app.include_router(chat.router)`
etc., none pass a `prefix=`). This is a real structural difference from an
earlier planned design that assumed a `/nova/*` prefix — don't assume one.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness check |
| `POST` | `/chat/{user_id}` | Send a message to Nova — returns `ChatResponse{type, message, data, suggestions}` |
| `GET` | `/chat/{user_id}/suggestions` | Initial quick-suggestion chips |
| `GET` | `/facts/{user_id}` | Raw facts snapshot for this student |
| `POST` | `/reasoning/{user_id}/run` | Run a reasoning pass (`trigger_type: 'full_pass' \| 'minor_trigger_rerank'`) → ranked study plan |
| `GET` | `/proposals/{user_id}/pending` | List unconfirmed proposals from this user's conversation |
| `POST` | `/proposals/{user_id}/{proposal_id}/confirm` | Confirm one proposal — writes the real row |
| `POST` | `/proposals/{user_id}/{proposal_id}/reject` | Reject one proposal — no write |
| `POST` | `/proposals/{user_id}/turn/{turn_id}/confirm` | Confirm every proposal from one chat turn at once |
| `POST` | `/proposals/{user_id}/turn/{turn_id}/reject` | Reject every proposal from one chat turn at once |

`full_pass` vs `minor_trigger_rerank` currently only changes one thing —
`_REASONING_EFFORT` in `reasoning_service.py` picks `"high"` vs `"medium"`
Groq reasoning effort. Both run the identical full-snapshot prompt through
the identical code path; there's no separate lighter/scoped re-rank yet.

### Auth and scope

All user-scoped routes require a verified bearer token through
`backend/nova/api/deps.py`. The path `user_id` is checked against the
verified authenticated user before Supabase/Groq clients or session state are
constructed, returning `401` for missing/invalid authentication and `403` for
cross-user access. The service currently exposes student-owned operations
only; no administrator-only Nova operation is defined in this repository.

The separate `backend/app` trigger route accepts only trusted application
roles (`student` or `admin`) from verified JWT `app_metadata`. Supabase's
generic JWT role claim is not treated as an application role, and missing or
unrecognized application role metadata is denied.

## Proposals Flow (Confirmation Gate)

Chat never writes `standing_flags`, `situation_flags`, `nova_history`, or
`career_units` directly. Instead, when the model proposes a fact during a
conversation, it's staged in `nova_unconfirmed_proposals` — inert until the
student explicitly confirms it. Only confirming writes the real destination
table; rejecting just marks the staged row rejected.

```
Student says something Nova-worthy in chat
        ↓
proposals_service.py stages a row in nova_unconfirmed_proposals
        ↓ (chat response includes the proposal for the UI to render as a confirm/reject chip)
Student confirms (per-proposal or per-turn)              Student rejects
        ↓                                                        ↓
Real row written to standing_flags / situation_flags /    Staged row marked
nova_history / career_units, supersession resolved         'rejected', nothing
at confirm time (§2a rule)                                  else touched
        ↓
Relevant FactsState table marked dirty — next /chat or
/reasoning/run call picks up the change
```

`career_unit` proposals are the one exception to the supersession model:
they use pause/resume (un-pausing an existing row matched by case-insensitive
name) rather than superseding a previous row, matching how `career_units`
already works elsewhere in the schema.

Endpoints, request flow, and schemas are listed in
[Nova API Service](#nova-api-service-backendnova) above. Full schemas:

```python
ProposalKind = Literal["standing_flag", "situation_flag", "nova_history", "career_unit"]
ProposalSummary{id, turn_id, kind, summary}         # what the client renders as a confirm/reject chip
PendingProposal(ProposalSummary){created_at}
ProposalResolution{id, kind, status: "confirmed"|"rejected", resulting_row_id?}
```

The staging table itself (`nova_unconfirmed_proposals`, migration
`20260909120000_nova_unconfirmed_proposals.sql`):

```
id                  uuid, primary key, default gen_random_uuid()
user_id             uuid, not null, references users.id ON DELETE CASCADE
turn_id             uuid, not null — groups everything proposed in one chat turn
proposal_type       text, not null, check (standing_flag|situation_flag|nova_history|career_unit)
user_subject_id     uuid, nullable, references user_subjects.id ON DELETE CASCADE
career_unit_id      uuid, nullable, references career_units.id ON DELETE CASCADE
payload             jsonb, not null
proposed_summary    text, not null
status              text, not null, default 'pending', check (pending|confirmed|rejected)
resulting_row_id    uuid, nullable
resolved_at         timestamptz, nullable
created_at          timestamptz, not null, default now()
```

RLS: read-only for the owning student (`SELECT` where `user_id = auth.uid()`)
— no direct INSERT/UPDATE for `authenticated` at all. The real write path
(`backend/nova`) always uses the service-role key, which bypasses RLS
regardless; this policy only matters if the table is ever queried directly
by a Supabase client.

> The migration's own comments flag a related, pre-existing gap worth
> knowing about: `standing_flags`, `situation_flags`, `nova_history`, and
> `career_units` all use a single `FOR ALL USING (user_id = auth.uid())`
> RLS policy, which — as an apparently unintended side effect — lets an
> authenticated student INSERT/UPDATE those tables directly with
> `confirmed_at` already set, bypassing the propose/confirm flow entirely.
> Not fixed by this migration; flagged, not silently repeated.

## Nova Chat UI (`lib/features/nova_chat`)

**This is real and shipped**, not planned. It's a complete Clean
Architecture feature, reachable from the dashboard (an `expandable_progress_card.dart`
tap routes to `AppRoutes.novaChat = '/nova-chat'`), not just a dev-menu entry.

| Layer | Files |
|---|---|
| Presentation | `nova_chat_page.dart` (full chat screen — glassmorphic background, message list, empty-state greeting, input dock, suggestion chips); widgets: `nova_chat_app_bar`, `nova_chat_bubble`, `nova_chat_input_dock`, `nova_quick_suggestions`, `nova_thinking_indicator`, `nova_study_plan_card`, `nova_quiz_card`, `nova_flashcard_deck`, `nova_practice_problem_card`, `nova_fullscreen_modal`, `nova_proposal_card` |
| State | `nova_chat_provider.dart` (Riverpod `StateNotifier`), `nova_chat_state.dart` |
| Data | `nova_chat_remote_datasource.dart`, `nova_chat_repository_impl.dart`, DTOs (`chat_message_dto`, `study_plan_dto`, `proposal_dto`) |
| Domain | `chat_message_entity`, `study_plan_entity`, `proposal_entity`, `i_nova_chat_repository.dart` |

The datasource covers every endpoint listed above, including the full
proposals set (`getPendingProposals`, `confirmProposal`, `rejectProposal`,
`confirmProposalTurn`, `rejectProposalTurn`) — there's a renderer for every
one of the backend's response types.

`userId` is sourced from `Supabase.instance.client.auth.currentUser?.id`,
falling back to a hardcoded dev ID (`dev-student-01` / `dev-user-001`
depending on call site) when there is no session. The shared Dio client
attaches the current Supabase bearer token; the API independently verifies
that token and rejects requests whose path `userId` does not match it.

## Nova CLI (Dev Prototype)

A working, dev-only CLI still exists, now living at `backend/nova/__main__.py`
(moved from the old `lib/core/ai/nova/nova_agent.py`, which no longer exists
anywhere in the repo — its usage string still literally says
`python nova_agent.py <user_id>`, which is stale; the real invocation is
below).

```bash
cd backend
python -m nova <user_id>
```

It fetches a student's live facts snapshot from Supabase and lets you ask
Nova questions about it in a terminal chat loop, answered by Groq
(`openai/gpt-oss-120b` via `chat_service.ask_nova`).

**What's changed since the CLI first shipped** (this corrects the CLI's old
"no error handling, snapshot goes stale" characterization — both are fixed):

- **Error handling exists now.** The initial facts fetch and every chat turn
  are wrapped in try/except — a failure prints a message and either exits
  cleanly (startup) or lets you try again (mid-session), instead of dumping
  a raw stack trace and killing the session.
- **The snapshot no longer goes stale mid-session.** `start_facts_listener_threaded`
  opens a background Supabase Realtime subscription covering every table
  `FactsSnapshot` is built from; a live data change marks the relevant table
  dirty and gets patched into the next turn's snapshot, instead of being
  held frozen from process startup.
- **Groq key fallback and model switching** (from the prior CLI writeup)
  still apply: an optional `GROQ_API_KEY_2` is tried once if the primary
  call raises, and the model is a parameter rather than hardcoded.

**What's still true, unchanged:**

- **No auth.** `user_id` is a raw CLI argument with no check against the
  caller's identity — dev-only, local use, runs on a service-role key that
  bypasses RLS (so the CLI's own `.eq("id", user_id)` filter, not RLS, is
  what stops it from reading another student's profile row).

## Nova Trigger Layer (`backend/app`)

A separate, standalone FastAPI service — not part of `backend/nova` and not
mounted into it.

```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/nova/trigger/check` | Runs `get_nova_triggers(p_user_id)` — decides whether a reasoning pass is warranted |

- The trigger logic itself is a Postgres function, `public.get_nova_triggers(p_user_id uuid)`
  (latest version in migration `20260716115056_...sql`), not Python. It's a
  single batched, set-based query covering 10 trigger branches: new test
  score, time-left threshold, error-type shift, academic staleness, career
  staleness, situation-flag confirmed, standing-flag confirmed, industry
  relevance refreshed, capacity changed, and new career unit — one query per
  student, not a per-unit loop.
- **Auth is real here** — `get_current_user_id` (`backend/app/dependencies.py`)
  is `HTTPBearer` → `supabase.auth.get_user(token)` → returns the verified
  `user_id` or raises 401. **There's no service-role bypass.** This is
  still accurate as documented.
- **Not called from anywhere yet.** No scheduler/cron exists in `backend/`
  to call this on a timer, and nothing in Flutter calls it either — it's
  live and correct, but currently invoked by nothing. The Nova chat UI
  triggers reasoning manually (the student asks "what should I study
  today") rather than through this layer.
- `staleness_tracker`'s exclusivity constraint is three-way
  (`user_subject_id` / `career_unit_id` / `topic_id`), not the two-way XOR
  an earlier design assumed, since this function needs to reason at topic
  granularity too.

`backend/app` vs `backend/nova` remains architecturally unreconciled — see
[Tech Debt](#tech-debt).

## Nova Schema Tables

All Nova tables have RLS enabled, scoped to `user_id = auth.uid()` (except
`nova_unconfirmed_proposals`, which is read-only for the owner — see
[Proposals Flow](#proposals-flow-confirmation-gate) above).

#### `nova_capacity_log` table

Daily capacity tap per student. One row per student per day, upserted when
the student changes their tap.

```
id                uuid, primary key, default gen_random_uuid()
user_id           uuid, not null, references users.id
capacity          text, not null, check (light|normal|packed)
logged_for_date   date, not null
created_at        timestamptz, not null, default now()
updated_at        timestamptz, not null, default now()
unique            (user_id, logged_for_date)
```

Upsert: `ON CONFLICT (user_id, logged_for_date) DO UPDATE SET capacity = EXCLUDED.capacity, updated_at = now()`.

#### `staleness_tracker` table

Tracks when each unit (academic subject, career unit, or topic) was last
meaningfully worked on.

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

**Constraint:** exactly one of `user_subject_id` / `career_unit_id` /
`topic_id` must be set (three-way XOR).

#### `standing_flags` table

Durable instructions from the student that persist until explicitly removed
or superseded. Example: "always buffer DBMS practicals."

```
id                uuid, primary key, default gen_random_uuid()
user_id           uuid, not null, references users.id
user_subject_id   uuid, nullable, references user_subjects.id
career_unit_id    uuid, nullable, references career_units.id
instruction_text  text, not null
confirmed_at      timestamptz, nullable — null = pending confirmation, inert until confirmed
superseded_at     timestamptz, nullable
supersedes_id     uuid, nullable, references standing_flags.id
source            text, not null, default 'conversation'
created_at        timestamptz, not null, default now()
```

Active flags: `WHERE superseded_at IS NULL AND confirmed_at IS NOT NULL`.
`confirmed_at` is set either by the onboarding seed RPC (`source = 'onboarding'`)
or by the proposals confirm flow — nothing else in `backend/nova` writes this
table today.

#### `situation_flags` table

Temporary context the student tells Nova. Example: "I'm sick this week."

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

#### `nova_history` table

What has worked for this student before, conversation-fed only.

```
id                uuid, primary key, default gen_random_uuid()
user_id           uuid, not null, references users.id
user_subject_id   uuid, nullable, references user_subjects.id
career_unit_id    uuid, nullable, references career_units.id
content           text, not null
confirmed_at      timestamptz, nullable
superseded_at     timestamptz, nullable
supersedes_id     uuid, nullable, references nova_history.id
source            text, not null, default 'conversation'
created_at        timestamptz, not null, default now()
```

#### `career_units` table

```
id                              uuid, primary key, default gen_random_uuid()
user_id                         uuid, not null, references users.id
name                            text, not null
description                     text, nullable
industry_relevance_text         text, nullable
industry_relevance_score        numeric, nullable, check (0–1)
industry_relevance_updated_at   timestamptz, nullable
confirmed_at                    timestamptz, nullable
paused_at                       timestamptz, nullable — null = active, set = paused
source                          text, not null, default 'conversation'
created_at                      timestamptz, not null, default now()
updated_at                      timestamptz, not null, default now()
```

Active units: `WHERE paused_at IS NULL AND confirmed_at IS NOT NULL`.
`industry_relevance_score`/`text` columns exist and are read by the
reasoning layer, but nothing currently writes them — no periodic
industry-relevance lookup job exists yet, so they stay `NULL` in practice.

#### `nova_why_log` table

Audit trail for every plan change.

```
id                  uuid, primary key, default gen_random_uuid()
user_id             uuid, not null, references users.id
entry_type          text, not null, check (full_pass|minor_trigger|one_off_override)
user_subject_id     uuid, nullable, references user_subjects.id
topic_id            uuid, nullable, references topics.id
career_unit_id      uuid, nullable, references career_units.id
facts_snapshot      jsonb, nullable
plan_output         jsonb, nullable
reasoning_summary   text, not null
superseded_at       timestamptz, nullable
supersedes_id       uuid, nullable, references nova_why_log.id
created_at          timestamptz, not null, default now()
```

> **Known-broken today.** The only two insert sites (`reasoning.py`, both
> the full-pass and minor-rerank branches) write columns —
> `triggered_by`, `snapshot_summary`, `reasoning_output`, `passed`,
> `failure_reason` — **none of which exist on this table.** Every insert
> raises and is swallowed by a bare `try/except: logger.error(...)`, so the
> reasoning endpoint still returns a plan to the caller, but the audit trail
> is silently empty on every single call. See [Tech Debt](#tech-debt).

#### `nova_config` table

Generic key/value config store, not fixed columns.

```
id            uuid, primary key, default gen_random_uuid()
user_id       uuid, nullable, references users.id — null = global/default config
key           text, not null
value         jsonb, not null
updated_at    timestamptz, not null, default now()
unique        (user_id, key)
```

Seeded global (`user_id = NULL`) rows: `staleness_days_academic` (14),
`staleness_days_career` (21), `time_left_buckets` (`[7,3,1]`),
`academic_pressure_buckets` (`[10,3]` — seeded but never read; `academic_pressure`
isn't a computed field anywhere yet, see [Tech Debt](#tech-debt)). A
per-student `capacity_hour_mapping` row is written during onboarding — see
[Onboarding Seed Context](#onboarding-seed-context).

## Onboarding Seed Context

The onboarding flow (avatar picker + full profile capture) writes everything
in a single RPC call, `public.save_onboarding_seed_context(...)`, rather than
separate writes per table:

```
Student completes onboarding questionnaire + profile fields (Flutter)
        ↓
save_onboarding_seed_context(p_endgame, p_derailer, p_buffer_pref, p_prep_style,
                              p_career_interests, p_daily_capacity,
                              p_avatar_data, p_full_name, p_roll_number, p_college,
                              p_branch, p_dual_branch, p_academic_year,
                              p_current_semester, p_study_capacity)
        ↓
UPDATE users              — avatar_data, full_name, roll_number, college, branch,
                             dual_branch, academic_year, current_semester, study_capacity
INSERT standing_flags     — endgame / derailer / buffer preference (source = 'onboarding')
INSERT nova_history       — prep style (source = 'onboarding')
INSERT career_units       — one row per career interest, ON CONFLICT (user_id, name)
                             WHERE paused_at IS NULL DO NOTHING
UPSERT nova_config        — capacity_hour_mapping, scoped to this user_id
```

All profile-field parameters are optional (`DEFAULT NULL`) and applied via
`COALESCE`, so re-running onboarding (or a future profile-edit screen calling
the same RPC with a partial payload) only overwrites the fields it's given.
See [FLUTTER.md](FLUTTER.md#profile) for how the Profile page's "Update
Profile & Preferences" re-entry point uses this.

## Nova Facts Snapshot

Derived live at reasoning/chat time by `backend/nova/services/facts_service.py`
(`FactsSnapshot`), not stored as a materialized table. It joins
`user_subject_exams`, `nova_capacity_log`, `staleness_tracker`,
`standing_flags` + `situation_flags`, `nova_history`, `career_units`,
`question_results` + `user_topic_weights`, and `study_plans`. Two spec
fields don't exist yet: `academic_pressure` (no field, no computation
anywhere — the `nova_config` seed row for it is unread) and `fixability`
(only appears as prompt prose, not a distinct computed value).

`FactsState` (`backend/nova/services/facts_state.py`) caches this per user
session and patches it incrementally via the Realtime listener described
under [Nova CLI](#nova-cli-dev-prototype) and mirrored in the API service's
`UserSession`. Fetch→reason is **not atomic**: the cache lock is released
before the reasoning LLM call runs, so a concurrent write could in principle
land in that gap. No scheduler exists yet to make this reachable in
practice, but the code isn't hardened against it either.

## AI Subject Matching (in review, not merged)

A newer feature, committed on a separate branch (`feat/ai-subject-matching`,
commit `6f8f384`) that has **not been merged** into the branch this
documentation set was written against (`feat/nova-proposals`) or into
`master`. Documented here because it's real, reviewable code, not vaporware
— but treat it as upcoming, not shipped, until it lands.

New router, `backend/nova/api/routers/subjects.py`:

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/subjects/{user_id}/add` | AI-assisted match of a free-text subject name against the catalog |
| `POST` | `/subjects/{user_id}/confirm` | Confirm (or correct) the suggested match, enroll the student |

Backed by `services/subject_matcher.py` and `services/subject_enrollment.py`,
with its own schema module (`schemas/subject_match.py`) and a new migration
(`supabase/migrations/20260909080620_add_subject_match_log.sql`). Test
coverage exists (`backend/tests/test_subject_matcher.py`,
`test_subjects_router.py`, `test_subject_match_log_rls.py`) on that branch.
Follows the same no-prefix, no-auth pattern as the rest of `backend/nova`
today — the auth fix in [Tech Debt](#tech-debt) should cover this router too
once the branches converge.

## Prior Audits

Two read-only, point-in-time audit passes live inside `backend/nova/` — they
are **snapshots, not living reference docs**; re-verify a specific claim
against source before relying on it if enough time has passed:

- [`backend/nova/MODEL_TIERS_AUDIT.md`](backend/nova/MODEL_TIERS_AUDIT.md) —
  whether `backend/nova/config/model_tiers.yaml` is actually loaded by any
  code. Verdict: no — it's a design doc the code has never once parsed;
  every place the code matches it (models, key fallback, reasoning-effort
  levels, TPM caps) does so because a human hand-copied the value into a
  Python constant in the same commit, not because anything reads the YAML.
  Includes a concrete minimum-fix plan if this is ever prioritized.
- [`backend/nova/UI_INTEGRATION_PREREQS.md`](backend/nova/UI_INTEGRATION_PREREQS.md) —
  what actually blocks wiring the Nova chat UI to the live backend for real
  users. Verdict: almost entirely the auth gap above, not missing UI or
  schema work — includes a concrete 6-step minimum path to one authenticated
  screen working end to end.

## Tech Debt

- **Nova API has no auth on any of its 5 routes.** `chat`, `facts`,
  `reasoning`, and both proposals endpoints trust a bare `user_id` path
  param with zero verification, and CORS is wide open. This is the actual
  blocker on shipping the Nova chat UI to real users — see
  [UI_INTEGRATION_PREREQS.md](backend/nova/UI_INTEGRATION_PREREQS.md) for
  the exact fix (copy `backend/app/dependencies.py`'s `HTTPBearer` pattern
  into `backend/nova/api/deps.py`, apply it to every route, then attach a
  bearer token in `nova_chat_remote_datasource.dart`).
- **`nova_why_log` insert is broken on every call.** Wrong column names in
  both insert sites in `reasoning.py`; silently swallowed by a bare
  `try/except`. Nova currently has zero working audit trail despite the
  schema existing and being otherwise correct.
- **`model_tiers.yaml` is dead config.** Nothing loads it; every matching
  behavior in code is a hand-synced coincidence, not config-driven. See
  [MODEL_TIERS_AUDIT.md](backend/nova/MODEL_TIERS_AUDIT.md) for the concrete
  fix.
- **`backend/app` vs `backend/nova` — not reconciled.** `POST /nova/trigger/check`
  shipped early as a standalone service (`backend/app`), architecturally
  separate from the newer `backend/nova` (chat/facts/reasoning/proposals).
  Whether the rest of the trigger layer gets folded into `backend/nova`,
  `backend/app` grows to match it, or they stay permanently separate is
  still undecided. Resolve before more Nova backend surface area is built on
  top of either assumption.
- **`academic_pressure` doesn't exist.** Seeded as `nova_config` rows
  (`academic_pressure_buckets`) and referenced in `spec.md`, but there's no
  field in `FactsSnapshot`, no trigger branch for it, and nothing in the
  reasoning prompt weighs it against career/industry relevance the way the
  spec's §2a balancing judgment calls for.
- **No industry-relevance lookup job.** `career_units.industry_relevance_score`/`text`
  are read by the reasoning layer but never written — no periodic web/industry
  lookup exists. Columns are permanently `NULL` in practice today.
- **Fetch→reason isn't atomic; no scheduler exists yet either.** See
  [Nova Facts Snapshot](#nova-facts-snapshot) — currently unreachable in
  practice (nothing runs Nova on a timer yet) but unhardened for when a
  scheduler is added.
- **AI Subject Matching auth gap.** Once `feat/ai-subject-matching` merges,
  its new `/subjects/*` router inherits the same no-auth gap as the rest of
  `backend/nova` — fold it into the same auth fix, don't patch it separately.
- **CLI (`python -m nova`) still has no auth.** Error handling and snapshot
  staleness are fixed (see [Nova CLI](#nova-cli-dev-prototype)); the raw
  `user_id` argv with no identity check is still real. Fine for local dev;
  fix before this pattern carries over into anything student-facing.

## Nova — Still To Build

| Table | Purpose |
|---|---|
| `nova_conversations` | Conversation turn history with Nova |
| `nova_conversations_archive` | Older conversations moved out for performance |
| `nova_plan_outputs` | Ranked plan the student sees — subjects, time budgets, one-line reasons per item |
| `nova_trigger_log` | What fired each reasoning pass and why |
| `nova_industry_relevance_log` | Web lookup history for career unit relevance signals |
| `nova_one_off_overrides` | Today-only overrides, never persisted to schema |

> `nova_why_log`, `nova_config`, and `nova_unconfirmed_proposals` were
> previously listed here but are already live — see
> [Nova Schema Tables](#nova-schema-tables) and
> [Proposals Flow](#proposals-flow-confirmation-gate) above.

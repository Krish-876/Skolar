# Nova UI Integration — Prerequisites (Research Pass)

**Read-only research. No code changed.**

## A note on the premise, and on AUTH_AUDIT.md / AUTH_PREREQS.md

Neither `AUTH_AUDIT.md` nor `AUTH_PREREQS.md` exist anywhere in this repo (checked
the full tree, including `.claude/worktrees/`), and this session's memory store is
empty. They're referenced as if already known, but I have no access to their
content — likely from a prior conversation that didn't persist. Rather than guess
at what they said, everything below is re-derived directly from source (backend
code, Flutter code, actual Supabase migrations, `README.md`, `spec.md`) and
independently verified. Where it matters, I've flagged where the live code
disagrees with `README.md`'s own description of itself.

**The framing "connect Nova to a real UI page for the first time" is false.**
A full Nova chat UI already exists, is wired to a route, and is reachable from
the dashboard today. `README.md` itself is stale on this point — its Folder
Structure section (line ~1245) still lists `lib/features/nova/` as "planned —
Nova conversation + plan display." That's wrong: the real, shipped directory is
`lib/features/nova_chat/`, and it's substantially more built-out than "planned."
The actual gap is almost entirely on the backend (auth, and one broken insert),
not the UI.

---

## 1. Does a Nova UI already exist?

Yes — `lib/features/nova_chat/` is a complete Clean-Architecture feature, not a
stub:

- **Pages:** `nova_chat_page.dart` — full chat screen: glassmorphic background,
  scrollable message list, empty-state greeting (Lottie mascot + time-of-day
  greeting), frosted app bar, input dock, suggestion chips.
- **Widgets:** `nova_chat_app_bar.dart`, `nova_chat_bubble.dart`,
  `nova_chat_input_dock.dart`, `nova_quick_suggestions.dart`,
  `nova_thinking_indicator.dart`, `nova_study_plan_card.dart`,
  `nova_quiz_card.dart`, `nova_flashcard_deck.dart`,
  `nova_practice_problem_card.dart`, `nova_fullscreen_modal.dart` — i.e. a
  renderer already exists for every one of the backend's `NovaResponseType`
  variants (`chat`, `quiz`, `plan`, `flashcard`, `practice_problem`).
- **State:** `nova_chat_provider.dart` (Riverpod `StateNotifier`) +
  `nova_chat_state.dart`.
- **Data layer:** `nova_chat_remote_datasource.dart`, `nova_chat_repository_impl.dart`,
  DTOs (`chat_message_dto.dart`, `study_plan_dto.dart`), domain entities and an
  `INovaChatRepository` interface.

**Routing:** registered at `AppRoutes.novaChat = '/nova-chat'` in
`lib/core/routing/app_routes.dart:81,179`, rendering `NovaChatPage`.

**Reachability:** yes, from real (non-dev) UI. `expandable_progress_card.dart:1303`
(a dashboard widget) does `context.push(AppRoutes.novaChat)`. It's *also* listed
in the root `_DevMenu` (`'Nova AI Chat Window (Dev)'`) reachable at `/`, but that's
in addition to the dashboard entry point, not instead of it.

**Old vs. new datasource:** there is only one datasource,
`nova_chat_remote_datasource.dart`, and it is the "old" bare-Dio one — its own
`Dio` instance, `Content-Type` header only, **no `Authorization` header
anywhere**. It is not calling through the app's `DioHttpClient`
(`lib/core/network/dio_http_client.dart`), which does have an `AuthInterceptor`
and a `setBearerToken()` method — but see §6, that interceptor's token is never
actually set by anything in the app, on any feature, today.

---

## 2. Call shape vs. schema, endpoint by endpoint

| Endpoint | Flutter calls it? | Shape match? |
|---|---|---|
| `POST /chat/{user_id}` | Yes — `sendMessage()`, body `{question}` | **Matches.** `ChatResponse{type,message,data,suggestions}` ↔ `NovaChatResponseDto.fromJson` reads exactly those 4 keys (plus a legacy `answer` fallback for `message`). |
| `GET /chat/{user_id}/suggestions` | Yes — `getInitialSuggestions()` | **Matches.** `{suggestions: [...]}` on both sides. |
| `GET /facts/{user_id}` | Datasource + repository method exist (`getFacts`/`getStudentFacts`) and would decode `FactsResponse{snapshot, patch}` fine as a raw map | **Never called.** Not referenced anywhere in `nova_chat_provider.dart` or any widget. Fully wired, completely unused — dead plumbing, not a bug. |
| `POST /reasoning/{user_id}/run` | Yes — `runReasoning()`, body `{trigger_type}` | **Matches.** `StudyPlanDto.fromJson` reads `json['plan']['items']`, `json['plan']['summary']`, `json['stale']`, `json['note']` — exactly `ReasoningRunResponse{plan:{items,summary}, stale, note, compression_tier}`. `compression_tier` is simply not read by Flutter (harmless — it's an observability field, not needed for rendering). |

No real schema drift found. The one thing worth naming: `userId` is sourced as
`Supabase.instance.client.auth.currentUser?.id ?? 'dev-student-01'`
(`nova_chat_provider.dart:59-64`) — i.e. the UI already tries to use the real
authenticated user, it just also silently falls back to a hardcoded dev ID if
there's no session, and never sends anything proving that ID to the backend.

---

## 3. Which known gaps block first UI connectivity, vs. don't

Verified directly against current source (`backend/nova/api/*`,
`backend/nova/services/*.py`, migrations):

| Gap | Verified? | Blocks first UI wiring? |
|---|---|---|
| **No auth on Nova's 4 routes** (`chat.py` ×2, `facts.py`, `reasoning.py`) | Confirmed — zero `Depends()` auth check anywhere in `backend/nova/api/`. `user_id` is a bare path param; nothing validates the caller owns it. `main.py` CORS is wide open (`allow_origins=["*"]`) with a `TODO` explicitly deferring this until auth lands. | **Yes — this is the actual blocker.** Anyone who knows/guesses a `user_id` can read/act on that student's data. Shippable to real users only after this is closed (see §5 on the ordered list — this is listed as a hard prerequisite, not optional, exactly as the task frames it). |
| **`full_pass` vs `minor_trigger_rerank` effectively aliased** | Confirmed. In `reasoning_service.py`, `trigger_type` affects exactly one thing: `_REASONING_EFFORT[trigger_type]` (`"high"` vs `"medium"`, `reasoning_service.py:34-37`). Compression tiering, prompt building, and model call path are all identical regardless of trigger type — there's no actual "lighter rerank," just the same full pass at a cheaper reasoning-effort setting. | **No.** Doesn't block wiring — the UI only ever sends `trigger_type: 'full_pass'` today (`nova_chat_provider.dart:174`). Cost/quality correctness issue for later. |
| **Trigger layer (`get_nova_triggers` RPC / `/nova/trigger/check`) never called from Flutter** | Confirmed — lives in a separate app (`backend/app/main.py`, port implied by that app, not Nova's), correctly auth-protected via `get_current_user_id` there. Grepped all of `lib/`: no reference to `nova/trigger/check` anywhere. | **No.** This decides *when* to auto-run a reasoning pass (app open, after a test, after a flag confirm). The current UI triggers reasoning manually (user types "what should I study today"), so this system is irrelevant to a first manual-trigger connection. Automation-later item. |
| **Chat never writes facts** | Confirmed — `ask_nova()`/`chat.py` only reads the snapshot and commits the *already-fetched* cache; nothing in the chat path writes to `standing_flags`/`situation_flags`/`nova_history`/etc. | **No.** Doesn't block a UI that displays chat replies; it only means facts don't evolve from conversation yet. Correctness/product-completeness gap, not a connectivity one. |
| **Why-log insert broken** | Confirmed, and worse than "broken" — it will fail on every single call. `reasoning.py`'s inserts use columns `triggered_by`, `snapshot_summary`, `reasoning_output`, `passed`, `failure_reason` — **none of which exist** on `nova_why_log` (see `20260710040155_add_nova_why_log.sql`: real columns are `entry_type` (NOT NULL, check-constrained to `full_pass`/`minor_trigger`/`one_off_override`), `facts_snapshot`, `plan_output`, `reasoning_summary` (NOT NULL), `user_subject_id`/`topic_id`/`career_unit_id`, `superseded_at`, `supersedes_id`). The insert is wrapped in try/except that just logs and swallows the error, so this fails silently on every reasoning call today. | **No.** It's audit logging on the side of the request/response cycle — the reasoning endpoint still returns a plan to the caller even though the insert underneath it always fails. Doesn't block a first UI seeing a plan render. Worth fixing soon after, since right now Nova has *zero* working audit trail despite the schema existing. |
| **`academic_pressure` doesn't exist** | Confirmed — it's a `spec.md` concept and a *config* seed (`academic_pressure_buckets` in `nova_config`, per `README.md`), not a field anywhere in `FactsSnapshot` (`facts_snapshot.py`) or computed anywhere in `facts_service.py`. | **No.** Purely a future reasoning-input refinement; nothing in the current chat/reasoning path references it, so its absence doesn't affect what the UI receives today. |

---

## 4. What the reasoning output actually looks like

Real schema, from `backend/nova/schemas/api.py`:

```python
class PlanItem(BaseModel):
    subject: str
    task: str
    priority: int      # 1 = highest
    reason: str

class StudyPlan(BaseModel):
    items: list[PlanItem] = []
    summary: str | None = None

class ReasoningRunResponse(BaseModel):
    plan: StudyPlan
    stale: bool          # True = yesterday's plan, carried over
    note: str | None      # user-visible explanation when stale/degraded
    compression_tier: int # 1=full, 2=compressed, 3=skeleton — observability only
```

I did **not** run a live local pass to capture a real response — `get_clients()`
(`services/clients.py`) needs live `SUPABASE_URL`/`SUPABASE_KEY`/`GROQ_API_KEY`,
and any real invocation would make a billed Groq call and write into whatever
Supabase project those keys point at. That's a live side-effecting action, not
a read, so it's out of scope for this read-only pass — flagging this rather than
just doing it.

Instead, the concrete shape the model is actually instructed to return is
directly in `chat_service.py`'s `STRUCTURED_FORMAT_INSTRUCTIONS` (for `/chat`)
and `reasoning_service.py`'s `_PLAN_INSTRUCTION` (for `/reasoning/run`) — the
literal JSON shape given to Groq as a prompt constraint is:

```json
{"items": [{"subject": "...", "task": "...", "priority": 1, "reason": "..."}],
 "summary": "..."}
```

`StudyPlan.model_validate(...)` (`reasoning_service.py:339`) enforces this at
parse time — anything Groq returns that doesn't fit is a validation error, not
silently-passed-through garbage. So the schema above is a reliable contract for
UI rendering purposes, live-response capture just wasn't done.

`nova_study_plan_card.dart` already renders exactly `subject`/`task`/`priority`/
`reason` per item, including a priority→color mapping (1=red/high ... 4+=cyan).
No shape gap between what the widget expects and what the schema defines.

---

## 5. Loading / error states

**Reasoning is already treated as slow.** `nova_chat_provider.dart`'s
`generateStudyPlan()` sets `isThinking: true` before calling
`_repository.generateStudyPlan(...)`, and the page shows
`NovaThinkingIndicator` (an animated 3-dot mascot bubble) whenever
`chatState.isThinking` is true — the same indicator is used for both `/chat`
and `/reasoning/run` calls, there's no reasoning-specific spinner variant, but
there also doesn't need to be one; it already covers both call sites.

**App-wide async convention vs. Nova's:** the rest of the app (`dashboard_provider.dart`,
`subjects_provider.dart`, `feed_provider.dart`, `exam_prediction_provider.dart`)
uses Riverpod `FutureProvider`/`AsyncValue` for async state. Nova's provider
instead hand-rolls loading/error as plain booleans + nullable strings on a
`StateNotifier` (`isThinking`, `errorMessage`, `isBackendOnline`). This is a
real, if minor, convention mismatch — worth noting, not worth fixing before a
first connection works, since the hand-rolled version already functions and
migrating it is a refactor with no behavior change.

**401 handling.** `app_routes.dart`'s `GoRouter` redirect only checks
`Supabase.instance.client.auth.currentSession == null` — i.e. "is there a local
Supabase session at all," not "did the last API call return 401." It has no
knowledge of Nova (or any other backend's) HTTP responses. Confirmed no global
401-from-API interceptor exists anywhere (`dio_http_client.dart`'s
`ErrorInterceptor` only forwards 4xx/5xx to the caller, it doesn't redirect).
**So once auth is added to Nova, a 401 will not trigger the global session-expiry
redirect** — it'll surface exactly the way any other Dio error does today: caught
in `nova_chat_remote_datasource.dart`'s `on DioException catch`, turned into a
generic `Exception('Nova Error (...)')`, and shown as an error bubble in the chat
feed (`"**Could not complete request**\n\n..."`, `nova_chat_provider.dart:151`).
That's *survivable* for a first version (nothing crashes), but it will look like
"Nova is broken" rather than "please log in again" — a session-expiry-specific
message is a nice-to-have, not a blocker.

**Generic-Exception-is-enough-for-v1?** Today literally every failure mode —
Groq down, network unreachable, backend 500, (soon) backend 401 — collapses into
one code path: catch, stringify, show as an assistant error bubble. For a first
working connection this is suffient to not crash and to show the user *something*
went wrong. It is **not** distinguishing "Nova couldn't reach the AI" vs "no plan
yet" vs "not enough data yet" as the task's framing anticipates wanting —
those three cases don't exist as distinct code paths anywhere in the backend
either (a failed reasoning pass either returns `stale: true` with a `note`, or
throws a 500 — there's no explicit "not enough data yet" signal at all). Building
those distinctions out is real, separable UI/backend work for after first
connection, not a prerequisite to it.

---

## 6. State management / provider layer

`nova_chat_provider.dart` already has the right *shape* to hook a real,
authenticated backend onto: it has messages, `isThinking`, `errorMessage`,
`isBackendOnline`, `suggestions`, `latestStudyPlan`, optimistic user-message
append, and per-call try/catch that turns failures into inline error bubbles
rather than crashing. **Connecting a real UI does not require building the
provider layer from scratch** — it already exists and already works against
the live (unauthenticated) backend today. The only functional gap on the
Flutter side is: the datasource needs to actually attach a bearer token once
the backend requires one.

Confirmed separately: `DioHttpClient.setBearerToken()` /
`HttpClient.setAuthToken()` exist in `lib/core/network/` but are **never called
anywhere in the app** — grepped for `setBearerToken`/`setAuthToken`/
`access_token`/`currentSession` across all of `lib/`, the only hits are the
interceptor's own definition. No feature in this codebase — not Nova, not mock
tests, not exam prediction — currently attaches a Supabase JWT to an outgoing
Dio request. This is genuinely new work, not "flip a switch that's already
there."

The backend-side pattern to verify that JWT *does* already exist and work,
just in a different app: `backend/app/dependencies.py`'s `get_current_user_id`
(`HTTPBearer` → `supabase.auth.get_user(token)` → returns `user.id` or raises
401), already used for real in `backend/app/main.py`'s
`/nova/trigger/check`. Reusing this exact pattern inside `backend/nova/api/` is
the natural fix — it's proven, not hypothetical.

---

## 7. Design/reference material

None found. No Figma link, reference image, or written UI-direction doc for
the Nova page anywhere in `README.md`, `spec.md`, `docs/` (doesn't exist), or
code comments. The dashboard and auth screens reportedly had reference images
in prior work; Nova has no equivalent on record. The chat page's actual visual
direction (obsidian/glassmorphic, purple accent `#8C5BE8`/`#9153DE`, Lottie
mascot) exists only as already-implemented code in `nova_chat_page.dart` and
its widgets — there is no separate spec for it to be checked against, so "does
the implementation match the intended design" isn't answerable; only "what does
the implementation currently look like" is.

---

## Minimum path: one real screen, one real Nova response, end to end

This assumes the goal is "a logged-in student opens `/nova-chat` from the
dashboard, sends a message or asks for a plan, and gets back a real,
authenticated response" — using what already exists wherever possible.

1. **Backend:** add a `get_current_user_id`-style dependency to
   `backend/nova/api/deps.py` (copy the proven pattern from
   `backend/app/dependencies.py` — `HTTPBearer` + `supabase.auth.get_user(token)`).
2. **Backend:** apply that dependency to all 4 Nova routes
   (`chat.py`'s `chat()` and `get_suggestions()`, `facts.py`'s `get_facts()`,
   `reasoning.py`'s `run_reasoning()`), and use the verified user id instead of
   trusting the `user_id` path param — or at minimum assert they match, so the
   path param can't be used to read/act on someone else's data.
3. **Backend:** narrow `main.py`'s CORS `allow_origins` off `"*"` now that
   requests carry a real credential (the code's own `TODO` already flags this
   as tied to auth landing).
4. **Flutter:** in `nova_chat_remote_datasource.dart`, attach
   `Authorization: Bearer <token>` to every request, sourced from
   `Supabase.instance.client.auth.currentSession?.accessToken` — either wire it
   through the existing (currently-unused) `DioHttpClient.setBearerToken()`, or
   set the header directly on this datasource's own `Dio` instance; either is
   fine, but it needs to be read fresh per-request (not set once), since a
   session can refresh mid-app-lifetime.
5. **Flutter:** remove/gate the `?? 'dev-user-001'` / `'dev-student-01'`
   fallbacks in the datasource and provider now that a missing session should
   mean "don't call Nova," not "silently call it as a fake user."
6. **Verify end to end:** log in as a real user in the running app, open
   `/nova-chat` via the dashboard's existing entry point
   (`expandable_progress_card.dart:1303`), send a message, confirm a real
   authenticated `200` comes back and renders in `NovaChatBubble`; then trigger
   a plan ("what should I study today") and confirm `NovaStudyPlanCard` renders
   a real `/reasoning/run` response.

Nothing else — no new page, no new provider, no new widget, no schema change —
is required to reach "one real screen, one real response." Everything past
step 6 is hardening or correctness, not connectivity.

## Explicitly out of scope for this first pass

Fine to leave exactly as-is until after the above ships, per §3's analysis:

- **Trigger layer automation** (`get_nova_triggers` / `/nova/trigger/check`
  wiring into Flutter) — decides *when* to auto-run reasoning; irrelevant while
  reasoning is user-triggered.
- **Why-log insert** — currently guaranteed to fail on every call (wrong column
  names against the real `nova_why_log` schema) but fails silently behind a
  try/except that doesn't affect the response returned to the UI. Fix once
  real audit trail data is wanted, not before.
- **`academic_pressure`** — doesn't exist as a computed signal anywhere yet;
  purely a future reasoning-quality input.
- **Chat writing facts** — chat stays read-only against the facts snapshot for
  now; conversation-driven fact writes are a separate, larger feature (the
  `/nova/proposals/{id}/confirm` confirmation-gate flow described in
  `README.md`, none of which exists yet in `backend/nova/`).
- **`full_pass`/`minor_trigger_rerank` de-aliasing** — both trigger types
  already work (they just cost/behave near-identically); only matters once
  automated re-ranks are actually being fired at scale.

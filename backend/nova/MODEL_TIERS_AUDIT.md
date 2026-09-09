# model_tiers.yaml — Loaded and Enforced, or Dead Config? (Read-only audit)

**No code changed.**

## 1. Is the file loaded at all?

**No.** Grepped all of `backend/` for `model_tiers`, `yaml.safe_load`, `yaml.load`,
`import yaml`:

- `backend/nova/services/reasoning_service.py:25` — the only hit inside `nova/`,
  and it's a **comment**: `# From model_tiers.yaml reasoning_layer.full_pass`,
  sitting above a hardcoded `ALT_MODEL = "qwen/qwen3.6-27b"` constant.
- `backend/bench/sweep.py:85` and `backend/tests/test_bench_sweep.py:16` do call
  `yaml.safe_load`, but against a benchmark sweep-grid config, unrelated to
  `nova/config/model_tiers.yaml` — no path in either file references
  `model_tiers.yaml`.
- No config-loading utility anywhere in `backend/nova/`, `backend/app/`, or
  `backend/pyq/` reads this path. `nova/services/clients.py` (Nova's only
  client-construction module) does `load_dotenv()` + reads `os.environ[...]`
  directly — no YAML, no config object, nothing.

**Nothing in this codebase ever parses `model_tiers.yaml`.** Everything below is
therefore "would apply if it were loaded" — the actual code was independently
written (and, per §8, hand-copied from the same PR) to *match* several of the
YAML's values, not to *read* them.

---

## 2. The three model-selection call sites

### `ask_nova` — `chat_service.py`

- **Model:** hardcoded. `GROQ_MODEL = "openai/gpt-oss-120b"` (`chat_service.py:14`),
  passed straight into `groq.chat.completions.create(model=model, ...)`
  (`ask_nova`, `chat_service.py:269` / `279`). Matches YAML's `ask_nova[0].model`
  and `[1].model` (both tiers use the same model in the YAML too) by coincidence
  of independent authorship, not by reading it.
- **Fallback:** yes, one real cascade. `ask_nova` (`chat_service.py:257-286`):
  if the estimated token count exceeds `GROQ_TPM_CAP`, it skips primary
  entirely and calls `groq_backup` directly; otherwise it tries `groq` first
  and falls to `groq_backup` only `except Exception`. Both branches call
  `groq_backup` with the **same** `model` value (`GROQ_MODEL`) — matching the
  YAML's `ask_nova` backup tier, which also specifies the same model, just
  `key: backup`. If `groq_backup` is `None` (no `GROQ_API_KEY_2` configured),
  it raises/re-raises with nothing further attempted — there is no cerebras
  fallback in this cascade; cerebras is invoked separately as pure shadow
  (see §4), never as a fallback tier, matching the YAML's own comment ("no
  live tier 3 today — fail gracefully after backup key").
- **`reasoning_effort`:** not applicable — `ask_nova`'s Groq calls never pass a
  `reasoning_effort` kwarg at all (`chat_service.py:269-284` only pass `model`,
  `messages`, `temperature`, `response_format`). This matches the YAML, whose
  `ask_nova` tier entries have no `reasoning_effort` field either — consistent,
  by coincidence, not by design-that-reads-YAML.

### `reasoning_layer.full_pass` / `.minor_trigger_rerank` — `reasoning_service.py`

- **Model:** hardcoded, in two constants: `GROQ_MODEL = "openai/gpt-oss-120b"`
  (primary) and `ALT_MODEL = "qwen/qwen3.6-27b"` (backup) — the latter's
  comment literally says `# From model_tiers.yaml reasoning_layer.full_pass`,
  i.e. a human read the YAML once and typed the value in, rather than the
  program reading it at runtime.
- **Fallback:** yes, a real two-tier cascade in `_try_groq`
  (`reasoning_service.py:314-358`): primary `groq` client + `GROQ_MODEL`
  (retried once without `reasoning_effort` if that kwarg itself throws) →
  on total failure, if `groq_backup` is set, retries once against
  `groq_backup` + `ALT_MODEL`. If that also fails, returns `None` and the
  caller (`run_reasoning_pass`) falls through to `last_good_plan`/empty-plan
  handling (§7). This structurally matches the YAML's two-row lists under
  `full_pass`/`minor_trigger_rerank` (primary model+key, backup model+key) —
  again, matched by hand, not read.
- **`reasoning_effort`:** **Confirmed still a separate hardcoded dict**, exactly
  as the prior audit found — `_REASONING_EFFORT: dict[TriggerType, ReasoningEffort]
  = {"full_pass": "high", "minor_trigger_rerank": "medium"}`
  (`reasoning_service.py:34-37`). It is not sourced from the YAML in any way;
  it happens to agree with the YAML's `reasoning_effort: high` /
  `reasoning_effort: medium` values for the same two trigger types because,
  per §8, both were written in the same commit as two halves of one design,
  never wired together.

### Shadow tier — both files

- `chat_service.py`'s `_shadow_eval_cerebras` (Cerebras) and
  `reasoning_service.py`'s `_try_nemotron_shadow` (OpenRouter/Nemotron) — see
  §4, both real and both fire-and-forget. Neither reads `status: shadow_eval`
  or any other YAML field to decide whether to run; whether they run is
  governed purely by whether the corresponding client object is `None` (i.e.
  whether an API key env var was set — see §5/`clients.py:35-64`).

---

## 3. `cacheable_segment` markers — is anything actually cached?

**No.** Grepped `backend/nova/` for `cache_control`, prompt-caching headers, or
any caching-related parameter on the Groq/OpenAI-compatible client calls used
here (`groq.chat.completions.create`, `openrouter.chat.completions.create`,
`cerebras.chat.completions.create`) — zero hits. Every call site builds the
full message list (system persona + facts snapshot + history + question, or
system persona + plan instruction + snapshot) as one plain list of
`{"role": ..., "content": ...}` dicts and sends the whole thing every time
(`chat_service.py:247-252`, `reasoning_service.py:274-281`). There is no split
between a cached "system_instructions"/"reasoning_instructions" segment and a
dynamic per-call segment anywhere — `cacheable_segment` is a purely descriptive
YAML annotation with no corresponding code path. (The Groq Python SDK as used
here does not receive any cache-related kwarg at all; nothing suggests the SDK
version in `requirements.txt` is even asked to do this.)

---

## 4. `status: shadow_eval` gating — real, but YAML-blind

**Yes, shadow calls really happen** — this part of the design is implemented,
just not driven by the YAML field of the same name:

- **Cerebras** (`ask_nova`'s shadow tier): `_shadow_eval_cerebras`
  (`chat_service.py:90-102`) is called unconditionally inside `ask_nova`
  (line 254) whenever a `cerebras` client was constructed. It checks
  `_estimate_tokens(messages) > CEREBRAS_CONTEXT_CAP` (hardcoded `8192`,
  matching the YAML's `max_context_tokens: 8192` for this tier by
  coincidence) and skips if over. On success or failure, **the result is
  discarded** — the function returns `None` always; nothing logs the
  comparison anywhere, nothing persists it. So "shadow eval" here means
  "fire an extra request nobody looks at," not "fire and log for later
  comparison."
- **Nemotron/OpenRouter** (`reasoning_layer.shadow`): `_try_nemotron_shadow`
  (`reasoning_service.py:361-374`) is called unconditionally in both the
  success and failure branches of `run_reasoning_pass` (lines 409, 413).
  Same pattern: result is computed, then thrown away — no comparison logging,
  no storage.
- Neither call site reads `status: shadow_eval`, `daily_cap`, or anything else
  from the YAML to gate *whether* to fire — gating is entirely "does this
  client object exist," i.e. entirely a function of which API keys happen to
  be set in the environment (see §5).
- **No scheduled/cron infrastructure exists anywhere in `backend/`** to run
  shadow comparisons as a batch job either. Grepped for cron/APScheduler/
  Celery/`schedule.`/`BackgroundScheduler` across all of `backend/` — the only
  hits are false positives inside unrelated benchmark data files
  (`backend/bench/data/TREC/*.jsonl`, `RTE/train.jsonl`), not code. This
  confirms the earlier Skolar-wide audit finding extends to Nova: there is no
  scheduler of any kind, so shadow_eval output isn't being reviewed by
  anything, scheduled or manual, beyond "the request happened and its result
  vanished."

---

## 5. `key: primary`/`key: backup` — is there actually a second Groq key?

**The mechanism exists; whether it's populated is a deployment fact, not a code
fact.** `nova/services/clients.py:16-24` (`get_clients()`) does:

```python
groq_key = os.environ["GROQ_API_KEY"]
groq_key_2 = os.environ.get("GROQ_API_KEY_2")
groq_backup = Groq(api_key=groq_key_2) if groq_key_2 else None
```

So the code genuinely supports two distinct keys and constructs two distinct
`Groq` client objects when both are present — this is not vaporware. The root
`.env` in this repo does define a `GROQ_API_KEY_2=` line as a variable name
(confirmed by listing variable names only — I did not read or need the actual
secret values to answer this). Whether that line currently holds a real,
distinct, working second key in any given deployment isn't something this
audit can or should determine by inspecting the value — that's an operational
fact, not a code fact. **The important code-level finding stands regardless:**
every fallback path in both `chat_service.py` and `reasoning_service.py` is
written correctly to *use* a second key/client if one is configured, and to
degrade gracefully (raise / return `None` / fall to `last_good_plan`) if
`GROQ_API_KEY_2` is unset. So "only one key exists" would make the backup tier
inert, but wouldn't make it broken — it's a soft dependency, not a hard crash.

`CEREBRAS_API_KEY` and `OPENROUTER_API_KEY` are the same shape (both
`.get()`, both optional, both gate the shadow tiers via `None`-checks in
`clients.py:35-64`) — consistent with the YAML's shadow tiers having no
`key: primary`/`backup` split at all (shadow tiers in the YAML don't specify
one, since there's nothing to fail over to for a discarded-result call).

---

## 6. `max_context_tokens` / `max_tokens_per_minute` — enforced?

**Partially, and not the way the YAML implies.** There is a real, general-purpose
rate limiter elsewhere in this codebase — `backend/pyq/rag/llm/client.py`'s
`TokenBudgetLimiter`, a proper sliding-window limiter (`limit`,
`window_seconds`, actually tracks usage over time and sleeps/blocks callers
that would exceed it — see `backend/tests/test_rate_limiter.py`), tunable via
`GROQ_TPM_LIMIT` env var (default `8000`), and every Groq call in `pyq/` is
supposed to route through its shared `create_chat_completion()` so the budget
is enforced across calls (per `backend/pyq/ONBOARDING.md:52`).

**Nova has no equivalent.** `nova/services/clients.py` builds its own raw
`Groq(...)` client directly, never touching `pyq`'s limiter. What Nova has
instead, in both `chat_service.py` and `reasoning_service.py`, is a hardcoded
module-level constant (`GROQ_TPM_CAP = 8000` in both files, plus
`CEREBRAS_CONTEXT_CAP = 8192` in `chat_service.py`) compared **once, per call,
against that single call's own estimated token count** — not a rolling window
tracking cumulative usage across multiple calls/users the way `TokenBudgetLimiter`
does. So:

- `max_context_tokens: 8192` (cerebras, ask_nova shadow tier) — matches
  `CEREBRAS_CONTEXT_CAP`, enforced per-call, gates whether the shadow call
  fires at all.
- `max_tokens_per_minute: 8000` (reasoning_layer, both trigger types) — matches
  `GROQ_TPM_CAP`, but this is misleadingly named on the YAML side: nothing
  about it is actually "per minute" in the code. It's a static per-call size
  cap (triggers snapshot compression tiering in `reasoning_service.py`, or a
  straight `RuntimeError` in `chat_service.py` if over cap and no backup) —
  there is no tracking of cumulative tokens consumed across a rolling 60-second
  window the way the name (and `pyq`'s real `TokenBudgetLimiter`) implies. Two
  concurrent students could each individually pass their own per-call check and
  still blow past a real per-minute account-wide Groq limit; Nova has zero
  protection against that scenario today.

---

## 7. `fallback_behavior: show_last_plan_with_flag` — cascade-triggered or narrower?

**Triggered by the full cascade failing, exactly as the YAML implies** — not by
a single narrower failure. `run_reasoning_pass` (`reasoning_service.py:381-436`):

1. Builds tiered messages, checks the token cap.
2. If under cap: calls `_try_groq(...)`, which itself is the two-key cascade
   from §2 (primary Groq → backup Groq+ALT_MODEL). Only if **both** of those
   fail does `_try_groq` return `None`.
3. Only once `_try_groq` returns `None` does the function fall through to
   `last_good_plan` (`stale=True`, with a user-visible `note`), or an empty
   plan if no `last_good_plan` exists yet.
4. The Nemotron shadow call (§4) always fires alongside, win or lose, but its
   result is never part of this decision — it's discarded either way, so it
   cannot rescue a failed pass even though its output was computed.

So: yes, `show_last_plan_with_flag` is genuinely gated on "primary and backup
both failed" (2 real attempts, both against Groq, different keys/models) — it
is not triggered by a single Groq call failing with nothing else attempted
first. It just isn't gated on the *shadow* tier too, since shadow is
architecturally excluded from ever being a real fallback (by design, per its
name and the YAML's own framing of it as eval-only).

---

## 8. Git history — was the code ever built to read this file?

`model_tiers.yaml`'s history (`git log --follow`):

| Commit | Date | What else it touched |
|---|---|---|
| `15d3529` | 2026-08-23 | Added the file for the first time, alongside `services/chat_service.py`, `clients.py`, `facts_service.py`, `facts_state.py`, `reasoning_service.py` (all under the old `lib/core/ai/nova/` path) — i.e. introduced alongside the services it's meant to govern, not in isolation. |
| `4a8407c` | 2026-08-23 | Pure directory move (`lib/core/ai/nova/` → `backend/nova/`), file content unchanged (`0` diff on the YAML itself). |
| `415c4cf` | 2026-09-03 | The "v3" diff quoted in this task's prompt — added `key: primary`/`backup` rows and the `minor_trigger_rerank` backup entry, **in the same commit** that rewrote `reasoning_service.py` by +403/-31 lines and `chat_service.py` by +260 lines. |

Looking at `415c4cf`'s actual diff for `reasoning_service.py`: the **prior**
version of the file (before this commit) had a large comment block directly
above `_REASONING_EFFORT` explaining the full_pass/minor_trigger_rerank
distinction in prose (referencing "v3 §2/§4" — the same section numbers the
YAML's own header comments use), which this commit *deleted* and replaced with
the current, shorter comment. In the same diff, `ALT_MODEL` was added with the
`# From model_tiers.yaml reasoning_layer.full_pass` comment.

**Conclusion: this file was never independent of the code — it was added
alongside the services, and edited in the same PR that hand-updated those
services' hardcoded constants to match its new content.** This is a deliberate
"design doc that the code is manually kept in sync with," not a forgotten
planning artifact with an accidental resemblance, and not a case of the code
ever having a `yaml.safe_load(...)` call that was later ripped out — grepping
that commit's full diff shows no such removal. The sync has always been by
hand, on purpose, every time either side changes.

---

## Summary table

| YAML field/section | Enforced in code? | Evidence (file:line) | Note |
|---|---|---|---|
| `ask_nova[].model` | Partial | `chat_service.py:14` (`GROQ_MODEL`) | Hardcoded constant, value matches; not read from YAML. |
| `ask_nova[].key: primary/backup` | Partial | `chat_service.py:257-286`; `clients.py:16-24` | Real 2-key cascade exists and works if `GROQ_API_KEY_2` is set; not YAML-driven. |
| `ask_nova[].cacheable_segment` | No | — (no hits anywhere) | Purely descriptive; no message-splitting or caching API param exists. |
| `ask_nova` cerebras tier (`status: shadow_eval`, `max_context_tokens`) | Partial | `chat_service.py:90-102,254` | Shadow call is real and fires; gated by hardcoded `CEREBRAS_CONTEXT_CAP=8192` + key presence, not by reading `status`/`max_context_tokens`. Result always discarded, never logged/compared. |
| `reasoning_layer.full_pass`/`minor_trigger_rerank[].model`, `.key` | Partial | `reasoning_service.py:23-24,314-358` (`GROQ_MODEL`, `ALT_MODEL`) | Real 2-tier cascade, hardcoded constants matching YAML values; `ALT_MODEL`'s comment explicitly cites the YAML as its source — copied by hand. |
| `reasoning_layer.*.reasoning_effort` | No | `reasoning_service.py:34-37` (`_REASONING_EFFORT`) | Separate hardcoded dict; values happen to match YAML's `high`/`medium` because both were authored together, not because one reads the other. |
| `reasoning_layer.*.cacheable_segment` | No | — (no hits anywhere) | Same as ask_nova — descriptive only. |
| `reasoning_layer.*.max_tokens_per_minute: 8000` | Partial, and misleading as-named | `reasoning_service.py:27` (`GROQ_TPM_CAP`); `chat_service.py:17` | Enforced as a **static per-call size cap** (triggers compression tiering / raises), not an actual rolling per-minute budget. `backend/pyq/rag/llm/client.py`'s `TokenBudgetLimiter` is the real per-minute mechanism elsewhere in this codebase; Nova doesn't use it. |
| `reasoning_layer.shadow` (Nemotron/OpenRouter, `status: shadow_eval`, `daily_cap`) | Partial | `reasoning_service.py:361-374` | Shadow call is real, fires unconditionally alongside every pass; gated only by key presence, not by `status`/`daily_cap`. Result discarded, never compared/logged. No scheduler exists anywhere in `backend/` for batch shadow comparisons. |
| `reasoning_layer.fallback_behavior: show_last_plan_with_flag` | Yes (behaviorally) | `reasoning_service.py:381-436` | Genuinely gated on the full primary+backup cascade failing, matching the YAML's intent — just not because the code read this field; it's independently implemented to do the right thing. |

---

## Verdict

**`model_tiers.yaml` is a design document the codebase has never once parsed —
not dead in the sense of "written and abandoned," but dead in the sense of
"the only thing enforcing it is developer discipline."** Every call site that
matches it (models, keys, effort levels, TPM caps, shadow-tier behavior)
matches because a human read this YAML and typed the equivalent Python
constant by hand, in the same commit, sometimes with a comment literally
citing the YAML section as the source — confirmed in git history, not
inferred. Nothing about `cacheable_segment` exists in code at all (no
caching API is used anywhere), and nothing about `status`/`daily_cap`/
`max_tokens_per_minute` is read as configuration — they're re-expressed as
separately-named hardcoded constants that will silently drift out of sync
the moment someone edits one side and forgets the other, which the file's own
structure gives no protection against.

## Minimum fix for the two things that matter most: key failover + reasoning_effort

Not the full cacheable_segment/shadow_eval scope — just closing the biggest
reliability gap (config drift silently breaking failover behavior) with the
smallest change:

1. Add a tiny loader in `nova/services/clients.py` (or a new
   `nova/config/model_tiers.py`): `yaml.safe_load(Path(__file__).parent.parent
   / "config" / "model_tiers.yaml")`, called once at import/startup, no caching
   library needed for a file this small.
2. In `reasoning_service.py`, replace the hardcoded `_REASONING_EFFORT` dict
   with a lookup into the loaded YAML:
   `tiers["reasoning_layer"][trigger_type][0]["reasoning_effort"]` — this alone
   makes the effort mapping config-driven instead of a second hand-maintained
   copy.
3. In both `chat_service.py` and `reasoning_service.py`, replace the
   `GROQ_MODEL`/`ALT_MODEL`/`GROQ_TPM_CAP` module constants with reads from the
   same loaded structure (`tiers["ask_nova"][0]["model"]`,
   `tiers["ask_nova"][1]["model"]`, etc.) — this is what actually makes
   primary/backup failover config-driven: today, changing which model backs up
   which key means editing Python in two files; after this change it means
   editing one YAML file, and the two are no longer able to silently diverge.
4. Explicitly leave `cacheable_segment`, `status: shadow_eval` gating, and
   `daily_cap` unread for now — none of them affect whether a student gets a
   working response today (§3/§4), so wiring them up is separable follow-up
   work, not part of closing the reliability gap.

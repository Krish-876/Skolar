# Spec

**Status:** Concept finalised, ready for implementation<br>
**Core principle:** Nothing about *what to prioritize* is hardcoded. Only the *plumbing* — what triggers re-evaluation, what gets confirmed, what gets logged — is rule-based. The actual judgment (urgency vs. weakness vs. stakes vs. fixability, and — as of this revision — academic vs. career/industry relevance) is reasoned fresh every time, never decided in advance by a fixed formula.

**Scope correction from an earlier draft of this spec:** an earlier version of this document scoped Nova to academic planning only, treating career/industry guidance as a separate, deferred concern. That was wrong. Nova is one mind, not two notebooks — the same instinct that kept academic facts from being split across two memory stores (§ on conversation vs. structured facts) applies here: a student deciding whether to grind DSA or start learning a relevant new skill is one decision, made by one mentor, not a handoff between two systems. Academic prep and career/industry guidance now live in the **same facts schema, same trigger layer, same daily reasoning pass, same time budget.** There is no separate surface for career guidance — it competes for the same hours as exam prep, judged the same way, by the same reasoner, every day.

---

## 1. System Shape

Four layers, each with a single job:

1. **Facts Schema** — the only fixed structure. Everything observable about the student's situation lives here — academic *and* career/industry-relevant, side by side.
2. **Trigger Layer** — cheap, dumb, arithmetic. Runs daily. Decides *whether* something changed enough to warrant re-reasoning. No AI here.
3. **Reasoning Layer** — runs only when triggered. Takes the full facts snapshot, reasons over it like an experienced senior would, outputs a plan. No hardcoded priority rules — including no hardcoded rule that academic always outranks career/industry guidance, or vice versa. That balance is itself a judgment call, made fresh against the actual situation (see §2a).
4. **Output** — ranked focus list + rough time budgets + one-line "why" per item. Not a rigid hour-by-hour schedule (overbearing, breaks on the first late start) and not a bare ranking (offloads all the work back to the student).

A fifth, parallel surface — the **conversation layer** — lets the student talk to Nova for bigger decisions (pause something, protect something, flag falling behind, add a new commitment, ask about a new skill or industry direction). It never bypasses the reasoning layer; it only ever feeds new facts into the schema, then triggers a fresh reasoning pass.

---

## 2. Facts Schema

Per trackable unit (subject, topic-inside-subject, side-project, standing instruction, **career/industry-relevant skill or direction**):

| Field | Description | Source |
|---|---|---|
| `time_left` | Days to exam/deadline. **Not applicable to career/industry units** — see §2a for how those get an urgency-equivalent. | Calendar / academic data |
| `stakes` | Credits, weightage, one-shot vs. recoverable | Academic data |
| `performance` | Score trend | Test/mock data |
| `error_type` | Concept gap / practice gap / careless mistakes (categorical, not just numeric) | Mock test analysis |
| `fixability` | Does this respond fast to more hours, or slowly (rote vs. conceptual)? | **Computed live by the reasoning layer, every pass, from `subject_type` + current `error_type` — not stored.** Unlike `history` or `standing_flags`, this isn't a fact that persists between passes; it's a derived judgment that should always reflect the *current* `error_type`, so storing it risks it going stale the moment `error_type` changes without `fixability` being recomputed alongside it. Treating it as a stored fact (as earlier phrasing implied) was a gap — it had a vague "inferred from X and Y" source with no stated owner, which masked three different possible architectures (trigger-layer classification, compute-once-at-creation, or live-in-reasoner) behind one row that looked structurally identical to the genuinely-stored fields around it. |
| `capacity_today` | Self-reported: light / normal / packed | Student, low-friction tap input |
| `history` | What's worked before for this student | **Conversation-fed only** (see §5) — not auto-inferred in v1 |
| `last_meaningfully_touched` | Timestamp — when this unit last got real plan attention | System-logged |
| `standing_flags` | Durable instructions ("always buffer DBMS practicals"), no expiry unless stated | **Conversation-fed**, confirmed before write |
| `situation_flags` | Holiday, sudden workload, illness, "falling behind," etc. | **Conversation-fed**, confirmed before write |
| `academic_pressure` | **New.** A single, holistic read on how much exam/deadline pressure exists *right now*, across all academic units at once — not per-subject, a whole-picture signal (e.g. "start of semester, nothing due for weeks" vs. "exam season, three subjects within 10 days"). This is the field that lets the reasoner know how much room exists for career/industry focus on a given day. | Derived live by the reasoning layer from the academic units' own `time_left` values — not separately stored, same reasoning as `fixability` |
| `industry_relevance` | **New, career/industry units only.** What's currently worth learning, grounded in real signal — what's gaining traction in the industry right now — filtered through the student's own stated interests, not a generic list. | **Web/industry-awareness lookup, periodic, filtered through conversation-stated interests** — see §2a |
| `relevance_staleness` | **New, career/industry units only.** How long since this skill/direction was last meaningfully engaged with — same staleness mechanism as side-projects (§8), generalized. | System-logged, same mechanism as `last_meaningfully_touched` |

### 2a. How career/industry units get judged without a `time_left`

Academic urgency comes from a real, exact fact: days until something with stakes happens. Career/industry relevance has no equivalent deadline — "learn transformers before they're table stakes" doesn't have a date attached. Forcing a fake deadline onto this would be dishonest and would reintroduce exactly the kind of hardcoded brittleness this spec has avoided everywhere else. Instead:

- **`industry_relevance` is the urgency-equivalent.** It's not a date, it's a periodically-refreshed read on "is this still rising in relevance, or has it leveled off / already become table stakes." This requires Nova to occasionally check real industry/web signal, not just sit on stored data — a genuinely different kind of input from anything else in this schema, and it should be refreshed on its own cadence (weekly is a reasonable default), not on every trigger.
- **`relevance_staleness` is the fallback urgency, same role staleness already plays for side-projects.** A skill the student cares about but hasn't touched in three weeks should start surfacing again, the same way a neglected topic does — staleness generalizes cleanly here; it doesn't need to be invented twice.
- **`academic_pressure` is the field that actually answers your stated requirement** — "Nova has to decide based on the timeline, situation, etc., like if it's the start of semester, focus more on non-academic." Early semester, low `academic_pressure` → the reasoner has real room to allocate meaningful time to career/industry focus, and should. Exam season, high `academic_pressure` → academic dominates almost completely, not because of a hardcoded rule, but because that's what the judgment call actually produces when the gap is that lopsided. The balance is decided fresh every day, by the same reasoning layer, using the same "no hardcoded priorities" philosophy as everything else in this spec — academic doesn't win by default, it wins when the situation actually makes it the right call.
- **Confirmation still applies.** "Nova thinks you should learn X" is exactly the kind of soft, debatable call that shouldn't silently become a standing fact. Same universal confirmation gate as §5 — Nova proposes, the student confirms or pushes back, nothing writes without that.

**Note on `capacity_today`:** deliberately low-friction (tap-based: light/normal/packed → mapped to hour ranges), not a typed number. A typed-number input will stop being filled in accurately after about a week. Calendar integration, if added later, supplements this — it never replaces self-report as the source of truth.

**Resolved decision: output is single-day only, never a multi-day projection.** `time_left` and `capacity_today` operate on different time horizons — one is multi-day, the other is explicitly today-only, since tomorrow's capacity literally cannot be known yet. The reasoner could have tried to project a rough multi-day allocation (e.g. "2hr today, 3hr tomorrow, 1hr the day after"), but that inherits the same brittleness §0 already rejected for rigid hour-by-hour schedules: a 3-day projection that assumes tomorrow is "normal" is wrong the instant tomorrow turns out packed, producing a stale forward-plan nobody told the system to revise. **Decision: `time_left` is used purely as an urgency input that shapes *today's* ranking and budget — it never produces a claim about any day beyond today.** Since the reasoner already re-runs whenever `capacity_today` changes, "today" gets re-decided fresh each day with no new machinery required. This was implicit in every output example through this conversation but never stated as a decision until now.

**Note on `history`:** v1 ships conversation-fed only. Auto-inferring "we gave it 3 hours, score went up, therefore it works" is real causal inference with confounds and isn't designed yet — that's a deliberate v2 deferral, not an oversight.

**Contradiction handling for conversation-fed fields.** Neither `history` nor `standing_flags` originally specified what happens when a new conversation-fed statement contradicts an already-confirmed one for the same field (e.g. week 2: "cramming the night before works for me"; week 6: "actually that backfired, I need more lead time"). **Rule: newer confirmed statements supersede older ones for live reasoning.** The older entry isn't deleted — it remains visible in the why-log's facts-snapshot history for audit purposes — but the reasoning layer only ever reasons over the current value. Same versioning principle already used for decision flags elsewhere in this spec, applied here so it isn't left ambiguous.

---

## 3. Trigger Layer (dumb, daily, no AI)

Fires a reasoning pass if **any** of the following changed since the last check:

- A new test score was added
- `time_left` crossed a meaningful threshold (e.g. ≤7, ≤3, ≤1 days)
- `capacity_today` changed
- **`error_type` changed, even if the raw score barely moved** — a shift from careless-mistakes to concept-gap is a worse signal than the score drop alone suggests, and must be checked as its own field, not folded into a numeric threshold
- **`last_meaningfully_touched` exceeds a staleness threshold for any unit**, regardless of whether anything else about that unit changed — this is what stops a topic or side-project from quietly rotting at rank 4 forever just because nothing about it ever "changes" enough to retrigger on its own
- A new `situation_flag` or `standing_flag` was confirmed and written
- **`industry_relevance` was refreshed and changed meaningfully for a tracked career/industry unit** (e.g. a skill the student cares about just became significantly more or less relevant)
- **`relevance_staleness` exceeds threshold for a career/industry unit** — same mechanism as academic staleness, so a skill the student said they cared about doesn't silently stop surfacing just because nothing about it "changed"
- **`academic_pressure` crossed a meaningful threshold** (e.g. moving from "quiet stretch" to "exam season" or back) — this is the signal that should make the reasoner reconsider how much room exists for career/industry focus, in either direction

If none of the above fired: **no reasoning pass runs, plan stays exactly as it was.**

---

## 4. Reasoning Layer (runs only when triggered)

Receives the full facts snapshot (not a diff) and is asked to weigh, fresh, for this specific moment:

- Urgency (`time_left`)
- Stakes
- Performance and *why* it's weak (`error_type`)
- Fixability in the time actually available
- Real capacity
- History (if any has been told to it)
- Active situation/standing flags
- **Industry relevance and its own staleness, weighed against `academic_pressure`** — how much room exists today for career/industry focus, given where academic urgency currently stands

No field is pre-weighted against another. Urgency doesn't automatically beat weakness; stakes don't automatically beat fixability; **academic urgency doesn't automatically beat career/industry relevance, or vice versa** — that balance is judged fresh, against `academic_pressure`, the same way every other tradeoff in this layer is judged. The output is a judgment call over the facts, the same call an experienced senior would make if asked "where do I put my hours today" — including a senior who'd tell a student in a quiet stretch of semester to spend real time getting ahead on something industry-relevant, not just grinding ahead on syllabus that isn't urgent yet.

**Tradeoff this principle carries, stated rather than assumed away:** "fresh judgment every time" is not the same as "deterministic." The same facts snapshot given to the same model on two different days can produce a different ranking purely from reasoning noise — not because anything in the student's situation changed. A student watching two subjects swap rank for no visible reason will correctly read that as the system being noisy, not thoughtful, and will trust it less. This is a real cost of rejecting hardcoded priority rules, and it wasn't weighed against the benefit anywhere until now.

**Mitigation: stability constraint, not full re-rank from scratch.** The reasoning layer should only be asked to re-judge the relative order of units whose underlying facts actually changed since the last pass. Units with no changed facts keep their prior relative position unless a changed unit's new ranking logically forces a reordering around them (e.g. a unit that just became urgent has to move up, which may shift others down by position, but their *relative order among themselves* shouldn't be re-litigated from zero). This converts "judge fresh every time" from "recompute everything" into "recompute the disputed region only" — which also aligns with §9's minor/major trigger split, rather than fighting it.

**Stronger principle, committed now rather than left fully open:** "what counts as the disputed region" was originally left to be decided during implementation, but that's riskier to leave open than it looked — get it wrong (e.g. re-litigating every unit in the numeric gap a jump creates) and the instability problem this constraint exists to solve comes back, just scoped to "near a big jump" instead of everywhere. **Rule: only units whose ranking depends on a direct comparison with a changed unit are re-litigated. Everything else is shifted in position (to make room), never re-judged.** If Networks jumps from rank 5 to rank 1 because it just became urgent, the units between old-rank-1 and old-rank-4 move down one slot each, but their order *relative to each other* is untouched — only Networks's position relative to whichever unit it now sits above is an actual judgment call. The exact prompt-engineering mechanism for enforcing this is still an implementation detail; the principle itself is not.

**Residual risk this constraint does not cover, named explicitly rather than left implicit: close-call flicker between two genuinely contested units.** The constraint above limits *which* units get re-judged — it does not make the reasoning call itself deterministic. Two units that are close in urgency/stakes (the exact kind of pair the "disputed region" rule says must be compared) can still be ranked differently by the same model on different days, on identical facts, simply because that comparison is a genuine judgment call and LLM reasoning isn't perfectly stable on close calls. This is the scenario a student actually experiences as "this is flaky," and the disputed-region rule above narrows *where* it can happen without reducing it to zero inside that region.

**Fix, scoped specifically to this residual risk: hysteresis on close comparisons.** When two units are within a defined closeness margin of each other on the factors that matter (e.g. days-to-exam within a day or two of each other, similar stakes), the reasoner should default to **keeping yesterday's relative order** rather than re-deciding the comparison fresh — a real re-judgment is only forced once the gap between them widens past the closeness threshold (i.e. something actually changed enough to no longer be a close call). This is narrower and more honest than the disputed-region rule alone: it doesn't claim to eliminate instability everywhere, it specifically targets contested, close rankings that shouldn't be re-litigated daily just because nothing forces them to stay put.

**Separately, make any genuine flicker visible rather than silent, since it can't be fully eliminated.** If two units swap rank with no underlying fact having changed (the residual case hysteresis is meant to suppress but can't guarantee zero of), the output should flag it distinctly from a real, fact-driven change — e.g. a "close call, order may not be stable day-to-day" marker — rather than presenting it identically to a swap that happened for a real reason. This doesn't fix the flicker; it stops the student from reading noise as signal, which is the actual harm being protected against here.

---

## 5. Conversation Layer

Handles:
- New commitments ("I want to start learning X")
- Pausing or protecting a subject
- Admitting falling behind
- Stating standing instructions ("always buffer DBMS practicals")
- Stating history ("cramming Networks the night before actually worked last time")
- **Career/industry direction** ("what should I actually be learning right now," "is X still worth focusing on," stated interests that filter `industry_relevance` lookups) — same confirmation discipline as everything else: Nova proposes a direction, the student confirms or redirects before it's written as a tracked unit
- **One-off overrides — a missing category, added here.** "I hear the plan, I just don't want to do DSA today" is an ordinary thing a student would say, and every other conversational input above was designed to become a durable fact. This one explicitly shouldn't. **Rule: a one-off override affects only the current day's output and writes to neither `history`, `standing_flags`, nor any persistent field.** It's logged in the why-log for traceability (so "why didn't I do DSA on the 14th" still has an answer), but it is never fed back into future reasoning unless the student restates it on a later day. The distinction the conversation layer needs to make explicit, via confirmation, is "is this a pattern going forward, or just today" — defaulting to *not* persisting unless the student's phrasing or an explicit confirmation says otherwise. **Why-log entry type, made explicit:** this produces neither a full-snapshot entry (§7) nor a minor-trigger arithmetic entry (§9's amendment) — it's a third, lighter type: a one-line record of what was declined/overridden and that no facts changed as a result (e.g. "student declined DSA on the 14th — one-off, no schema write, no re-rank"). The why-log has three entry shapes now, not two, and this is stated explicitly so it isn't discovered as a gap later the way the §7/§9 seam was.

**Universal confirmation gate, batched per turn — not per individual write.** Any time the conversation is about to write something to the facts schema — a situation flag, a standing flag, a history entry — Nova confirms before writing. Nothing writes silently. **Correction to earlier framing:** "uniform, no exceptions" was previously stated in a way that implied one confirmation prompt per individual fact. In practice, a single conversational turn often contains several small statements at once ("Networks went better than expected, also I'm a bit behind in DBMS, also remember I always need buffer before practicals") — confirming each separately turns a conversation into a form and is the kind of friction that erodes trust in a conversational assistant fast. **Revised rule: confirmation happens once per turn, as a single batched summary of everything that turn would write** ("sounds like: Networks moves up, DBMS gets flagged as behind, and I'll remember you want practical buffer time going forward — update all of that?"). The safety property is unchanged — nothing writes without explicit confirmation — only the granularity of the confirmation step changes.

**Unconfirmed = inert:** a proposed-but-unconfirmed change has zero effect anywhere — it doesn't show up in today's view, doesn't influence the next reasoning pass, nothing — until the student confirms it.

**Minor deferred item: no expiry policy on old unconfirmed proposals.** Inert-forever is safe in the sense that it can't silently affect the plan, but it isn't the same as having a defined lifecycle — nothing currently states whether old, abandoned proposals (e.g. from a conversation a month ago the student never confirmed) get re-surfaced, expired, or just accumulate indefinitely. Deferred deliberately, same spirit as `history` and why-log retention: worth a simple expiry-or-resurface rule eventually, not urgent enough to block v1.

---

## 6. Concurrency Rule

Background (trigger-fired) reasoning passes and conversation-triggered reasoning passes can overlap in time. Resolution:

- **Conversation always wins.** If a conversation-triggered pass and a background pass conflict, the conversation-triggered output is what's shown as current.
- **Every conversation-triggered pass re-pulls the facts schema fresh at trigger time** — it never reasons over a cached or earlier-in-context state. This matters specifically when a background pass changed something the conversation didn't know about (e.g., a 4am run bumped a subject up; a 9am conversation about something unrelated must reason over the post-4am state, not a stale pre-4am one).
- A superseded pass is **logged as superseded in the why-log, never silently discarded** — but never rendered as the current plan either.
- **In-flight overlap:** if a background pass is still running when a conversation-triggered pass starts, the background pass is left to complete (not cancelled mid-run) and then marked superseded if the conversation pass finishes first. Simpler than building cancellation logic for what should be a rare overlap window; costs one wasted reasoning call in that case, which is an acceptable tradeoff.
- **Scope note: this rule covers reasoning-pass output conflicts. It also extends to write-layer races** — e.g. a confirmed conversation flag and an independently-firing staleness trigger landing on the same unit near-simultaneously, before either has reached the reasoning stage. Same precedence applies: the conversation-confirmed write wins if both land in the same cycle, since it reflects an explicit, just-confirmed student decision rather than a passive arithmetic detection. This was implicit in the original rule's spirit but only ever stated for reasoning-output conflicts — stating it here so it isn't assumed to cover writes by accident.

---

## 7. Why-Log (audit trail)

Every reasoning pass logs, as one unit:

- **The full facts snapshot** the model actually reasoned over (not just what changed)
- The resulting plan/decision
- A one-line reasoning summary

Storing the full snapshot, not just the diff, is what makes this genuinely auditable — if the student asks "why did you skip ML on the 14th" two weeks later, there has to be a real answer pointing at what the model actually knew, not just what it concluded.

**Seam with §9's minor-trigger path — must be closed before implementation.** §9 allows a minor trigger to be resolved via pure arithmetic re-rank with no new LLM call at all. If that path produces a rank change with nothing logging it, the why-log silently stops being complete the moment that path is taken — "why did Networks move from rank 3 to rank 2 yesterday" would have no answer, because the change happened outside the only path §7 was written to cover. **Resolution: every path that changes the visible plan logs an entry, including the no-LLM-call minor path** — for that path, the entry is lighter (what changed, and the arithmetic rule applied, e.g. "single score update, no category shift, re-ranked relative to last full pass") rather than a full facts snapshot, since there's no full reasoning pass to snapshot. The why-log is a record of *every* plan change, not only full reasoning passes — §7 and §9 must be read together, not §7 alone.

**Retention (deliberate v2 deferral, not an oversight):** storing a full facts snapshot per reasoning pass, forever, for every active student, is a real and growing storage cost. v1 ships without a hard answer here, but the intended shape is something like "retained for N weeks, or until superseded passes age past M days" — exact values to be set once real usage shows how often students actually look back. Flagging this now so it's a conscious choice to defer, same spirit as the `history` deferral above, not something that surprises anyone later.

---

## 8. Staleness (cross-cutting primitive)

`last_meaningfully_touched` is tracked per unit, at every granularity — whole subjects, individual topics inside an active subject, side-projects, even standing flags. This single field is what prevents three related failure modes from needing three separate patches:

- A whole track (e.g. the ML side project) going quiet for weeks because nothing about it ever numerically "changes"
- A topic inside an active subject (e.g. DBMS sitting at rank 4 daily, never urgent enough to surface) starving silently
- A `history` entry going stale and being trusted at full weight long after it's no longer representative

One field, checked by the dumb trigger layer, closes all three.

---

## 9. Implementation Footguns (cost/scale — decide now, cheap to prevent)

These don't change the architecture, but left unstated they'll quietly become the slowest or most expensive part of the system once this runs for real users instead of one test account.

- **Batch same-day triggers.** Multiple units crossing a threshold on the same day (realistic during exam season — several subjects hitting "≤7 days" in the same week) must **not** each fire their own full reasoning pass. Same-day triggers batch into a single reasoning pass at the next scheduled check. One-trigger-one-call is the structural version of an unnecessary full re-render on a small state change — avoid it from day one.
- **Trigger severity — minor vs. major (this is the one batching above doesn't fix).** Batching stops three triggers in one day from causing three full passes. It does nothing about the fact that even one well-batched pass is still specified, as written, to re-reason over the *entire* facts snapshot every time — the full-screen-repaint bug, applied to a single call's payload rather than to call count. A single subject's score updating without an `error_type` shift, or a routine staleness trigger on one topic, doesn't plausibly change the relative ranking of five other unrelated subjects, and shouldn't force a full re-decision of all of them.
  - **Minor trigger** (routine field update, no category shift, no threshold crossed into a danger zone): scoped re-evaluation — adjust the affected unit's position relative to the last full pass, rather than re-reasoning everything from zero.
  - **Major trigger** (new exam date entering the picture, an `error_type` category shift, a situation/standing flag confirmed, a unit crossing into a danger zone like ≤3 or ≤1 days where the whole ranking could plausibly reshuffle): forces a full re-pass over the complete snapshot, as originally specified.
  - **Open implementation question, not yet decided:** what "scoped re-evaluation" for a minor trigger actually means technically — a pure arithmetic re-rank using the last full pass as a baseline with no new LLM call at all, versus a cheaper LLM call scoped only to the changed unit and its immediate neighbors in the ranking. Both are valid; deciding between them is an implementation-phase call, not a paper one, and is flagged here rather than guessed at.
- **Forced structured output, hard-capped.** The reasoning layer outputs a strict schema (JSON, not free text), with the "why" field capped at one line, enforced, not just requested. An LLM asked to "reason like an experienced senior" will produce as much explanation as it's allowed to, every time, across every student, every trigger — that cost compounds invisibly at scale if it isn't capped structurally.
- **One query per student per trigger, not one per unit.** "Re-pull facts fresh" (§6) must mean a single batched fetch of that student's full facts row-set, not N individual queries per trackable unit. This is the most common real-world version of the cost problem above — not wrong logic, just unbatched repeated work that's invisible at small scale and expensive at real scale.
- **Scope the daily trigger check to students with something time-relevant happening**, not a blanket job over every account regardless of activity. No reasoning pass should run for a student with nothing changing and nothing upcoming.
- **The staleness check itself must be batched, not just the reasoning-fetch.** The fix above ("one query per student per trigger") only covers facts pulled immediately before a reasoning pass. The daily staleness check (§3/§8) runs on its own cadence, checking `last_meaningfully_touched` across every trackable unit, every day, regardless of whether anything else fires. If implemented as a loop-per-unit instead of one batched query per student, this reintroduces the same N+1 pattern on the trigger side that the fix above only closed on the reasoning side.
- **Batch window for same-day triggers must be explicitly defined, not left as "next scheduled check."** If the only scheduled check is once-daily (e.g. 4am), a trigger landing at 9am waits a full day before the plan reflects it — likely to feel sluggish the first time a student takes a same-day quiz and wonders why their plan didn't move. Decide a concrete cadence now (e.g. one morning batch + one evening batch) rather than discovering this gap from a confused user.
- **Fetch-then-reason must be one atomic read, not "fetch, then maybe something else writes, then reason" — pre-launch requirement, not deferrable.** This is distinct from (and more serious than) the cost framing above: if a second trigger lands in the gap between fetching facts and the reasoning pass consuming them, the model can reason over a half-updated snapshot — some fields current, some one trigger stale — and produce a plan that's wrong, not just slow or delayed. The why-log won't catch this either, since it faithfully logs whatever snapshot it was handed, timing bug or not. Unlike the other items in this section, this one can produce an incorrect plan rather than a merely inefficient one, which is why it's treated as required before launch rather than a scale-later optimization.

---

## 10. Reasoning-Quality Risks (correctness — the dangerous category)

Unlike §9, these aren't about cost — they're about the reasoning layer being confidently wrong in a way that's invisible from the outside, because a fluent wrong answer looks identical to a fluent correct one. This is the most important category to take seriously before shipping, precisely because nothing else in the system (why-log included) catches it — the why-log faithfully records clean reasoning over a corrupted or thin fact, and that record will look fine.

- **Garbage-in is invisible, not loud.** If `error_type` or any other fact is set incorrectly upstream (a flaky mock-test-parsing heuristic, for example), the reasoning layer will build a fluent, confident justification on top of the wrong fact, and nothing about the output will look broken. A buggy UI is visible because it lags or crashes; a wrong-but-fluent explanation is not. **Decision for v1: periodic spot-checks of facts against ground truth** (e.g., manually verify a sample of `error_type` classifications), not just trust in the pipeline that populates them. This is a process commitment, not a code feature — worth stating as one anyway. **Operational specifics, since this is the load-bearing safety mechanism for this entire section and was otherwise the least-specified item in the document: weekly cadence, N=10 randomly sampled `error_type` (and `fixability`, given it's now computed live off the same input) classifications per active student cohort, checked against the actual mock-test data they were derived from. Owner: TBD at implementation, but must be a named person/role before launch, not left informal — a safety mechanism with no owner is the kind of thing that exists on paper and quietly stops happening under real deadline pressure, which defeats its entire purpose.**
- **`error_type` has too little resolution to distinguish real differences.** "Concept gap in DBMS normalization" and "concept gap in DBMS indexing" both collapse to the same category, so the reasoner can't tell a small, fixable misunderstanding from a deep, multi-topic one — not because it's reasoning shallowly, but because the schema didn't give it the resolution to do otherwise. **Deferred to v2, consciously:** richer sub-categorization of `error_type` (e.g., per-topic rather than per-subject) is a real improvement, but adding it now without real usage data to know which sub-categories actually matter risks over-engineering the schema. Flagging it as a known, intentional gap rather than discovering it by accident later.
- **No confidence/data-sufficiency signal in the output.** A thin snapshot (new subject, no history, one data point) currently produces a plan that looks exactly as confident as a well-grounded one. **Decision for v1: add a data-sufficiency field to the structured output** (e.g., `confidence: low/medium/high`, driven by how much real history/performance data exists for the units involved). **Correction to earlier framing in this document:** this was previously called "the single highest-leverage fix in this section" — that overstated it. Confidence-from-data-volume (thin history, few data points) is legitimate and computable from real inputs. But a model that's confidently misjudging `error_type` has no particular reason to correctly flag its own misjudgment — it can't reliably self-assess correctness, only data volume. The actual highest-leverage fix for this section is the spot-check process above; confidence is a useful supporting UI signal for the data-thinness case specifically, not a substitute for catching reasoning errors.
- **No feedback loop on past misjudgments, beyond what `history` already covers.** If the model overweighted the wrong factor last week and the plan didn't help, nothing currently surfaces that except the student noticing and saying so through the conversation layer. **Deferred to v2, consciously, same as `history` itself** (§2) — a real outcome-feedback mechanism requires causal inference (did the plan fail because of bad reasoning, or for unrelated reasons?) that isn't designed yet. Until then, the conversation layer remains the only correction path, and that's an accepted v1 limitation, not an oversight.

---

## 11. Scope Boundary: Single-Student Only (conscious, not by omission)

The reasoning layer only ever sees one student's own facts — never aggregate patterns across other students. This means the system cannot learn something like "students who approach DBMS a certain way tend to do better"; it is permanently bootstrapped from zero for every new student and every subject that student hasn't generated history for yet. **This is a deliberate v1 boundary, stated explicitly so it's a decision rather than something discovered later as a missing feature.** It avoids a cross-student data pipeline and the privacy/consent questions that come with one — both real costs that aren't worth taking on before the single-student core is validated. Revisiting this is a v2+ question, same category of deferral as `history`'s auto-inference.

**This boundary is separate from cold-start output quality, which is a v1 requirement, not deferrable.** A brand-new student with one mock score and no history gets reasoned over by the same machinery as a student six months in — just with thinner inputs. Tagging that as `confidence: low` (§10) labels the output as less trustworthy but doesn't make it more *useful* for that student — and for Skolar specifically, most near-term real users will be in exactly this cold-start state, which makes this more urgent than a generic nice-to-have. **Decision: low-confidence outputs use a deliberately different, more conservative shape** — smaller, more hedged claims, explicit "here's my best guess and why it's uncertain" framing surfaced in the plan text itself rather than buried in a separate confidence field, fewer aggressive reprioritizations on thin evidence. **Trigger condition, made explicit so it isn't wired to the wrong signal later: cold-start mode is gated on data-volume confidence specifically (how much real history/performance data exists for the units involved) — not on reasoning-confidence (how sure the model is its own judgment is correct).** §10 deliberately distinguishes these two meanings of confidence precisely because the model can't reliably self-assess the second one; cold-start mode only ever uses the first, which is a real, computable input (data point count, history entry count), not a self-assessment. This is achievable entirely within the single-student-only design above; it doesn't require reopening that boundary, only designing what the reasoner does differently when it knows it's working from thin data.

---

## 12. Scope Boundary, Corrected: Career/Industry Guidance Is In Scope. General Personal-Life Logistics Is Not.

**Correction to this section's earlier version.** An earlier draft scoped Nova to academic-only and treated career/industry guidance as a deferred, separate concern. That was wrong and has been reversed throughout §1 and §2 — career/industry guidance now lives inside the same facts schema, trigger layer, and daily reasoning pass as academic prep, judged by the same reasoner, competing for the same time budget. The reasoning for the reversal: a student deciding whether to grind DSA or start learning a skill that's rising in industry relevance is one decision, made by one mentor — not a handoff between two separate systems. `academic_pressure` (§2a) is the connective fact that lets the reasoner judge this fresh each day: low pressure (start of semester) means real room for career/industry focus; high pressure (exam season) means academic dominates — not by hardcoded rule, but because that's what the judgment call produces when the gap is genuinely lopsided.

**What remains genuinely out of scope, and why the line is drawn here specifically:** general personal-life logistics — sleep, exercise, social commitments, extracurriculars unrelated to academics or career direction. The reason career/industry guidance could be brought in cleanly while this can't: career/industry relevance has a real urgency-equivalent (§2a's `industry_relevance` + `relevance_staleness`) — something genuinely is or isn't rising in relevance, checkable against real external signal, filtered through the student's stated interests. "Should I exercise today" has no comparable external signal to check against and no deadline-equivalent — it would need an entirely different priority concept invented from scratch, not a generalization of something this schema already has. `capacity_today` remains scoped narrowly, exactly as in the original design: a courtesy input sizing the *combined* academic + career/industry time budget, never a planning surface for the rest of the student's day.

**This is a stated, reasoned boundary, not an oversight.** If general life-logistics planning becomes a real need later, it's a legitimate v2+ direction, but it's a genuinely different design problem — same category of conscious deferral as §11's single-student boundary — rather than something this spec quietly failed to cover.

---

## Open Implementation Details (not specified here, discover by building)

- Exact staleness thresholds per unit type
- Exact hour-range mapping for light/normal/packed capacity taps
- Where this lives in Skolar's schema (new table vs. extension of the existing weakness EMA system) — deferred until the reasoning core above is validated in practice


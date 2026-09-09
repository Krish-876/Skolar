"""
reasoning layer - one full pass/student/day + batched triggers.

Separate hierarchy from ask_nova on purpose: low-frequency, quality over
latency. Groq primary, Nemotron shadow-eval secondary, explicit degrade
path if both are down for a scheduled pass.
"""

import json
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Literal, cast

from groq import Groq
from groq.types.chat import ChatCompletionMessageParam

from nova.prompts.nova_system_prompt import NOVA_SYSTEM_PROMPT
from nova.schemas.api import StudyPlan, TriggerType
from nova.schemas.facts_snapshot import FactsSnapshot
from nova.schemas.reasoning_why_log import DeferredPassEntry

GROQ_MODEL = "openai/gpt-oss-120b"
NEMOTRON_MODEL = "nvidia/nemotron-3-ultra-550b-a55b:free"
# From model_tiers.yaml reasoning_layer.full_pass
ALT_MODEL = "qwen/qwen3.6-27b"
GROQ_TPM_CAP = 8000

# Matches Groq's Completions.create() reasoning_effort overload exactly, so
# mypy can select the right overload instead of falling back to "no match"
# when a plain str is passed in.
ReasoningEffort = Literal["none", "default", "low", "medium", "high"]

_REASONING_EFFORT: dict[TriggerType, ReasoningEffort] = {
    "full_pass": "high",
    "minor_trigger_rerank": "medium",
}


# ---------------------------------------------------------------------------
# Token counting — tiktoken-backed, chars//4 fallback
# ---------------------------------------------------------------------------

try:
    import tiktoken

    def _count_tokens(messages: list[dict], model: str) -> int:
        """Accurate token count using tiktoken.

        Uses the standard OpenAI per-message overhead formula:
          4 tokens per message (role + structure) + 1 reply-priming token.
        Falls back to cl100k_base for any model tiktoken doesn't recognise
        (e.g. OpenRouter slugs like 'openai/gpt-oss-120b', 'qwen/qwen3.6-27b').
        """
        try:
            enc = tiktoken.encoding_for_model(model)
        except KeyError:
            enc = tiktoken.get_encoding("cl100k_base")

        num_tokens = 0
        for message in messages:
            num_tokens += 4  # role + message structure overhead
            for value in message.values():
                if isinstance(value, str):
                    num_tokens += len(enc.encode(value))
        num_tokens += 1  # reply priming token
        return num_tokens

except ImportError:
    def _count_tokens(messages: list[dict], model: str) -> int:  # type: ignore[misc]
        return sum(len(m.get("content", "")) for m in messages) // 4


# ---------------------------------------------------------------------------
# Snapshot compression tiers
# ---------------------------------------------------------------------------

def _pick(row: dict, keys: list[str]) -> dict:
    """Return a copy of `row` with only the specified keys present."""
    return {k: row[k] for k in keys if k in row}


def _compress_snapshot(facts: FactsSnapshot, tier: int) -> dict:
    """Return a dict representation of `facts` at the given compression tier.

    Tier 1 — Full: complete model_dump(), unchanged.
    Tier 2 — Compressed: lists trimmed + projected to decision-critical fields.
              study_plans dropped (redundant with last_good_plan in caller).
              question_results capped at 50 rows. nova_history capped at 5.
    Tier 3 — Skeleton: minimum viable context.
              question_results aggregated by topic_id (not raw rows).
              nova_history dropped. staleness + weights capped at top 10.
    """
    if tier == 1:
        return facts.model_dump(mode="json")

    # Scalars always kept
    base: dict[str, Any] = {
        "snapshot_taken_at": facts.snapshot_taken_at.isoformat(),
        "full_name": facts.full_name,
        "academic_year": facts.academic_year,
        "branch": facts.branch,
        "current_semester": facts.current_semester,
        "dual_branch": facts.dual_branch,
        "study_capacity": facts.study_capacity,
    }

    # ── Always-keep, always-projected ──────────────────────────────────────

    # Flags: highest signal density, never drop. Project to text only.
    base["situation_flags"] = [
        _pick(f, ["flag_text", "expires_at"]) for f in facts.situation_flags
    ]
    base["standing_flags"] = [
        _pick(f, ["instruction_text"]) for f in facts.standing_flags
    ]

    # Capacity: one row max, keep only the value
    base["capacity_today"] = [_pick(c, ["capacity"]) for c in facts.capacity_today]

    # Exams: sort soonest-first, keep scheduling fields
    exams_sorted = sorted(
        facts.user_subject_exams,
        key=lambda x: x.get("exam_date", "9999-12-31"),
    )
    base["user_subject_exams"] = [
        _pick(e, ["exam_type", "exam_date", "user_subject_id"]) for e in exams_sorted
    ]

    # Staleness: sort most-stale-first (ascending touch timestamp)
    staleness_sorted = sorted(
        facts.staleness_tracker,
        key=lambda x: x.get("last_meaningfully_touched", "9999-12-31"),
    )

    # Career units: always keep name + relevance score; drop verbose description
    base["career_units"] = [
        _pick(cu, ["name", "industry_relevance_score"]) for cu in facts.career_units
    ]

    # ── Tier-specific ───────────────────────────────────────────────────────

    if tier == 2:
        # Staleness: all rows, projected
        base["staleness_tracker"] = [
            _pick(s, ["last_meaningfully_touched", "user_subject_id", "topic_id"])
            for s in staleness_sorted
        ]

        # Topic weights: weakest first (low weight = needs attention), top 30
        weights_sorted = sorted(
            facts.user_topic_weights, key=lambda x: x.get("weight", 1.0)
        )
        base["user_topic_weights"] = [
            _pick(w, ["topic", "weight", "topic_id", "subject_id", "custom_subject_id"])
            for w in weights_sorted[:30]
        ]

        # Question results: last 50 rows, key diagnostic fields
        base["question_results"] = [
            _pick(
                qr,
                ["topic_id", "is_correct", "marks_obtained", "marks_available",
                 "error_category", "created_at"],
            )
            for qr in facts.question_results[:50]
        ]

        # Nova history: most recent 5, content only
        base["nova_history"] = [
            _pick(h, ["content"]) for h in facts.nova_history[:5]
        ]

        # Topics: slim cross-reference
        base["topics"] = [
            _pick(t, ["id", "name", "subject_id", "custom_subject_id"])
            for t in facts.topics
        ]

        # User subjects: navigation fields only
        base["user_subjects"] = [
            _pick(us, ["id", "subject_id", "custom_subject_id", "semester"])
            for us in facts.user_subjects
        ]

        # Study plans: dropped — last_good_plan in the caller is the hysteresis source
        base["study_plans"] = []

    elif tier == 3:
        # Staleness: most stale 10 only
        base["staleness_tracker"] = [
            _pick(s, ["user_subject_id", "topic_id", "last_meaningfully_touched"])
            for s in staleness_sorted[:10]
        ]

        # Topic weights: weakest 10 only
        weights_sorted = sorted(
            facts.user_topic_weights, key=lambda x: x.get("weight", 1.0)
        )
        base["user_topic_weights"] = [
            _pick(w, ["topic", "weight", "topic_id"]) for w in weights_sorted[:10]
        ]

        # Question results: aggregated by topic_id (not raw rows)
        agg: dict[str, dict] = defaultdict(
            lambda: {
                "total": 0,
                "correct": 0,
                "marks_obtained": 0.0,
                "marks_available": 0,
                "errors": defaultdict(int),
            }
        )
        for qr in facts.question_results:
            tid = qr.get("topic_id") or "unknown"
            agg[tid]["total"] += 1
            if qr.get("is_correct"):
                agg[tid]["correct"] += 1
            agg[tid]["marks_obtained"] += float(qr.get("marks_obtained") or 0)
            agg[tid]["marks_available"] += int(qr.get("marks_available") or 0)
            ec = qr.get("error_category")
            if ec:
                agg[tid]["errors"][ec] += 1

        base["question_results_aggregated"] = [
            {
                "topic_id": tid,
                "total": v["total"],
                "correct": v["correct"],
                "score_pct": (
                    round(v["marks_obtained"] / v["marks_available"] * 100, 1)
                    if v["marks_available"] else None
                ),
                "dominant_error": (
                    max(v["errors"], key=lambda k: v["errors"][k])
                    if v["errors"] else None
                ),
            }
            for tid, v in agg.items()
        ]

        # Nova history: dropped at skeleton tier
        base["nova_history"] = []

        # Topics: id + name only
        base["topics"] = [_pick(t, ["id", "name"]) for t in facts.topics]

        # User subjects: id + semester only
        base["user_subjects"] = [
            _pick(us, ["id", "semester"]) for us in facts.user_subjects
        ]

        # Study plans: dropped
        base["study_plans"] = []

    return base


# ---------------------------------------------------------------------------
# Message building
# ---------------------------------------------------------------------------

_PLAN_INSTRUCTION = (
    "Generate today's study plan from this student's facts snapshot. "
    "Weigh urgency (exam proximity + staleness), stakes (exam type), "
    "fixability (error_category + topic weight), and industry relevance "
    "(career_units score). Respond with JSON matching exactly this shape, "
    "no extra top-level keys:\n"
    '{"items": [{"subject": str, "task": str, "priority": int, "reason": str}],'
    ' "summary": str | null}'
)


def _build_messages(snapshot_dict: dict) -> list[dict]:
    return [
        {"role": "system", "content": NOVA_SYSTEM_PROMPT},
        {
            "role": "system",
            "content": f"{_PLAN_INSTRUCTION}\n{json.dumps(snapshot_dict, default=str)}",
        },
    ]


def _build_messages_tiered(
    facts: FactsSnapshot, model: str
) -> tuple[list[dict], int]:
    """Try compression tiers 1 → 2 → 3 until messages fit within GROQ_TPM_CAP.

    Returns (messages, tier_used). If even tier 3 is still over cap the caller
    decides whether to proceed anyway or defer — we don't hard-block here."""
    messages: list[dict] = []
    for tier in (1, 2, 3):
        snapshot_dict = _compress_snapshot(facts, tier)
        messages = _build_messages(snapshot_dict)
        if _count_tokens(messages, model) <= GROQ_TPM_CAP:
            return messages, tier
    # tier 3 still over cap — return it anyway, caller will check
    return messages, 3


# ---------------------------------------------------------------------------
# Model call helpers
# ---------------------------------------------------------------------------

@dataclass
class ReasoningResult:
    plan: dict[str, Any]
    stale: bool
    note: str | None = None
    # Observability: which compression tier was used (1=full, 2=compressed, 3=skeleton)
    compression_tier: int = field(default=1)


def _try_groq(
    groq: Groq,
    messages: list[dict],
    model: str,
    reasoning_effort: ReasoningEffort,
    groq_backup: Groq | None = None,
) -> dict | None:
    kwargs = {
        "model": model,
        "messages": cast(list[ChatCompletionMessageParam], messages),
        "temperature": 0.4,
        "response_format": {"type": "json_object"},
    }
    try:
        try:
            # kwargs is built dynamically (temperature/response_format always
            # present, reasoning_effort conditionally included), so mypy widens
            # it to dict[str, object] and can't match Groq's per-model
            # overloads - runtime-safe (this is the retry-without-one-key
            # fallback below), not a real type mismatch.
            resp = groq.chat.completions.create(  # type: ignore[call-overload]
                **kwargs,
                reasoning_effort=reasoning_effort,
            )
        except Exception:
            resp = groq.chat.completions.create(**kwargs)  # type: ignore[call-overload]

        content = resp.choices[0].message.content
        if not content:
            return None
        return StudyPlan.model_validate(json.loads(content)).model_dump()
    except Exception as e:
        print(f"🔴 [Groq Reasoning Error]: {e}")
        if groq_backup is None:
            return None
        try:
            resp = groq_backup.chat.completions.create(
                model=ALT_MODEL,
                messages=cast(list[ChatCompletionMessageParam], messages),
                reasoning_effort=reasoning_effort,
                temperature=0.4,
                response_format={"type": "json_object"},
            )
            content = resp.choices[0].message.content
            if not content:
                return None
            return StudyPlan.model_validate(json.loads(content)).model_dump()
        except Exception as e_backup:
            print(f"🔴 [Groq Backup Reasoning Error]: {e_backup}")
            return None


def _try_nemotron_shadow(openrouter: Any, messages: list[dict]) -> dict | None:
    """Shadow-eval only — not a trusted fallback. Kept isolated so a Nemotron
    failure never blocks the pass."""
    if openrouter is None:
        return None
    try:
        resp = openrouter.chat.completions.create(
            model=NEMOTRON_MODEL,
            messages=cast(list[ChatCompletionMessageParam], messages),
        )
        content = resp.choices[0].message.content
        return json.loads(content) if content else None
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def run_reasoning_pass(
    groq: Groq,
    facts: FactsSnapshot,
    last_good_plan: dict[str, Any] | None,
    trigger_type: TriggerType = "full_pass",
    openrouter: Any = None,
    model: str = GROQ_MODEL,
    user_id: str | None = None,
    log_deferred_pass: Any = None,
    groq_backup: Groq | None = None,
) -> ReasoningResult:
    """One scheduled reasoning pass.

    Compression tiers 1 → 2 → 3 are tried before deferring, so the TPM cap
    triggers smarter prompting rather than an immediate fallback to a stale plan.
    Only hard-defers if even the skeleton prompt (tier 3) cannot fit, or if all
    model tiers fail to return a valid response."""
    messages, tier_used = _build_messages_tiered(facts, model)
    reasoning_effort = _REASONING_EFFORT[trigger_type]
    token_count = _count_tokens(messages, model)
    reason: str | None = None

    if token_count > GROQ_TPM_CAP and tier_used == 3:
        # Even skeleton is too large — extremely unlikely in production
        reason = "tpm_cap_exceeded_all_tiers"
    else:
        plan = _try_groq(groq, messages, model, reasoning_effort, groq_backup=groq_backup)
        if plan is not None:
            _try_nemotron_shadow(openrouter, messages)
            return ReasoningResult(plan=plan, stale=False, compression_tier=tier_used)
        reason = "groq_unavailable"

    _try_nemotron_shadow(openrouter, messages)

    if log_deferred_pass is not None and user_id is not None:
        log_deferred_pass(
            DeferredPassEntry(
                user_id=user_id,
                attempted_at=datetime.now(timezone.utc),
                reason=reason or "unknown",
            )
        )

    if last_good_plan is not None:
        return ReasoningResult(
            plan=last_good_plan,
            stale=True,
            note="Couldn't refresh today's plan, showing yesterday's.",
            compression_tier=tier_used,
        )

    return ReasoningResult(
        plan={"items": [], "summary": "No study plan available yet."},
        stale=True,
        note="Couldn't generate today's plan and no earlier plan exists yet.",
        compression_tier=tier_used,
    )
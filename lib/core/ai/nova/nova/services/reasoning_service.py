"""
reasoning layer - one full pass/student/day + batched triggers.

Separate hierarchy from ask_nova on purpose: low-frequency, quality over
latency. Groq primary, Nemotron shadow-eval secondary, explicit degrade
path if both are down for a scheduled pass..
"""

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, cast

from groq import Groq
from groq.types.chat import ChatCompletionMessageParam

from nova.prompts.nova_system_prompt import NOVA_SYSTEM_PROMPT
from nova.schemas.facts_snapshot import FactsSnapshot
from nova.schemas.reasoning_why_log import DeferredPassEntry

GROQ_MODEL = "openai/gpt-oss-120b"
GROQ_ALT_MODEL = "qwen/qwen3.6-27b"  # named config alt, not an ad hoc runtime pick
NEMOTRON_MODEL = "nvidia/nemotron-3-ultra-550b-a55b:free"
GROQ_TPM_CAP = 8000


@dataclass
class ReasoningResult:
    plan: dict[str, Any]
    stale: bool  # True when this is a carried-over last-good plan, not a fresh pass
    note: str | None = None  # user-visible flag when stale


def _estimate_tokens(messages: list[dict]) -> int:
    return sum(len(m.get("content", "")) for m in messages) // 4


def _build_messages(facts: FactsSnapshot) -> list[dict]:
    return [
        {"role": "system", "content": NOVA_SYSTEM_PROMPT},
        {
            "role": "system",
            "content": (
                "Generate today's study plan from this student's facts "
                "snapshot. Weigh urgency, stakes, fixability, and industry "
                "relevance. Respond with structured JSON only.\n"
                f"{json.dumps(facts.model_dump(), default=str)}"
            ),
        },
    ]


def _try_groq(groq: Groq, messages: list[dict], model: str) -> dict | None:
    try:
        resp = groq.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            reasoning_effort="high",
            temperature=0.4,
            response_format={"type": "json_object"},
        )
        content = resp.choices[0].message.content
        return json.loads(content) if content else None
    except Exception:
        return None


def _try_nemotron_shadow(openrouter, messages: list[dict]) -> dict | None:
    """Shadow-eval only per MD §2/§4 - untested thinkingFormat response shape,
    unconfirmed daily cap. Not promoted to a trusted fallback until both are
    validated. Kept isolated so a Nemotron failure never blocks the pass."""
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


def run_reasoning_pass(
    groq: Groq,
    facts: FactsSnapshot,
    last_good_plan: dict[str, Any] | None,
    openrouter=None,
    model: str = GROQ_MODEL,
    user_id: str | None = None,
    log_deferred_pass=None,
) -> ReasoningResult:
    """One scheduled reasoning pass. Falls back to the last good plan with an
    explicit staleness flag if the primary tier fails - never blank, never a
    silent retry loop (MD §2).

    log_deferred_pass is an optional callable(DeferredPassEntry) -> None -
    left as an injection point since no why-log persistence exists yet.
    Defaults to None so nothing calling this today is affected."""
    messages = _build_messages(facts)
    reason = None

    if _estimate_tokens(messages) > GROQ_TPM_CAP:
        # payload itself is over the TPM gate - this is a deferred pass too,
        # same fallback path as a provider outage
        reason = "tpm_cap_exceeded"
    else:
        plan = _try_groq(groq, messages, model)
        if plan is not None:
            return ReasoningResult(plan=plan, stale=False)
        reason = "groq_unavailable"

    # tier 1 (and its config alt) failed or was skipped - shadow tier is
    # informational only per MD, so it does not become a live fallback here
    _try_nemotron_shadow(openrouter, messages)

    if log_deferred_pass is not None and user_id is not None:
        log_deferred_pass(
            DeferredPassEntry(
                user_id=user_id,
                attempted_at=datetime.now(timezone.utc),
                reason=reason,
            )
        )

    if last_good_plan is not None:
        return ReasoningResult(
            plan=last_good_plan,
            stale=True,
            note="Couldn't refresh today's plan, showing yesterday's.",
        )

    # no prior plan to fall back to - still never silently blank
    return ReasoningResult(
        plan={},
        stale=True,
        note="Couldn't generate today's plan and no earlier plan exists yet.",
    )
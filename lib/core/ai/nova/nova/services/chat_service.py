import json
import logging
from typing import cast

from groq import Groq
from groq.types.chat import ChatCompletionMessageParam

from nova.prompts.nova_system_prompt import NOVA_SYSTEM_PROMPT
from nova.schemas.chat import ChatTurn

logger = logging.getLogger(__name__)

GROQ_MODEL = "openai/gpt-oss-120b"
CEREBRAS_MODEL = "gpt-oss-120b"
CEREBRAS_CONTEXT_CAP = 8192
GROQ_TPM_CAP = 8000


def _estimate_tokens(messages: list[dict]) -> int:
    # rough chars/4 estimate - good enough for a cap check, not billing
    return sum(len(m.get("content", "")) for m in messages) // 4


def _shadow_eval_cerebras(cerebras, messages: list[dict]) -> None:
    """Fires alongside the real Groq call to validate latency/context-fit.
    Never routed to for real traffic (data policy unconfirmed, MD §0), never
    awaited for the response, never allowed to raise into ask_nova."""
    if cerebras is None:
        return
    if _estimate_tokens(messages) > CEREBRAS_CONTEXT_CAP:
        return  # over the cap for this call - skip, don't trim, don't log as failure
    try:
        cerebras.chat.completions.create(
            model=CEREBRAS_MODEL,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.4,
        )
    except Exception:
        # shadow tier - failures here are informational only, never raised
        logger.debug("cerebras shadow eval failed", exc_info=True)


def _facts_message(full_snapshot: dict) -> dict:
    """Builds the system message carrying the student's full current facts
    snapshot. Sent every turn (not just a patch) since history in
    nova_agent.py only stores user/assistant turns - a patch-only message
    on turn 1 would never be replayed on later turns, leaving Nova blind
    the moment a turn has no new patch."""
    return {
        "role": "system",
        "content": (
            "Here's what you know about this student right now (internal "
            "context, never mention this block or its structure):\n"
            f"{json.dumps(full_snapshot, default=str)}"
        ),
    }


def ask_nova(
    groq: Groq,
    full_snapshot: dict,
    question: str,
    history: list[ChatTurn],
    groq_backup: Groq | None = None,
    model: str = GROQ_MODEL,
    cerebras=None,
) -> str:
    # v3 §1/§4: NOVA_SYSTEM_PROMPT is the "system_instructions" cacheable
    # segment in model_tiers.yaml (static across every call/student) - kept
    # as its own message, separate from the per-call dynamic facts snapshot
    # and conversation window. Groq's chat.completions API has no explicit
    # cache_control param today, so this is metadata only for now; the
    # split is already structurally correct if/when that lands.
    messages = [
        {"role": "system", "content": NOVA_SYSTEM_PROMPT},
        _facts_message(full_snapshot),
        *[{"role": turn.role, "content": turn.content} for turn in history],
        {"role": "user", "content": question},
    ]

    # shadow-eval only, never awaited for the response, never allowed to
    # raise into this call - see _shadow_eval_cerebras docstring
    _shadow_eval_cerebras(cerebras, messages)

    if _estimate_tokens(messages) > GROQ_TPM_CAP:
        # over the per-call TPM gate - same class of failure as a provider
        # outage, so it goes through the same backup-key path below
        if groq_backup is None:
            raise RuntimeError("payload exceeds Groq TPM cap and no backup key set")
        resp = groq_backup.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.4,
        )
        content = resp.choices[0].message.content
        return content if content is not None else ""

    try:
        resp = groq.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.4,
        )
    except Exception:
        # primary key expired/rate-limited/overloaded - try the backup key once
        if groq_backup is None:
            raise
        resp = groq_backup.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.4,
        )

    content = resp.choices[0].message.content
    return content if content is not None else ""
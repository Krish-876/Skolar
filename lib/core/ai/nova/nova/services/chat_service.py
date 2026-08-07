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


def _facts_message(patch: dict, is_first_turn: bool) -> dict | None:
    """Builds the system message carrying facts data, or None if there's
    nothing worth sending this turn (no changes, not the first turn)."""
    if is_first_turn:
        return {
            "role": "system",
            "content": (
                "Here's what you know about this student right now (internal "
                "context, never mention this block or its structure):\n"
                f"{json.dumps(patch, default=str)}"
            ),
        }
    if not patch:
        return None
    return {
        "role": "system",
        "content": (
            "Update - these fields changed since your last message, apply "
            "over what you already know (internal context, never mention "
            "this block or its structure):\n"
            f"{json.dumps(patch, default=str)}"
        ),
    }


def ask_nova(
    groq: Groq,
    patch: dict,
    question: str,
    history: list[ChatTurn],
    groq_backup: Groq | None = None,
    model: str = GROQ_MODEL,
) -> str:
    is_first_turn = len(history) == 0
    facts_msg = _facts_message(patch, is_first_turn)

    messages = [
        {"role": "system", "content": NOVA_SYSTEM_PROMPT},
        *([facts_msg] if facts_msg is not None else []),
        *[{"role": turn.role, "content": turn.content} for turn in history],
        {"role": "user", "content": question},
    ]

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
import json
from typing import cast

from groq import Groq
from groq.types.chat import ChatCompletionMessageParam

from nova.prompts.nova_system_prompt import NOVA_SYSTEM_PROMPT
from nova.schemas.chat import ChatTurn
from nova.schemas.facts_snapshot import FactsSnapshot

GROQ_MODEL = "llama-3.3-70b-versatile"


def ask_nova(
    groq: Groq,
    facts: FactsSnapshot,
    question: str,
    history: list[ChatTurn],
) -> str:
    messages = [
        {"role": "system", "content": NOVA_SYSTEM_PROMPT},
        {
            "role": "system",
            "content": (
                "Here's what you know about this student right now (internal "
                "context, never mention this block or its structure):\n"
                f"{json.dumps(facts.model_dump(), default=str)}"
            ),
        },
        *[{"role": turn.role, "content": turn.content} for turn in history],
        {"role": "user", "content": question},
    ]
    resp = groq.chat.completions.create(
        model=GROQ_MODEL,
        messages=cast(list[ChatCompletionMessageParam], messages),
        temperature=0.4,
    )
    content = resp.choices[0].message.content
    return content if content is not None else ""
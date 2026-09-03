import json
import logging
from typing import cast

from groq import Groq
from groq.types.chat import ChatCompletionMessageParam

from nova.prompts.nova_system_prompt import NOVA_SYSTEM_PROMPT
from nova.schemas.api import ChatResponse
from nova.schemas.chat import ChatTurn

logger = logging.getLogger(__name__)

GROQ_MODEL = "openai/gpt-oss-120b"
CEREBRAS_MODEL = "gpt-oss-120b"
CEREBRAS_CONTEXT_CAP = 8192
GROQ_TPM_CAP = 8000

STRUCTURED_FORMAT_INSTRUCTIONS = """
You are Nova, an AI Academic Copilot.
You MUST output valid, parseable JSON matching the following schema:
{
  "type": "chat" | "quiz" | "plan" | "flashcard" | "practice_problem",
  "message": "Your main natural-language markdown response or component introduction",
  "data": null | { ...payload... },
  "suggestions": [
    "Next prompt 1",
    "Next prompt 2",
    "Next prompt 3"
  ]
}

Type & Data Schemas:
1. "chat": General questions, derivations, conceptual explanations. "data" is null.
2. "quiz": When user asks for a quiz, practice test, or self-check. "data" is:
   {
     "title": "Quiz Title",
     "questions": [
       {
         "question": "Question text?",
         "options": ["Option A", "Option B", "Option C", "Option D"],
         "correct_index": 0,
         "explanation": "Why this option is correct."
       }
     ]
   }
3. "plan": When user asks for a study plan, schedule, or daily roadmap. "data" is:
   {
     "summary": "Short daily summary",
     "items": [
       {
         "priority": 1,
         "subject": "Subject Name",
         "task": "Actionable task",
         "reason": "Why this is prioritized"
       }
     ]
   }
4. "flashcard": When user asks for flashcards, key formulas, or rapid revision. "data" is:
   {
     "title": "Flashcard Deck Title",
     "cards": [
       {
         "front": "Term or Formula name",
         "back": "Definition, derivation, or equation expansion",
         "key_takeaway": "Exam tip or common pitfall"
       }
     ]
   }
5. "practice_problem": When user asks for a problem, numerical question, or challenge. "data" is:
   {
     "title": "Problem Title",
     "topic": "Topic Name",
     "difficulty": "Easy" | "Medium" | "Hard" | "Advanced",
     "problem_statement": "Complete problem prompt",
     "hints": ["Hint 1", "Hint 2"],
     "solution": "Step-by-step complete solution and answer"
   }

Suggestions Phrasing Rules:
- Every string in the "suggestions" array MUST be phrased as the student's next prompt/command to Nova (e.g. "Give me more challenging questions on this", "Explain step 2 in detail", "Show a practice problem on this", "Quiz me on this chapter").
- NEVER phrase suggestions as questions from Nova to the student (e.g. do NOT write "Want more questions?" or "Would you like a quiz?").
"""


def _estimate_tokens(messages: list[dict]) -> int:
    return sum(len(m.get("content", "")) for m in messages) // 4


def _shadow_eval_cerebras(cerebras, messages: list[dict]) -> None:
    if cerebras is None:
        return
    if _estimate_tokens(messages) > CEREBRAS_CONTEXT_CAP:
        return
    try:
        cerebras.chat.completions.create(
            model=CEREBRAS_MODEL,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.4,
        )
    except Exception:
        logger.debug("cerebras shadow eval failed", exc_info=True)


def _facts_message(full_snapshot: dict) -> dict:
    return {
        "role": "system",
        "content": (
            "Here's what you know about this student right now (internal "
            "context, never mention this block or its structure):\n"
            f"{json.dumps(full_snapshot, default=str)}"
        ),
    }


def _parse_response_to_chat_response(raw_text: str) -> ChatResponse:
    """Safely parse LLM JSON into a structured ChatResponse, with fallback to type='chat'."""
    trimmed = raw_text.strip()
    if trimmed.startswith("```json"):
        trimmed = trimmed[7:]
    if trimmed.startswith("```"):
        trimmed = trimmed[3:]
    if trimmed.endswith("```"):
        trimmed = trimmed[:-3]
    trimmed = trimmed.strip()

    try:
        parsed = json.loads(trimmed)
        if isinstance(parsed, dict):
            resp_type = parsed.get("type", "chat")
            if resp_type not in ["chat", "quiz", "plan", "flashcard", "practice_problem"]:
                resp_type = "chat"

            message = parsed.get("message") or parsed.get("answer") or ""
            data = parsed.get("data")
            suggestions = parsed.get("suggestions", [])

            if not isinstance(suggestions, list):
                suggestions = []

            # Format suggestions as student prompts
            clean_suggestions = []
            for s in suggestions[:4]:
                s_str = str(s).strip()
                # If model accidentally asked a question like "Want more questions?", rephrase or clean
                if s_str.lower().startswith("want "):
                    s_str = "Give me " + s_str[5:]
                if s_str.lower().startswith("would you like "):
                    s_str = "Give me " + s_str[15:]
                clean_suggestions.append(s_str)

            if not clean_suggestions:
                clean_suggestions = [
                    "Explain this in more detail",
                    "Give me a quick quiz on this topic",
                    "Show a practice problem",
                ]

            return ChatResponse(
                type=resp_type,
                message=message,
                data=data,
                suggestions=clean_suggestions,
            )
    except Exception as e:
        logger.warning(f"Failed to parse structured JSON response: {e}. Falling back to chat.")

    return ChatResponse(
        type="chat",
        message=raw_text,
        data=None,
        suggestions=[
            "Explain this in more detail",
            "Give me a quick quiz on this topic",
            "Show a practice problem",
        ],
    )


def generate_initial_suggestions(
    groq: Groq,
    full_snapshot: dict,
    groq_backup: Groq | None = None,
    model: str = GROQ_MODEL,
) -> list[str]:
    """Generate 4 personalized initial starter prompts based on student facts."""
    prompt = (
        "Based on this student's subjects and academic standing, output a JSON object with a key 'suggestions' "
        "containing exactly 4 concise, high-yield starter prompts the student might send to Nova today. "
        "Each suggestion MUST be written from the student's perspective as a direct command (e.g. 'What should I study today?', 'Quiz me on Operating Systems', 'Explain Quantum Tunneling', 'Give me a practice problem on Calculus'). "
        "Do NOT ask questions to the student."
    )

    messages = [
        {"role": "system", "content": "You are Nova Academic Copilot. Output only JSON."},
        _facts_message(full_snapshot),
        {"role": "user", "content": prompt},
    ]

    try:
        resp = groq.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.5,
            response_format={"type": "json_object"},
        )
        content = resp.choices[0].message.content or "{}"
        parsed = json.loads(content)
        suggestions = parsed.get("suggestions", [])
        if isinstance(suggestions, list) and suggestions:
            return [str(s) for s in suggestions[:4]]
    except Exception as e:
        logger.warning(f"Failed to generate initial suggestions from model: {e}")
        if groq_backup:
            try:
                resp = groq_backup.chat.completions.create(
                    model=model,
                    messages=cast(list[ChatCompletionMessageParam], messages),
                    temperature=0.5,
                    response_format={"type": "json_object"},
                )
                content = resp.choices[0].message.content or "{}"
                parsed = json.loads(content)
                suggestions = parsed.get("suggestions", [])
                if isinstance(suggestions, list) and suggestions:
                    return [str(s) for s in suggestions[:4]]
            except Exception as e_backup:
                logger.warning(f"Failed to generate initial suggestions from backup model: {e_backup}")

    return [
        "What should I study today?",
        "Explain Quantum Tunneling in simple terms",
        "Review my weak areas in Thermodynamics",
        "Give me a 30-minute high-yield practice quiz",
    ]


def ask_nova(
    groq: Groq,
    full_snapshot: dict,
    question: str,
    history: list[ChatTurn],
    groq_backup: Groq | None = None,
    model: str = GROQ_MODEL,
    cerebras=None,
) -> ChatResponse:
    messages = [
        {"role": "system", "content": NOVA_SYSTEM_PROMPT + "\n\n" + STRUCTURED_FORMAT_INSTRUCTIONS},
        _facts_message(full_snapshot),
        *[{"role": turn.role, "content": turn.content} for turn in history],
        {"role": "user", "content": question},
    ]

    _shadow_eval_cerebras(cerebras, messages)

    raw_content = ""
    if _estimate_tokens(messages) > GROQ_TPM_CAP:
        if groq_backup is None:
            raise RuntimeError("payload exceeds Groq TPM cap and no backup key set")
        resp = groq_backup.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.3,
            response_format={"type": "json_object"},
        )
        raw_content = resp.choices[0].message.content or ""
    else:
        try:
            resp = groq.chat.completions.create(
                model=model,
                messages=cast(list[ChatCompletionMessageParam], messages),
                temperature=0.3,
                response_format={"type": "json_object"},
            )
            raw_content = resp.choices[0].message.content or ""
        except Exception:
            if groq_backup is None:
                raise
            resp = groq_backup.chat.completions.create(
                model=model,
                messages=cast(list[ChatCompletionMessageParam], messages),
                temperature=0.3,
                response_format={"type": "json_object"},
            )
            raw_content = resp.choices[0].message.content or ""

    return _parse_response_to_chat_response(raw_content)
"""
On-demand mock paper generation, triggered by the "/paper" CLI command.

Scope (see conflicts flagged in nova_agent.py's /paper branch):
- Reads "users" and "subjects" directly, does NOT check user_subjects or
  custom_subjects - the list shown may not exactly match what the student
  is actually enrolled in.
- Generation prompt is a plain placeholder - no real mark-calibration or
  exam-type-pooling instructions exist anywhere in this codebase yet.
- Nothing here writes to "questions" or "published_tests" - purely
  ephemeral, printed to the terminal and discarded.
"""

from typing import Any, cast

from groq import Groq
from groq.types.chat import ChatCompletionMessageParam
from supabase import Client

PAPER_SYSTEM_PROMPT = "You generate mock exam papers for students. Output the paper only, no commentary."


def get_subjects_for_student(supabase: Client, user_id: str) -> list[dict]:
    """Returns subjects matching the student's academic_year, current
    semester, and campus - queried directly against "subjects", not
    "user_subjects" (see conflict #1). Empty list if the student's own
    profile is missing any of the three fields needed to run this query."""
    user_rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("users")
            .select("current_semester, academic_year, campus_id")
            .eq("id", user_id)
            .limit(1)
            .execute()
            .data
        ),
    )
    if not user_rows:
        return []

    profile = user_rows[0]
    current_semester = profile.get("current_semester")
    academic_year = profile.get("academic_year")
    campus_id = profile.get("campus_id")
    if current_semester is None or academic_year is None or campus_id is None:
        return []

    subject_rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("subjects")
            .select("id, name, short_name")
            .eq("academic_year", academic_year)
            .eq("semester", current_semester)
            .eq("campus_id", campus_id)
            .execute()
            .data
        ),
    )
    return subject_rows


def generate_paper(
    groq: Groq,
    subject_name: str,
    groq_backup: Groq | None = None,
    model: str = "openai/gpt-oss-120b",
) -> str:
    """Generates a mock paper for subject_name via Groq, on-demand only.
    Same primary/backup retry pattern as ask_nova in chat_service.py: one
    retry on groq_backup if the primary call raises, re-raise if no
    backup is configured."""
    prompt = (
        f"Generate a mock exam paper for the subject '{subject_name}'. "
        "Include a mix of question types and mark values. Format it "
        "clearly with question numbers."
    )
    messages = [
        {"role": "system", "content": PAPER_SYSTEM_PROMPT},
        {"role": "user", "content": prompt},
    ]

    try:
        resp = groq.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.4,
        )
    except Exception:
        if groq_backup is None:
            raise
        resp = groq_backup.chat.completions.create(
            model=model,
            messages=cast(list[ChatCompletionMessageParam], messages),
            temperature=0.4,
        )

    content = resp.choices[0].message.content
    return content if content is not None else ""
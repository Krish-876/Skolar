"""
AI-assisted subject matching for the onboarding/subject-add flow.

A student's free-text subject name ("OS", "opersting systms") rarely
exact-matches a row in `subjects`/`custom_subjects`. This asks the model to
semantically resolve it against the candidate pool for the student's
institution/campus instead of relying on exact/fuzzy string matching alone.

Uses the same model as ask_nova's primary tier (model_tiers.yaml's cheapest
available tier - see nova/services/chat_service.py's GROQ_MODEL) rather than
the more expensive reasoning_layer tiers, since this is a single-shot
classification call, not multi-factor reasoning.

Never guesses: below SUBJECT_MATCH_CONFIDENCE_THRESHOLD the caller gets back
a no-match/disambiguation result instead of an auto-selected id, and never
creates a custom_subjects row itself - that's subject_enrollment.py's job,
triggered only by an explicit student action downstream.
"""

import json
import logging
from typing import Any, cast

from groq import Groq
from groq.types.chat import ChatCompletionMessageParam
from supabase import Client

from nova.schemas.subject_match import (
    LLMMatchResult,
    MatchCandidateOut,
    MatchResult,
    SubjectCandidate,
)

logger = logging.getLogger(__name__)

# Matches ask_nova's primary tier in model_tiers.yaml - the cheapest tier
# available, appropriate for a single-shot classification call.
GROQ_MODEL = "openai/gpt-oss-120b"

# Named threshold, not a magic number inline: below this, a model-reported
# match is downgraded to no-match rather than trusted at face value, even if
# the model itself claimed match=true.
SUBJECT_MATCH_CONFIDENCE_THRESHOLD = 0.75

# A disambiguation response only ever offers the top few options - more than
# that stops being useful "did you mean?" UI.
MAX_DISAMBIGUATION_CANDIDATES = 2

_MATCH_INSTRUCTIONS = """You are matching a student's free-text subject name against a list of \
candidate subjects already on file for their institution/campus. Typos \
("opersting systms"), abbreviations ("OS" -> "Operating Systems"), and \
different phrasings of the same course should all resolve to the correct \
candidate when you are genuinely confident. If nothing in the list \
plausibly matches, or several candidates are equally plausible, do not \
guess.

Respond with ONLY valid JSON in exactly one of these two shapes:
{"match": true, "subject_id": "<candidate id>", "confidence": 0.0-1.0}
{"match": false, "candidates": [{"id": "<candidate id>", "name": "<candidate name>", "confidence": 0.0-1.0}]}

Rules:
- "subject_id" and every candidate "id" MUST be one of the candidate ids given below - never invent an id.
- For the second shape, include at most the top 2 plausible candidates, most likely first. Return an empty candidates array if genuinely nothing is close.
- confidence is your own calibrated probability that the id is the correct match for the student's text, not a rounded/discrete score.
"""


def _get_candidate_pool(
    supabase: Client, institution_id: str, campus_id: str | None
) -> dict[str, SubjectCandidate]:
    """Institution+campus-scoped `subjects` rows plus every institution-scoped
    `custom_subjects` row - two students independently mistyping the same
    missing course should converge on the same custom_subjects row instead
    of the model (or the student) creating a second duplicate."""
    subjects_query = supabase.table("subjects").select("id, name, short_name").eq(
        "institution_id", institution_id
    )
    if campus_id:
        subjects_query = subjects_query.eq("campus_id", campus_id)
    subjects_rows = cast(list[dict[str, Any]], subjects_query.execute().data or [])

    custom_rows = cast(
        list[dict[str, Any]],
        supabase.table("custom_subjects")
        .select("id, name, course_code")
        .eq("institution_id", institution_id)
        .execute()
        .data
        or [],
    )

    pool: dict[str, SubjectCandidate] = {}
    for row in subjects_rows:
        pool[row["id"]] = SubjectCandidate(
            id=row["id"], name=row["name"], short_name=row.get("short_name"), source="subject"
        )
    for row in custom_rows:
        pool[row["id"]] = SubjectCandidate(
            id=row["id"], name=row["name"], short_name=row.get("course_code"), source="custom_subject"
        )
    return pool


def _build_messages(raw_text: str, candidate_pool: dict[str, SubjectCandidate]) -> list[dict]:
    candidate_payload = [
        {"id": c.id, "name": c.name, "short_name": c.short_name} for c in candidate_pool.values()
    ]
    return [
        {"role": "system", "content": _MATCH_INSTRUCTIONS},
        {
            "role": "user",
            "content": (
                f"Student typed: {raw_text!r}\n\nCandidates:\n{json.dumps(candidate_payload)}"
            ),
        },
    ]


def _call_groq(
    groq: Groq, messages: list[dict], model: str, groq_backup: Groq | None
) -> LLMMatchResult | None:
    kwargs = {
        "model": model,
        "messages": cast(list[ChatCompletionMessageParam], messages),
        "temperature": 0.1,
        "response_format": {"type": "json_object"},
    }
    try:
        resp = groq.chat.completions.create(**kwargs)
        content = resp.choices[0].message.content
        if not content:
            return None
        return LLMMatchResult.model_validate(json.loads(content))
    except Exception as e:
        logger.warning(f"Subject match Groq call failed: {e}")
        if groq_backup is None:
            return None
        try:
            resp = groq_backup.chat.completions.create(**kwargs)
            content = resp.choices[0].message.content
            if not content:
                return None
            return LLMMatchResult.model_validate(json.loads(content))
        except Exception as e_backup:
            logger.warning(f"Subject match Groq backup call failed: {e_backup}")
            return None


def _log_match_attempt(
    supabase: Client,
    user_id: str,
    institution_id: str,
    campus_id: str | None,
    query_text: str,
    candidates: list[MatchCandidateOut],
) -> str:
    status = "disambiguation" if candidates else "no_match"
    row = cast(
        dict[str, Any],
        supabase.table("subject_match_log")
        .insert(
            {
                "user_id": user_id,
                "institution_id": institution_id,
                "campus_id": campus_id,
                "query_text": query_text,
                "status": status,
                "candidates": [c.model_dump() for c in candidates],
            }
        )
        .execute()
        .data[0],
    )
    return row["id"]


def match_subject(
    groq: Groq,
    supabase: Client,
    user_id: str,
    raw_text: str,
    institution_id: str,
    campus_id: str | None,
    groq_backup: Groq | None = None,
    model: str = GROQ_MODEL,
) -> MatchResult:
    """Semantically matches `raw_text` against the institution/campus
    candidate pool. Never writes to subjects/custom_subjects/user_subjects -
    a confident match only returns the id for the caller to act on; anything
    below threshold is logged to subject_match_log and returned as
    candidates for the frontend to show a disambiguation prompt."""
    pool = _get_candidate_pool(supabase, institution_id, campus_id)
    if not pool:
        log_id = _log_match_attempt(supabase, user_id, institution_id, campus_id, raw_text, [])
        return MatchResult(matched=False, candidates=[], match_log_id=log_id)

    messages = _build_messages(raw_text, pool)
    llm_result = _call_groq(groq, messages, model, groq_backup)

    if (
        llm_result is not None
        and llm_result.match
        and llm_result.subject_id in pool
        and llm_result.confidence >= SUBJECT_MATCH_CONFIDENCE_THRESHOLD
    ):
        matched = pool[llm_result.subject_id]
        return MatchResult(
            matched=True,
            subject_id=matched.id,
            source=matched.source,
            confidence=llm_result.confidence,
        )

    # No confident match - either the model said so directly, said match=true
    # but under threshold, or the call failed outright (never guess on a
    # model outage). Filter candidates to ids that actually exist in the
    # pool - the model must not invent one - and cap at the top few.
    raw_candidates = llm_result.candidates if llm_result is not None else []
    enriched = [
        MatchCandidateOut(id=c.id, name=pool[c.id].name, confidence=c.confidence, source=pool[c.id].source)
        for c in raw_candidates
        if c.id in pool
    ][:MAX_DISAMBIGUATION_CANDIDATES]

    log_id = _log_match_attempt(supabase, user_id, institution_id, campus_id, raw_text, enriched)
    return MatchResult(matched=False, candidates=enriched, match_log_id=log_id)

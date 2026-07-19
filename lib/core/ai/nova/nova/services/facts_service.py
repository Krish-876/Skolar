"""
Pulls a student's live facts snapshot from Supabase.

Read-only. Never writes, never mutates staleness/history. Mirrors the join
Nova's reasoning pass uses at trigger time.
"""

from datetime import datetime, timezone
from typing import Any, cast

from supabase import Client

from nova.schemas.facts_snapshot import FactsSnapshot


def _user_subject_ids(supabase: Client, user_id: str) -> list[str]:
    rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("user_subjects")
            .select("id")
            .eq("user_id", user_id)
            .execute()
            .data
        ),
    )
    return [row["id"] for row in rows]


def _test_attempt_ids(supabase: Client, user_id: str) -> list[str]:
    rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("test_attempts")
            .select("id")
            .eq("user_id", user_id)
            .execute()
            .data
        ),
    )
    return [row["id"] for row in rows]


def _fetch_exams(supabase: Client, user_subject_ids: list[str]) -> list[dict]:
    if not user_subject_ids:
        return []
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("user_subject_exams")
        .select("*")
        .in_("user_subject_id", user_subject_ids)
        .execute()
        .data
        ),
    )


def _fetch_capacity_today(supabase: Client, user_id: str) -> list[dict]:
    today = datetime.now(timezone.utc).date().isoformat()
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("nova_capacity_log")
        .select("*")
        .eq("user_id", user_id)
        .eq("logged_for_date", today)
        .execute()
        .data
        ),
    )


def _fetch_staleness(supabase: Client, user_id: str) -> list[dict]:
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("staleness_tracker")
        .select("*")
        .eq("user_id", user_id)
        .execute()
        .data
        ),
    )


def _fetch_confirmed_active(supabase: Client, table: str, user_id: str) -> list[dict]:
    """Shared shape: standing_flags, situation_flags, nova_history all use
    confirmed_at / superseded_at the same way."""
    return cast(
        list[dict[str, Any]],
        (
            supabase.table(table)
        .select("*")
        .eq("user_id", user_id)
        .is_("superseded_at", "null")
        .not_.is_("confirmed_at", "null")
        .execute()
        .data
        ),
    )


def _fetch_career_units(supabase: Client, user_id: str) -> list[dict]:
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("career_units")
        .select("*")
        .eq("user_id", user_id)
        .is_("paused_at", "null")
        .not_.is_("confirmed_at", "null")
        .execute()
        .data
        ),
    )


def _fetch_question_results(supabase: Client, test_attempt_ids: list[str]) -> list[dict]:
    if not test_attempt_ids:
        return []
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("question_results")
        .select("*")
        .in_("attempt_id", test_attempt_ids)
        .order("created_at", desc=True)
        .limit(200)
        .execute()
        .data
        ),
    )


def _fetch_topic_weights(supabase: Client, user_id: str) -> list[dict]:
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("user_topic_weights")
        .select("*")
        .eq("user_id", user_id)
        .execute()
        .data
        ),
    )


def _fetch_study_plans(supabase: Client, user_id: str) -> list[dict]:
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("study_plans")
        .select("*")
        .eq("user_id", user_id)
        .eq("is_active", True)
        .execute()
        .data
        ),
    )


def _collect_topic_ids(*row_lists: list[dict]) -> list[str]:
    """Pulls unique topic_id values out of any snapshot rows that carry one."""
    ids: set[str] = set()
    for rows in row_lists:
        for row in rows:
            topic_id = row.get("topic_id")
            if topic_id:
                ids.add(topic_id)
    return list(ids)


def _fetch_topics(supabase: Client, topic_ids: list[str]) -> list[dict]:
    if not topic_ids:
        return []
    return cast(
        list[dict[str, Any]],
        (
            supabase.table("topics")
        .select("*")
        .in_("id", topic_ids)
        .execute()
        .data
        ),
    )


def get_facts_snapshot(supabase: Client, user_id: str) -> FactsSnapshot:
    user_subject_ids = _user_subject_ids(supabase, user_id)
    test_attempt_ids = _test_attempt_ids(supabase, user_id)

    question_results = _fetch_question_results(supabase, test_attempt_ids)
    staleness_tracker = _fetch_staleness(supabase, user_id)
    user_topic_weights = _fetch_topic_weights(supabase, user_id)

    topic_ids = _collect_topic_ids(
        question_results, staleness_tracker, user_topic_weights
    )

    return FactsSnapshot(
        snapshot_taken_at=datetime.now(timezone.utc),
        user_subject_exams=_fetch_exams(supabase, user_subject_ids),
        capacity_today=_fetch_capacity_today(supabase, user_id),
        staleness_tracker=staleness_tracker,
        standing_flags=_fetch_confirmed_active(supabase, "standing_flags", user_id),
        situation_flags=_fetch_confirmed_active(supabase, "situation_flags", user_id),
        nova_history=_fetch_confirmed_active(supabase, "nova_history", user_id),
        career_units=_fetch_career_units(supabase, user_id),
        question_results=question_results,
        user_topic_weights=user_topic_weights,
        study_plans=_fetch_study_plans(supabase, user_id),
        topics=_fetch_topics(supabase, topic_ids),
    )
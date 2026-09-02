"""
Pulls a student's live facts snapshot from Supabase.

Read-only. Never writes, never mutates staleness/history. Mirrors the join
Nova's reasoning pass uses at trigger time.
"""

from datetime import datetime, timezone
from typing import Any, cast

from nova.schemas.facts_snapshot import FactsSnapshot
from supabase import Client


def _fetch_own_profile(supabase: Client, user_id: str) -> dict:
    try:
        rows = cast(
            list[dict[str, Any]],
            (
                supabase.table("users")
                .select("full_name, academic_year, branch, current_semester, dual_branch, study_capacity")
                .eq("id", user_id)
                .limit(1)
                .execute()
                .data
            ),
        )
        return rows[0] if rows else {}
    except Exception:
        return {}


def _user_subject_ids(supabase: Client, user_id: str) -> list[str]:
    try:
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
    except Exception:
        return []


def _test_attempt_ids(supabase: Client, user_id: str) -> list[str]:
    try:
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
    except Exception:
        return []


def _fetch_exams(supabase: Client, user_subject_ids: list[str]) -> list[dict]:
    if not user_subject_ids:
        return []
    try:
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
    except Exception:
        return []


def _fetch_capacity_today(supabase: Client, user_id: str) -> list[dict]:
    today = datetime.now(timezone.utc).date().isoformat()
    try:
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
    except Exception:
        return []


def _fetch_staleness(supabase: Client, user_id: str) -> list[dict]:
    try:
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
    except Exception:
        return []


def _fetch_confirmed_active(supabase: Client, table: str, user_id: str) -> list[dict]:
    try:
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
    except Exception:
        return []


def _fetch_career_units(supabase: Client, user_id: str) -> list[dict]:
    try:
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
    except Exception:
        return []


def _fetch_question_results(supabase: Client, test_attempt_ids: list[str]) -> list[dict]:
    if not test_attempt_ids:
        return []
    try:
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
    except Exception:
        return []


def _fetch_topic_weights(supabase: Client, user_id: str) -> list[dict]:
    try:
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
    except Exception:
        return []


def _fetch_study_plans(supabase: Client, user_id: str) -> list[dict]:
    try:
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
    except Exception:
        return []


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
    try:
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
    except Exception:
        return []


def get_facts_snapshot(supabase: Client, user_id: str) -> FactsSnapshot:
    profile = _fetch_own_profile(supabase, user_id)
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
        full_name=profile.get("full_name"),
        academic_year=profile.get("academic_year"),
        branch=profile.get("branch"),
        current_semester=profile.get("current_semester"),
        dual_branch=profile.get("dual_branch"),
        study_capacity=profile.get("study_capacity"),
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


def fetch_partial(
    supabase: Client, user_id: str, dirty_tables: set[str], table_to_fields: dict
) -> dict:
    """Re-fetches only the tables flagged dirty, returns a dict of
    {snapshot_field: new_value} suitable for FactsSnapshot.model_copy(update=...).
    Cheaper than get_facts_snapshot when only a slice changed."""
    patch: dict[str, Any] = {}

    if "users" in dirty_tables:
        profile = _fetch_own_profile(supabase, user_id)
        for field in table_to_fields["users"]:
            patch[field] = profile.get(field)

    if "user_subject_exams" in dirty_tables:
        patch["user_subject_exams"] = _fetch_exams(
            supabase, _user_subject_ids(supabase, user_id)
        )

    if "nova_capacity_log" in dirty_tables:
        patch["capacity_today"] = _fetch_capacity_today(supabase, user_id)

    if "staleness_tracker" in dirty_tables:
        patch["staleness_tracker"] = _fetch_staleness(supabase, user_id)

    if "standing_flags" in dirty_tables:
        patch["standing_flags"] = _fetch_confirmed_active(supabase, "standing_flags", user_id)

    if "situation_flags" in dirty_tables:
        patch["situation_flags"] = _fetch_confirmed_active(supabase, "situation_flags", user_id)

    if "nova_history" in dirty_tables:
        patch["nova_history"] = _fetch_confirmed_active(supabase, "nova_history", user_id)

    if "career_units" in dirty_tables:
        patch["career_units"] = _fetch_career_units(supabase, user_id)

    if "question_results" in dirty_tables or "test_attempts" in dirty_tables:
        patch["question_results"] = _fetch_question_results(
            supabase, _test_attempt_ids(supabase, user_id)
        )

    if "user_topic_weights" in dirty_tables:
        patch["user_topic_weights"] = _fetch_topic_weights(supabase, user_id)

    if "study_plans" in dirty_tables:
        patch["study_plans"] = _fetch_study_plans(supabase, user_id)

    # topics is derived from whatever rows carry a topic_id - only worth
    # refreshing if one of those source tables actually changed
    topic_sources = {"question_results", "staleness_tracker", "user_topic_weights"}
    if dirty_tables & topic_sources:
        sources = [
            patch.get("question_results", []),
            patch.get("staleness_tracker", []),
            patch.get("user_topic_weights", []),
        ]
        topic_ids = _collect_topic_ids(*sources)
        if topic_ids:
            patch["topics"] = _fetch_topics(supabase, topic_ids)

    return patch
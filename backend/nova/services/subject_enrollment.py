"""
Writes user_subjects/custom_subjects rows once a subject match is resolved -
either automatically (a confident subject_matcher.match_subject() result) or
explicitly by the student (a disambiguation choice, or "none of these").

subject_matcher.py only ever reads and logs; this is the one place that
actually creates rows, and it's only ever called in response to a specific,
already-decided outcome - never speculatively.
"""

from datetime import datetime, timezone
from typing import Any, cast

from supabase import Client

from nova.schemas.subject_match import UserSubjectOut


def verify_subject_belongs_to_institution(
    supabase: Client, subject_id: str, institution_id: str, campus_id: str | None
) -> None:
    """Confirms subject_id is a real `subjects` catalog row scoped to the
    caller's own institution (and campus, when the caller has one - same
    treatment of a null campus_id as _get_candidate_pool, so a student is
    never able to confirm a subject they'd never have been shown as a
    candidate). subject_id is client-supplied input, so without this a
    caller could enroll in (or probe the existence of) another
    institution's/campus's catalog subject."""
    query = (
        supabase.table("subjects")
        .select("id")
        .eq("id", subject_id)
        .eq("institution_id", institution_id)
    )
    if campus_id:
        query = query.eq("campus_id", campus_id)
    rows = cast(list[dict[str, Any]], query.limit(1).execute().data or [])
    if not rows:
        raise ValueError("Subject not found for your institution.")


def verify_custom_subject_belongs_to_institution(
    supabase: Client, custom_subject_id: str, institution_id: str
) -> None:
    """Same check as verify_subject_belongs_to_institution, for the
    custom_subjects table - custom_subject_id is likewise client-supplied."""
    rows = cast(
        list[dict[str, Any]],
        supabase.table("custom_subjects")
        .select("id")
        .eq("id", custom_subject_id)
        .eq("institution_id", institution_id)
        .limit(1)
        .execute()
        .data
        or [],
    )
    if not rows:
        raise ValueError("Custom subject not found for your institution.")


def create_custom_subject(
    supabase: Client, institution_id: str, course_code: str, name: str, credits: int | None
) -> str:
    """Upsert on (institution_id, course_code) - the same unique constraint
    the existing Flutter custom-subject flow relies on (see
    SubjectsRemoteDataSource.addCustomSubject) - so two students independently
    creating a custom subject for the same course converge on one row."""
    row = cast(
        dict[str, Any],
        supabase.table("custom_subjects")
        .upsert(
            {
                "institution_id": institution_id,
                "course_code": course_code,
                "name": name,
                "credits": credits,
            },
            on_conflict="institution_id,course_code",
        )
        .execute()
        .data[0],
    )
    return row["id"]


def create_user_subject(
    supabase: Client,
    user_id: str,
    semester: str,
    subject_id: str | None = None,
    custom_subject_id: str | None = None,
) -> UserSubjectOut:
    if (subject_id is None) == (custom_subject_id is None):
        raise ValueError("Exactly one of subject_id or custom_subject_id must be set.")

    row = cast(
        dict[str, Any],
        supabase.table("user_subjects")
        .insert(
            {
                "user_id": user_id,
                "subject_id": subject_id,
                "custom_subject_id": custom_subject_id,
                "semester": semester,
            }
        )
        .execute()
        .data[0],
    )
    return UserSubjectOut(
        id=row["id"],
        subject_id=row.get("subject_id"),
        custom_subject_id=row.get("custom_subject_id"),
        semester=row["semester"],
    )


def resolve_match_log(
    supabase: Client,
    match_log_id: str,
    user_id: str,
    subject_id: str | None,
    custom_subject_id: str | None,
) -> None:
    """Records how a logged no-match/disambiguation attempt was ultimately
    resolved, so subject_match_log stays queryable end-to-end rather than
    just capturing the dead-end. Scoped to the owning user's own row - a
    match_log_id is client-echoed input, so without this an authenticated
    student could resolve (or discover the existence of) another student's
    log row just by guessing/enumerating ids."""
    result = (
        supabase.table("subject_match_log")
        .update(
            {
                "resolved_subject_id": subject_id,
                "resolved_custom_subject_id": custom_subject_id,
                "resolved_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        .eq("id", match_log_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not result.data:
        raise ValueError(f"No subject_match_log row {match_log_id} for this student")

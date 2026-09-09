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
    subject_id: str | None,
    custom_subject_id: str | None,
) -> None:
    """Records how a logged no-match/disambiguation attempt was ultimately
    resolved, so subject_match_log stays queryable end-to-end rather than
    just capturing the dead-end."""
    supabase.table("subject_match_log").update(
        {
            "resolved_subject_id": subject_id,
            "resolved_custom_subject_id": custom_subject_id,
            "resolved_at": datetime.now(timezone.utc).isoformat(),
        }
    ).eq("id", match_log_id).execute()

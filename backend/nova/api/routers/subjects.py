from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client

from nova.api.deps import get_current_user_id, get_supabase_and_groq
from nova.schemas.subject_match import (
    AddSubjectRequest,
    AddSubjectResponse,
    ConfirmSubjectRequest,
    ConfirmSubjectResponse,
)
from nova.services.subject_enrollment import (
    create_custom_subject,
    create_user_subject,
    resolve_match_log,
    verify_custom_subject_belongs_to_institution,
    verify_subject_belongs_to_institution,
)
from nova.services.subject_matcher import get_user_institution_and_campus, match_subject

router = APIRouter(tags=["subjects"])


def _require_institution(supabase: Client, user_id: str) -> tuple[str, str | None]:
    """Shared guard for both endpoints that derive institution/campus
    scoping server-side from the caller's own profile rather than trusting
    the request body - a profile with no institution set yet can't add or
    confirm a subject."""
    institution_id, campus_id = get_user_institution_and_campus(supabase, user_id)
    if not institution_id:
        raise HTTPException(
            status_code=400,
            detail="Your profile has no institution set - update your profile before adding subjects.",
        )
    return institution_id, campus_id


@router.post("/subjects/{user_id}/add", response_model=AddSubjectResponse)
def add_subject(
    user_id: str,
    req: AddSubjectRequest,
    clients: tuple = Depends(get_supabase_and_groq),
    authenticated_user_id: str = Depends(get_current_user_id),
):
    if authenticated_user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot act on another user's subjects.",
        )

    supabase, groq, groq_backup = clients

    institution_id, campus_id = _require_institution(supabase, user_id)

    result = match_subject(
        groq,
        supabase,
        user_id,
        req.query,
        institution_id,
        campus_id,
        groq_backup,
    )

    if result.matched:
        user_subject = create_user_subject(
            supabase,
            user_id,
            req.semester,
            subject_id=result.subject_id if result.source == "subject" else None,
            custom_subject_id=result.subject_id if result.source == "custom_subject" else None,
        )
        return AddSubjectResponse(status="matched", user_subject=user_subject)

    return AddSubjectResponse(
        status="needs_confirmation",
        candidates=result.candidates,
        match_log_id=result.match_log_id,
    )


@router.post("/subjects/{user_id}/confirm", response_model=ConfirmSubjectResponse)
def confirm_subject(
    user_id: str,
    req: ConfirmSubjectRequest,
    clients: tuple = Depends(get_supabase_and_groq),
    authenticated_user_id: str = Depends(get_current_user_id),
):
    if authenticated_user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot act on another user's subjects.",
        )

    supabase, _groq, _groq_backup = clients

    chosen = [req.subject_id, req.custom_subject_id, req.new_custom_subject]
    if sum(c is not None for c in chosen) != 1:
        raise HTTPException(
            status_code=400,
            detail="Exactly one of subject_id, custom_subject_id, or new_custom_subject must be set.",
        )

    institution_id, campus_id = _require_institution(supabase, user_id)

    subject_id = req.subject_id
    custom_subject_id = req.custom_subject_id

    # All ownership/existence validation for this request - institution
    # scoping on subject_id/custom_subject_id, and (below) match_log
    # ownership - must run before create_user_subject. A 404/400 here must
    # never leave an orphaned user_subjects row behind (user_subjects has no
    # uniqueness constraint on user/subject/semester, so a client retry
    # after a partial failure could also duplicate it).
    try:
        if req.subject_id is not None:
            verify_subject_belongs_to_institution(supabase, req.subject_id, institution_id, campus_id)
        if req.custom_subject_id is not None:
            verify_custom_subject_belongs_to_institution(supabase, req.custom_subject_id, institution_id)
        if req.new_custom_subject is not None:
            custom_subject_id = create_custom_subject(
                supabase,
                institution_id,
                req.new_custom_subject.course_code,
                req.new_custom_subject.name,
                req.new_custom_subject.credits,
            )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    if req.match_log_id:
        try:
            resolve_match_log(supabase, req.match_log_id, user_id, subject_id, custom_subject_id)
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))

    user_subject = create_user_subject(
        supabase, user_id, req.semester, subject_id=subject_id, custom_subject_id=custom_subject_id
    )

    return ConfirmSubjectResponse(user_subject=user_subject)

from fastapi import APIRouter, Depends, HTTPException, status

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
)
from nova.services.subject_matcher import match_subject

router = APIRouter(tags=["subjects"])


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

    result = match_subject(
        groq,
        supabase,
        user_id,
        req.query,
        req.institution_id,
        req.campus_id,
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

    subject_id = req.subject_id
    custom_subject_id = req.custom_subject_id

    if req.new_custom_subject is not None:
        custom_subject_id = create_custom_subject(
            supabase,
            req.new_custom_subject.institution_id,
            req.new_custom_subject.course_code,
            req.new_custom_subject.name,
            req.new_custom_subject.credits,
        )

    user_subject = create_user_subject(
        supabase, user_id, req.semester, subject_id=subject_id, custom_subject_id=custom_subject_id
    )

    if req.match_log_id:
        resolve_match_log(supabase, req.match_log_id, subject_id, custom_subject_id)

    return ConfirmSubjectResponse(user_subject=user_subject)

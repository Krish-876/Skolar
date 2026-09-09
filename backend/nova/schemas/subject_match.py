from typing import Literal

from pydantic import BaseModel, Field

CandidateSource = Literal["subject", "custom_subject"]


class SubjectCandidate(BaseModel):
    """One row from the institution/campus candidate pool sent to the model."""

    id: str
    name: str
    short_name: str | None = None
    source: CandidateSource


class LLMCandidate(BaseModel):
    id: str
    name: str
    confidence: float = Field(ge=0.0, le=1.0)


class LLMMatchResult(BaseModel):
    """Exact structured-output contract the model must return - either shape,
    never both. `match`/`subject_id`/`confidence` only apply to the first
    shape; `candidates` only to the second."""

    match: bool
    subject_id: str | None = None
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    candidates: list[LLMCandidate] = Field(default_factory=list)


class MatchCandidateOut(BaseModel):
    """A disambiguation candidate, enriched with `source` for the frontend
    ("did you mean X?" needs to know which table X would resolve to)."""

    id: str
    name: str
    confidence: float
    source: CandidateSource


class MatchResult(BaseModel):
    """What subject_matcher.match_subject() returns to its caller."""

    matched: bool
    subject_id: str | None = None
    source: CandidateSource | None = None
    confidence: float = 0.0
    candidates: list[MatchCandidateOut] = Field(default_factory=list)
    match_log_id: str | None = Field(
        default=None,
        description="Set only when matched=False - the subject_match_log row this attempt was logged to.",
    )


# --- API request/response models ------------------------------------------


class AddSubjectRequest(BaseModel):
    query: str = Field(..., description="Raw subject name/text as typed by the student.")
    semester: str = Field(..., description="Semester label to store on the resulting user_subjects row.")


class UserSubjectOut(BaseModel):
    id: str
    subject_id: str | None = None
    custom_subject_id: str | None = None
    semester: str


class AddSubjectResponse(BaseModel):
    status: Literal["matched", "needs_confirmation"]
    user_subject: UserSubjectOut | None = Field(
        default=None, description="Set only when status='matched' - the row created for the auto-selected subject."
    )
    candidates: list[MatchCandidateOut] = Field(
        default_factory=list,
        description="Set only when status='needs_confirmation' - top 1-2 candidates for a 'did you mean?' prompt. Empty if genuinely nothing close.",
    )
    match_log_id: str | None = None


class NewCustomSubject(BaseModel):
    course_code: str
    name: str
    credits: int | None = None


class ConfirmSubjectRequest(BaseModel):
    """Finalizes a user_subjects row after the student resolves a
    needs_confirmation response - either by picking a returned candidate
    (subject_id / custom_subject_id) or by explicitly saying "none of
    these" (new_custom_subject). Exactly one of the three must be set."""

    semester: str
    match_log_id: str | None = Field(
        default=None, description="Echoed back from AddSubjectResponse, if any, so the log row can record how it was resolved."
    )
    subject_id: str | None = None
    custom_subject_id: str | None = None
    new_custom_subject: NewCustomSubject | None = None


class ConfirmSubjectResponse(BaseModel):
    user_subject: UserSubjectOut

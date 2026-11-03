from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

ProposalKind = Literal["standing_flag", "situation_flag", "nova_history", "career_unit"]


class RawProposedFact(BaseModel):
    """What the model is allowed to emit inline in a chat response, before
    any DB write happens. Subject/career-unit references are names, not
    ids - the model never gets to name a row id directly, the caller
    resolves these against the already-fetched snapshot."""

    kind: ProposalKind
    text: str = Field(..., description="instruction_text / flag_text / content / career unit name.")
    description: str | None = Field(
        default=None, description="career_unit only - short description of the interest."
    )
    target_subject_name: str | None = Field(
        default=None, description="Subject/custom-subject name this attaches to, if any."
    )
    target_career_unit_name: str | None = Field(
        default=None, description="Career unit name this attaches to, if any (not used for kind=career_unit itself)."
    )


class ProposalSummary(BaseModel):
    """What the client actually renders as a confirm/reject chip."""

    id: str
    turn_id: str
    kind: ProposalKind
    summary: str


class PendingProposal(ProposalSummary):
    created_at: datetime


class ProposalResolution(BaseModel):
    id: str
    kind: ProposalKind
    status: Literal["confirmed", "rejected"]
    resulting_row_id: str | None = None

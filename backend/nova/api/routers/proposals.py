from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from nova.api.deps import get_session, get_supabase_and_groq, require_same_user
from nova.schemas.proposals import PendingProposal, ProposalResolution
from nova.services.proposals_service import (
    PROPOSAL_KIND_TO_DIRTY_TABLE,
    confirm_proposal,
    confirm_turn,
    get_pending_proposals,
    reject_proposal,
    reject_turn,
)

router = APIRouter(tags=["proposals"])


class PendingProposalsResponse(BaseModel):
    proposals: list[PendingProposal]


class TurnResolutionResponse(BaseModel):
    resolutions: list[ProposalResolution]


def _mark_dirty(session, resolution: ProposalResolution) -> None:
    """Confirming a proposal writes a table facts_service reads (§8's
    staleness-tracked units live there too) - the session's cached
    FactsState has no other way to learn this happened, since Realtime
    isn't wired into the API app's sessions (separate, pre-existing gap)."""
    table = PROPOSAL_KIND_TO_DIRTY_TABLE[resolution.kind]
    session.facts_state.mark_dirty(table)


@router.get("/proposals/{user_id}/pending", response_model=PendingProposalsResponse)
def list_pending_proposals(
    user_id: str,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    supabase, _groq, _groq_backup = clients
    return PendingProposalsResponse(proposals=get_pending_proposals(supabase, user_id))


@router.post("/proposals/{user_id}/{proposal_id}/confirm", response_model=ProposalResolution)
def confirm_one(
    user_id: str,
    proposal_id: str,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    supabase, _groq, _groq_backup = clients
    session = get_session(user_id, clients)
    try:
        resolution = confirm_proposal(supabase, user_id, proposal_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    _mark_dirty(session, resolution)
    return resolution


@router.post("/proposals/{user_id}/{proposal_id}/reject", response_model=ProposalResolution)
def reject_one(
    user_id: str,
    proposal_id: str,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    supabase, _groq, _groq_backup = clients
    try:
        return reject_proposal(supabase, user_id, proposal_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/proposals/{user_id}/turn/{turn_id}/confirm", response_model=TurnResolutionResponse)
def confirm_whole_turn(
    user_id: str,
    turn_id: str,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    supabase, _groq, _groq_backup = clients
    session = get_session(user_id, clients)
    resolutions = confirm_turn(supabase, user_id, turn_id)
    for resolution in resolutions:
        _mark_dirty(session, resolution)
    return TurnResolutionResponse(resolutions=resolutions)


@router.post("/proposals/{user_id}/turn/{turn_id}/reject", response_model=TurnResolutionResponse)
def reject_whole_turn(
    user_id: str,
    turn_id: str,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    supabase, _groq, _groq_backup = clients
    return TurnResolutionResponse(resolutions=reject_turn(supabase, user_id, turn_id))

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from nova.api.deps import get_session, get_supabase_and_groq, require_same_user
from nova.schemas.api import ChatRequest, ChatResponse
from nova.schemas.chat import ChatTurn
from nova.services.chat_service import GROQ_MODEL, ask_nova, generate_initial_suggestions
from nova.services.proposals_service import create_proposals

router = APIRouter(tags=["chat"])
logger = logging.getLogger(__name__)


class SuggestionsResponse(BaseModel):
    suggestions: list[str] = Field(default_factory=list, description="4 personalized initial prompt starters.")


@router.get("/chat/{user_id}/suggestions", response_model=SuggestionsResponse)
def get_suggestions(
    user_id: str,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    _supabase, groq, groq_backup = clients
    session = get_session(user_id, clients)

    try:
        snapshot, _patch = session.facts_state.get()
        suggestions = generate_initial_suggestions(
            groq,
            snapshot.model_dump(),
            groq_backup,
            GROQ_MODEL,
        )
        return SuggestionsResponse(suggestions=suggestions)
    except Exception:
        logger.exception("Suggestions generation failed.")
        return SuggestionsResponse(
            suggestions=[
                "What should I study today?",
                "Explain Quantum Tunneling in simple terms",
                "Review my weak areas in Thermodynamics",
                "Give me a 30-minute high-yield practice quiz",
            ]
        )


@router.post("/chat/{user_id}", response_model=ChatResponse)
def chat(
    user_id: str,
    req: ChatRequest,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    supabase, groq, groq_backup = clients
    session = get_session(user_id, clients)

    try:
        snapshot, _patch = session.facts_state.get()
        snapshot_dict = snapshot.model_dump()
        parsed = ask_nova(
            groq,
            snapshot_dict,
            req.question,
            session.history,
            groq_backup,
            GROQ_MODEL,
        )
        response = parsed.response

        if parsed.raw_proposed_facts:
            turn_id = str(uuid.uuid4())
            proposals = create_proposals(
                supabase, user_id, turn_id, parsed.raw_proposed_facts, snapshot_dict
            )
            response.turn_id = turn_id
            response.pending_proposals = proposals
    except Exception:
        session.facts_state.rollback()
        logger.exception("Chat generation failed.")
        raise HTTPException(status_code=500, detail="Unable to process the request.")

    session.facts_state.commit()
    session.history.append(ChatTurn(role="user", content=req.question))
    session.history.append(ChatTurn(role="assistant", content=response.message))
    return response
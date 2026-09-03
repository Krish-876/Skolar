from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from nova.api.deps import get_session, get_supabase_and_groq
from nova.schemas.api import ChatRequest, ChatResponse
from nova.schemas.chat import ChatTurn
from nova.services.chat_service import GROQ_MODEL, ask_nova, generate_initial_suggestions

router = APIRouter(tags=["chat"])


class SuggestionsResponse(BaseModel):
    suggestions: list[str] = Field(default_factory=list, description="4 personalized initial prompt starters.")


@router.get("/chat/{user_id}/suggestions", response_model=SuggestionsResponse)
def get_suggestions(
    user_id: str,
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
    except Exception as e:
        print(f"🔴 [Suggestions Router Error]: {e}")
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
    clients: tuple = Depends(get_supabase_and_groq),
):
    _supabase, groq, groq_backup = clients
    session = get_session(user_id, clients)

    try:
        snapshot, _patch = session.facts_state.get()
        response = ask_nova(
            groq,
            snapshot.model_dump(),
            req.question,
            session.history,
            groq_backup,
            GROQ_MODEL,
        )
    except Exception as e:
        session.facts_state.rollback()
        print(f"🔴 [Chat Router Error]: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

    session.facts_state.commit()
    session.history.append(ChatTurn(role="user", content=req.question))
    session.history.append(ChatTurn(role="assistant", content=response.message))
    return response
from fastapi import APIRouter, Depends

from nova.api.deps import get_session, get_supabase_and_groq
from nova.schemas.api import ChatRequest, ChatResponse
from nova.schemas.chat import ChatTurn
from nova.services.chat_service import GROQ_MODEL, ask_nova

router = APIRouter(tags=["chat"])


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
        answer = ask_nova(
            groq,
            snapshot.model_dump(),
            req.question,
            session.history,
            groq_backup,
            GROQ_MODEL,
        )
    except Exception:
        session.facts_state.rollback()
        raise

    session.facts_state.commit()
    session.history.append(ChatTurn(role="user", content=req.question))
    session.history.append(ChatTurn(role="assistant", content=answer))
    return ChatResponse(answer=answer)
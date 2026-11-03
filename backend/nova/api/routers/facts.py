from fastapi import APIRouter, Depends

from nova.api.deps import get_session, get_supabase_and_groq, require_same_user
from nova.schemas.api import FactsResponse

router = APIRouter(tags=["facts"])


@router.get("/facts/{user_id}", response_model=FactsResponse)
def get_facts(
    user_id: str,
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    session = get_session(user_id, clients)
    try:
        snapshot, patch = session.facts_state.get()
    except Exception:
        session.facts_state.rollback()
        raise
    session.facts_state.commit()
    return FactsResponse(snapshot=snapshot.model_dump(), patch=patch)
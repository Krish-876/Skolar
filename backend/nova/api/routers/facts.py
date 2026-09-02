from fastapi import APIRouter, Depends, HTTPException

from nova.api.deps import get_session, get_supabase_and_groq
from nova.schemas.api import FactsResponse

router = APIRouter(tags=["facts"])


@router.get("/facts/{user_id}", response_model=FactsResponse)
def get_facts(user_id: str, clients: tuple = Depends(get_supabase_and_groq)):
    session = get_session(user_id, clients)
    try:
        snapshot, patch = session.facts_state.get()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    session.facts_state.commit()
    return FactsResponse(snapshot=snapshot.model_dump(), patch=patch)
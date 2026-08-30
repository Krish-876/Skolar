from fastapi import APIRouter, Depends, HTTPException

from nova.api.deps import get_session, get_supabase_and_groq
from nova.schemas.api import ReasoningRunRequest, ReasoningRunResponse
from nova.services.reasoning_service import GROQ_MODEL, run_reasoning_pass
from nova.services.clients import get_shadow_clients

router = APIRouter(tags=["reasoning"])


@router.post("/reasoning/{user_id}/run", response_model=ReasoningRunResponse)
def run_reasoning(
    user_id: str,
    req: ReasoningRunRequest,
    clients: tuple = Depends(get_supabase_and_groq),
):
    _supabase, groq, _groq_backup = clients
    session = get_session(user_id, clients)
    shadow = get_shadow_clients()

    try:
        snapshot, _patch = session.facts_state.get()
        result = run_reasoning_pass(
            groq,
            snapshot,
            session.last_good_plan,
            trigger_type=req.trigger_type,
            openrouter=shadow.get("openrouter"),
            model=GROQ_MODEL,
            user_id=user_id,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    session.facts_state.commit()
    if not result.stale:
        session.last_good_plan = result.plan
    return ReasoningRunResponse(plan=result.plan, stale=result.stale, note=result.note)
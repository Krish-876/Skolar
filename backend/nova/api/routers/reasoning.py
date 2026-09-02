from fastapi import APIRouter, Depends, HTTPException

from nova.api.deps import get_session, get_supabase_and_groq
from nova.schemas.api import ReasoningRunRequest, ReasoningRunResponse
from nova.services.reasoning_service import GROQ_MODEL, run_reasoning_pass
from nova.services.clients import get_shadow_clients

router = APIRouter(tags=["reasoning"])


@router.post(
    "/reasoning/{user_id}/run",
    response_model=ReasoningRunResponse,
    summary="Run a reasoning pass and get today's study plan",
    description=(
        "Generates (or re-ranks) a student's study plan from their current "
        "facts snapshot. Use trigger_type='full_pass' for a full scheduled "
        "run, or 'minor_trigger_rerank' after a single event like a new "
        "test score. Falls back to yesterday's plan (stale=True) if "
        "generation fails - never returns a blank plan."
    ),
)
def run_reasoning(
    user_id: str,
    req: ReasoningRunRequest,
    clients: tuple = Depends(get_supabase_and_groq),
):
    try:
        _supabase, groq, _groq_backup = clients
        session = get_session(user_id, clients)
        shadow = get_shadow_clients()
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
        print(f"🔴 [Reasoning Router Error]: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

    session.facts_state.commit()
    if not result.stale:
        session.last_good_plan = result.plan
    return ReasoningRunResponse(plan=result.plan, stale=result.stale, note=result.note)
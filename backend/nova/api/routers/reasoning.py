import logging

from fastapi import APIRouter, Depends, HTTPException

from nova.api.deps import get_session, get_supabase_and_groq, require_same_user
from nova.schemas.api import ReasoningRunRequest, ReasoningRunResponse
from nova.schemas.reasoning_why_log import DeferredPassEntry
from nova.services.reasoning_service import GROQ_MODEL, run_reasoning_pass
from nova.services.clients import get_shadow_clients

logger = logging.getLogger(__name__)
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
    _authorized_user_id: str = Depends(require_same_user),
    clients: tuple = Depends(get_supabase_and_groq),
):
    supabase, groq, groq_backup = clients
    session = get_session(user_id, clients)
    shadow = get_shadow_clients()

    try:
        snapshot, _patch = session.facts_state.get()
        snapshot_dump = snapshot.model_dump() if hasattr(snapshot, "model_dump") else (snapshot if isinstance(snapshot, dict) else {})

        def _log_deferred_pass(entry: DeferredPassEntry):
            """Persists a failed/deferred reasoning pass to nova_why_log."""
            entry_type = "minor_trigger" if req.trigger_type == "minor_trigger_rerank" else "full_pass"
            facts_snapshot = snapshot_dump if entry_type == "full_pass" else (snapshot_dump or None)
            if entry_type == "full_pass" and facts_snapshot is None:
                facts_snapshot = {}
            row = {
                "user_id": entry.user_id,
                "entry_type": entry_type,
                "facts_snapshot": facts_snapshot,
                "plan_output": None,
                "reasoning_summary": f"Deferred pass: {entry.reason}",
                "user_subject_id": None,
                "topic_id": None,
                "career_unit_id": None,
                "supersedes_id": None,
            }
            try:
                supabase.table("nova_why_log").insert(row).execute()
            except Exception as e:
                logger.error("Failed to log deferred pass to nova_why_log: %s", e, exc_info=True)

        result = run_reasoning_pass(
            groq,
            snapshot,
            session.last_good_plan,
            trigger_type=req.trigger_type,
            openrouter=shadow.get("openrouter"),
            model=GROQ_MODEL,
            user_id=user_id,
            log_deferred_pass=_log_deferred_pass,
            groq_backup=groq_backup,
        )
    except Exception:
        session.facts_state.rollback()
        logger.exception("Reasoning pass failed.")
        raise HTTPException(status_code=500, detail="Unable to process the request.")

    session.facts_state.commit()

    if not result.stale:
        session.last_good_plan = result.plan
        plan = result.plan
        plan_dump = plan.model_dump() if hasattr(plan, "model_dump") else plan
        summary = plan_dump.get("summary") if isinstance(plan_dump, dict) else str(plan_dump)

        # Log the successful pass to nova_why_log
        entry_type = "minor_trigger" if req.trigger_type == "minor_trigger_rerank" else "full_pass"
        facts_snapshot = snapshot_dump if entry_type == "full_pass" else (snapshot_dump or None)
        if entry_type == "full_pass" and facts_snapshot is None:
            facts_snapshot = {}
        row = {
            "user_id": user_id,
            "entry_type": entry_type,
            "facts_snapshot": facts_snapshot,
            "plan_output": plan_dump if isinstance(plan_dump, dict) else {"plan": plan_dump},
            "reasoning_summary": summary or "Study plan generated successfully.",
            "user_subject_id": None,
            "topic_id": None,
            "career_unit_id": None,
            "supersedes_id": None,
        }
        try:
            supabase.table("nova_why_log").insert(row).execute()
        except Exception as e:
            logger.error("Failed to log successful pass to nova_why_log: %s", e, exc_info=True)

    return ReasoningRunResponse(
        plan=result.plan,
        stale=result.stale,
        note=result.note,
        compression_tier=getattr(result, "compression_tier", 1),
    )
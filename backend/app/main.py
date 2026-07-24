from fastapi import FastAPI, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Dict, Any
from app.dependencies import get_current_user_id, supabase

app = FastAPI(title="Skolar Backend API")

class TriggerCheckResponse(BaseModel):
    trigger_needed: bool
    triggers: List[Dict[str, Any]]

@app.post("/nova/trigger/check", response_model=TriggerCheckResponse)
def check_nova_trigger(user_id: str = Depends(get_current_user_id)):
    """
    Synchronous FastAPI route to handle sync Supabase RPC execution safely.
    """
    try:
        # Call Supabase function passing "p_user_id"
        db_response = supabase.rpc(
            "get_nova_triggers", 
            {"p_user_id": user_id}
        ).execute()
        
        rows = db_response.data or []
        
        if rows:
            return TriggerCheckResponse(
                trigger_needed=True,
                triggers=rows
            )
        else:
            return TriggerCheckResponse(
                trigger_needed=False,
                triggers=[]
            )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database execution failed: {str(e)}"
        )
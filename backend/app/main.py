import logging
from typing import List, Dict, Any

from fastapi import FastAPI, Request, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.dependencies import get_current_user_id, supabase

app = FastAPI(title="Skolar Backend API")

# Add CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# LAYER 1: Edge Transport Security (TLS / HTTPS Termination Gate)
# ============================================================================

@app.middleware("http")
async def layer1_transport_security_middleware(request: Request, call_next):
    """
    Layer 1 Gatekeeper: Edge Transport Security.
    Enforces HTTPS by inspecting the proxy header 'x-forwarded-proto'.
    Rejects plain HTTP connections for non-local environments with 403 Forbidden.
    """
    try:
        forwarded_proto = request.headers.get("x-forwarded-proto", "https")
        client_host = request.client.host if request.client else ""
        is_local_dev = client_host in ("127.0.0.1", "localhost", "testclient")

        # Exclude open utility endpoints
        if request.url.path in ["/health", "/docs", "/openapi.json", "/redoc"]:
            return await call_next(request)

        if forwarded_proto != "https" and not is_local_dev:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insecure transport protocol. HTTPS is strictly required."
            )

        return await call_next(request)
    except HTTPException as exc:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail}
        )


# ============================================================================
# ROUTE DATA MODELS & ENDPOINTS
# ============================================================================

@app.get("/health")
def health_check():
    """Liveness probe endpoint."""
    return {"status": "ok"}


class TriggerCheckResponse(BaseModel):
    trigger_needed: bool
    triggers: List[Dict[str, Any]]


@app.post("/nova/trigger/check", response_model=TriggerCheckResponse)
def check_nova_trigger(user_id: str = Depends(get_current_user_id)):
    """
    Synchronous FastAPI route to handle sync Supabase RPC execution safely.
    """
    try:
        # Call Supabase stored procedure passing "p_user_id"
        db_response = supabase.rpc(
            "get_nova_triggers", 
            {"p_user_id": user_id}
        ).execute()
        
        rows = db_response.data or []
        
        return TriggerCheckResponse(
            trigger_needed=bool(rows),
            triggers=rows
        )

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to check Nova triggers: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to check Nova triggers."
        )
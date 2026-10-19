import os
import logging
from typing import List, Dict, Any

import jwt
from jwt import PyJWTError
from fastapi import FastAPI, Request, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from dotenv import load_dotenv

from app.dependencies import get_current_user_id, supabase

load_dotenv()

# Configured Supabase JWT signing secret (with fallback for local dev/testing)
DEFAULT_DEV_JWT_SECRET = "skolar-super-secure-test-secret-key-32chars"
SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", DEFAULT_DEV_JWT_SECRET)

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
# LAYERS 1 & 2: Edge Transport Security & Identity / Session Auth
# ============================================================================

@app.middleware("http")
async def security_gatekeeper_middleware(request: Request, call_next):
    """
    Ingress Security Pipeline:
    - Layer 1: Edge Transport Security (TLS/HTTPS Enforcement)
    - Layer 2: Identity & Session Auth (Cryptographic Supabase JWT Verification)
    """
    try:
        # Exclude CORS preflight and open utility endpoints
        if request.method == "OPTIONS" or request.url.path in ["/health", "/docs", "/openapi.json", "/redoc"]:
            return await call_next(request)

        # --------------------------------------------------------------------
        # LAYER 1: Edge Transport Security (HTTPS Check)
        # --------------------------------------------------------------------
        forwarded_proto = request.headers.get("x-forwarded-proto", "https")
        client_host = request.client.host if request.client else ""
        is_local_dev = client_host in ("127.0.0.1", "localhost", "testclient")

        if forwarded_proto != "https" and not is_local_dev:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insecure transport protocol. HTTPS is strictly required."
            )

        # --------------------------------------------------------------------
        # LAYER 2: Identity & Session Auth (JWT Signature & Claims Verification)
        # --------------------------------------------------------------------
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing or malformed Authorization header."
            )

        token = auth_header.split(" ")[1]

        try:
            # Cryptographically verify signature, algorithm, audience, and expiration
            jwt_secret = os.getenv("SUPABASE_JWT_SECRET", DEFAULT_DEV_JWT_SECRET)
            payload = jwt.decode(
                token,
                jwt_secret,
                algorithms=["HS256"],
                audience="authenticated",
                options={
                    "verify_signature": True,
                    "verify_exp": True,
                    "verify_aud": True,
                    "require": ["exp", "sub", "aud"],
                },
            )

            user_id = payload.get("sub")
            user_role = payload.get("role", "authenticated")
            app_metadata = payload.get("app_metadata")

            # Safely extract custom roles without raising AttributeError on non-dict types
            if isinstance(app_metadata, dict):
                custom_roles = app_metadata.get("roles", ["student"])
                if not isinstance(custom_roles, list):
                    custom_roles = ["student"]
            else:
                custom_roles = ["student"]

            if not user_id:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token payload: User ID (sub) not found."
                )

            # Attach validated claims to request state
            request.state.user_id = user_id
            request.state.user_role = user_role
            request.state.custom_roles = custom_roles

        except PyJWTError:
            # Return generic error detail without leaking internal parser exception details
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired authentication token."
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
    """Liveness probe endpoint (bypasses Layer 1 & 2)."""
    return {"status": "ok"}


@app.get("/me")
def get_current_user_profile(request: Request):
    """
    Returns caller identity context injected into request.state by Layer 2.
    """
    return {
        "user_id": getattr(request.state, "user_id", None),
        "user_role": getattr(request.state, "user_role", None),
        "custom_roles": getattr(request.state, "custom_roles", []),
    }


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
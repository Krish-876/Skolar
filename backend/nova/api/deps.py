"""Shared FastAPI dependencies. Routers stay thin - all wiring lives here."""
import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from groq import Groq
from supabase import Client

from nova.api.sessions import UserSession, get_or_create_session
from nova.services.clients import get_clients

logger = logging.getLogger(__name__)


def get_supabase_and_groq() -> tuple[Client, Groq, Groq | None]:
    return get_clients()


def get_session(user_id: str, clients: tuple) -> UserSession:
    supabase, _groq, _groq_backup = clients
    return get_or_create_session(user_id, supabase)


# Copied from backend/app/dependencies.py's get_current_user_id rather than
# imported from it: backend/app and backend/nova are separate, independently
# run/deployed services (see NOVA.md), so nova can't assume backend/app is
# importable at runtime. Reuses get_clients() for the Supabase client instead
# of constructing a second one, matching the rest of this module.
security = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> str:
    """Reads the Authorization header, verifies it with Supabase, and
    returns the authenticated user's id, or raises 401."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
        )
    supabase, _groq, _groq_backup = get_clients()
    token = credentials.credentials
    try:
        response = supabase.auth.get_user(token)
        user = response.user if response else None
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired authentication token.",
            )
        return user.id
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Authentication failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
        ) from e
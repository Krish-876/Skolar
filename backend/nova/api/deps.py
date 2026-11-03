"""Shared FastAPI dependencies. Routers stay thin - all wiring lives here."""
import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from groq import Groq
from supabase import Client

from nova.api.sessions import UserSession, get_or_create_session
from nova.services.clients import get_clients

logger = logging.getLogger(__name__)
_bearer = HTTPBearer()


def get_supabase_and_groq() -> tuple[Client, Groq, Groq | None]:
    return get_clients()


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    clients: tuple[Client, Groq, Groq | None] = Depends(get_supabase_and_groq),
) -> str:
    """Validate the bearer token and return the user ID from Supabase Auth."""
    try:
        response = clients[0].auth.get_user(credentials.credentials)
        if response.user is None:
            raise ValueError("Supabase returned no authenticated user")
        return response.user.id
    except Exception as exc:
        logger.warning("Nova API authentication failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


def get_authorized_user_id(
    user_id: str,
    authenticated_user_id: str = Depends(get_current_user_id),
) -> str:
    """Ensure the path user ID belongs to the authenticated caller."""
    if user_id != authenticated_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to access this user's data.",
        )
    return authenticated_user_id


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
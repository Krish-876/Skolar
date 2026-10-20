import os
import logging
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("SUPABASE_URL and SUPABASE_KEY environment variables must be set.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# HTTPBearer extracts the Authorization header automatically
security = HTTPBearer()

def get_current_user_id(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """
    Reads the Authorization header, verifies it synchronously with Supabase,
    and returns the authenticated user's ID.
    """
    token = credentials.credentials
    try:
        # Synchronous token verification with Supabase Auth
        response = supabase.auth.get_user(token)
        user = response.user
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired authentication token."
            )
        return user.id
    except HTTPException:
        raise
    except Exception as e:
        # Log internal error on server side without exposing error details to client
        logging.error(f"Authentication failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token."
        )


def require_student_or_admin(request: Request) -> str:
    """Allow only trusted application roles on shared Nova operations."""
    roles = getattr(request.state, "custom_roles", [])
    roles_are_trusted = getattr(request.state, "custom_roles_trusted", False)
    if not roles_are_trusted or not isinstance(roles, list):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions.",
        )

    normalized_roles = {role.lower() for role in roles if isinstance(role, str)}
    if not normalized_roles.intersection({"student", "admin"}):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions.",
        )
    return request.state.user_id
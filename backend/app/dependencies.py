import logging
import os
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase import Client, create_client

load_dotenv()
logger = logging.getLogger(__name__)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("SUPABASE_URL and SUPABASE_KEY environment variables must be set.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
security = HTTPBearer()


def get_current_user_id(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """
    Reads the Authorization header, verifies the token synchronously with Supabase Auth,
    and returns the authenticated user's ID.
    """
    token = credentials.credentials
    try:
        response = supabase.auth.get_user(token)
        user = response.user

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired authentication token.",
            )
        return user.id
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Authentication failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
        )


def get_current_user(user_id: str = Depends(get_current_user_id)) -> dict:
    """
    Fetches the authenticated user's profile from the database to supply verified
    identity attributes (e.g. college, campus_id) to downstream routes.
    """
    try:
        res = (
            supabase.table("users")
            .select("id, email, college, campus_id")
            .eq("id", user_id)
            .limit(1)
            .execute()
        )
        if res.data and len(res.data) > 0:
            return res.data[0]
        return {"id": user_id, "email": None, "college": None, "campus_id": None}
    except Exception as e:
        logger.warning("Failed to fetch profile for user %s: %s", user_id, e)
        return {"id": user_id, "email": None, "college": None, "campus_id": None}

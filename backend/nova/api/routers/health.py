from fastapi import APIRouter

from nova.schemas.api import HealthResponse
from nova.services.clients import get_clients

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def health():
    try:
        _supabase, groq, groq_backup = get_clients()
        return HealthResponse(
            status="ok", supabase=True, groq=bool(groq), groq_backup=bool(groq_backup)
        )
    except Exception:
        return HealthResponse(status="degraded", supabase=False, groq=False, groq_backup=False)
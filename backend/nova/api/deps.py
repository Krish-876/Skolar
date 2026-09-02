"""Shared FastAPI dependencies. Routers stay thin - all wiring lives here."""
from groq import Groq
from supabase import Client

from nova.api.sessions import UserSession, get_or_create_session
from nova.services.clients import get_clients


def get_supabase_and_groq() -> tuple[Client, Groq, Groq | None]:
    return get_clients()


def get_session(user_id: str, clients: tuple) -> UserSession:
    supabase, _groq, _groq_backup = clients
    return get_or_create_session(user_id, supabase)
import os
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq

from supabase import Client, create_client

# lib/core/ai/nova/nova/services/clients.py -> lib/core/ai/rag_llms/.env
ENV_PATH = Path(__file__).resolve().parent.parent.parent.parent / "rag_llms" / ".env"


def get_clients() -> tuple[Client, Groq, Groq | None]:
    load_dotenv(ENV_PATH, override=True)
    supabase_url = os.environ["SUPABASE_URL"]
    supabase_key = os.environ["SUPABASE_KEY"]
    groq_key = os.environ["GROQ_API_KEY"]
    groq_key_2 = os.environ.get("GROQ_API_KEY_2")

    groq_backup = Groq(api_key=groq_key_2) if groq_key_2 else None
    return create_client(supabase_url, supabase_key), Groq(api_key=groq_key), groq_backup
import os
from pathlib import Path

from dotenv import load_dotenv
from supabase import create_client, Client
from groq import Groq

# lib/core/ai/nova/nova/services/clients.py -> lib/core/ai/rag_llms/.env
ENV_PATH = Path(__file__).resolve().parent.parent.parent.parent / "rag_llms" / ".env"


def get_clients() -> tuple[Client, Groq]:
    load_dotenv(ENV_PATH, override=True)
    supabase_url = os.environ["SUPABASE_URL"]
    supabase_key = os.environ["SUPABASE_KEY"]
    groq_key = os.environ["GROQ_API_KEY"]
    return create_client(supabase_url, supabase_key), Groq(api_key=groq_key)

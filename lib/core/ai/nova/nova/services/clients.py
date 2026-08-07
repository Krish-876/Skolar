import os
from pathlib import Path

from dotenv import load_dotenv
from supabase import create_client, Client
from groq import Groq

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


def get_shadow_clients() -> dict[str, object | None]:
    """Separate from get_clients() on purpose - these back shadow-eval /
    reasoning-layer tiers (Cerebras, OpenRouter/Nemotron), not the ask_nova
    contract CI checks. Missing keys just mean that tier stays unavailable,
    never an error - shadow tiers are opt-in by env presence."""
    load_dotenv(ENV_PATH, override=True)

    cerebras = None
    cerebras_key = os.environ.get("CEREBRAS_API_KEY")
    if cerebras_key:
        from cerebras.cloud.sdk import Cerebras

        cerebras = Cerebras(api_key=cerebras_key)

    openrouter = None
    openrouter_key = os.environ.get("OPENROUTER_API_KEY")
    if openrouter_key:
        from openai import OpenAI

        openrouter = OpenAI(
            api_key=openrouter_key, base_url="https://openrouter.ai/api/v1"
        )

    return {"cerebras": cerebras, "openrouter": openrouter}
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


# tables Nova's FactsSnapshot is built from - kept here (not imported from
# facts_state) so this module doesn't need to know about the patch logic,
# just which tables to listen on.
FACTS_TABLES = [
    "users",
    "user_subject_exams",
    "nova_capacity_log",
    "staleness_tracker",
    "standing_flags",
    "situation_flags",
    "nova_history",
    "career_units",
    "question_results",
    "user_topic_weights",
    "study_plans",
]


def start_facts_listener(supabase: Client, user_id: str, on_change):
    """Subscribes to every table that feeds FactsSnapshot and calls
    on_change(table_name) whenever a row tied to this user changes.

    `users` and most tables filter directly on id/user_id. user_subject_exams
    and question_results don't carry user_id directly (joined via
    user_subject_id / attempt_id) - subscribed unfiltered and left to the
    caller's on_change to just mark that table dirty; the next targeted
    refetch re-scopes to this user_id anyway, so an extra dirty flag from
    another student's row costs one avoidable partial fetch, not a leak.
    """
    channel = supabase.channel(f"facts-{user_id}")

    direct_filter_tables = [
        "nova_capacity_log",
        "staleness_tracker",
        "standing_flags",
        "situation_flags",
        "nova_history",
        "career_units",
        "user_topic_weights",
        "study_plans",
    ]
    for table in direct_filter_tables:
        channel.on_postgres_changes(
            event="*",
            schema="public",
            table=table,
            filter=f"user_id=eq.{user_id}",
            callback=lambda payload, t=table: on_change(t),
        )

    channel.on_postgres_changes(
        event="*", schema="public", table="users",
        filter=f"id=eq.{user_id}",
        callback=lambda payload: on_change("users"),
    )

    for table in ("user_subject_exams", "question_results"):
        channel.on_postgres_changes(
            event="*", schema="public", table=table,
            callback=lambda payload, t=table: on_change(t),
        )

    channel.subscribe()
    return channel
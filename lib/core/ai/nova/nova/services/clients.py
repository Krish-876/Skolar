import asyncio
import logging
import os
import threading
from collections.abc import Callable
from pathlib import Path
from typing import cast

from dotenv import load_dotenv
from groq import Groq
from realtime import PostgresChangesPayload, RealtimePostgresChangesListenEvent
from supabase import Client, acreate_client, create_client

logger = logging.getLogger(__name__)

ENV_PATH = Path(__file__).resolve().parent.parent.parent.parent / "rag_llms" / ".env"


def get_clients() -> tuple[Client, Groq, Groq | None]:
    load_dotenv(ENV_PATH, override=True)
    supabase_url = os.environ["SUPABASE_URL"]
    supabase_key = os.environ["SUPABASE_KEY"]
    groq_key = os.environ["GROQ_API_KEY"]
    groq_key_2 = os.environ.get("GROQ_API_KEY_2")

    groq_backup = Groq(api_key=groq_key_2) if groq_key_2 else None
    return create_client(supabase_url, supabase_key), Groq(api_key=groq_key), groq_backup


def get_supabase_credentials() -> tuple[str, str]:
    """Raw url/key, separate from get_clients() so callers that only need
    to open the async Realtime client (start_facts_listener_threaded)
    don't have to also build a sync Client they won't use."""
    load_dotenv(ENV_PATH, override=True)
    return os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"]


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


def start_facts_listener_threaded(supabase_url: str, supabase_key: str, user_id: str, on_change):
    """Subscribes to every table that feeds FactsSnapshot and calls
    on_change(table_name) whenever a row tied to this user changes, on its
    own background thread with its own asyncio event loop, using the async
    Supabase client. This is what lets Realtime actually work from a plain
    sync CLI (nova_agent.py's main() has no event loop of its own).

    on_change (FactsState.mark_dirty) stays a plain sync callable - it just
    adds a table name to a set under a lock, so it's safe to call from this
    background thread without making it async itself.

    Returns the thread (daemon=True, dies with the main process).
    """

    def _runner():
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(
                _subscribe_async(supabase_url, supabase_key, user_id, on_change)
            )
            loop.run_forever()  # keep the channel alive until the process exits
        except Exception:
            # background thread - a listener failure should never crash the
            # CLI session, it just means live updates stop coming through
            logger.exception("facts listener thread failed, live updates disabled")

    thread = threading.Thread(target=_runner, daemon=True)
    thread.start()
    return thread


async def _subscribe_async(supabase_url: str, supabase_key: str, user_id: str, on_change):
    all_events = cast(RealtimePostgresChangesListenEvent, "*")

    async_supabase = await acreate_client(supabase_url, supabase_key)
    channel = async_supabase.channel(f"facts-{user_id}")

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

    def _make_table_callback(t: str) -> Callable[[PostgresChangesPayload], None]:
        def _callback(payload: PostgresChangesPayload) -> None:
            on_change(t)
        return _callback

    for table in direct_filter_tables:
        channel.on_postgres_changes(
            event=all_events,
            schema="public",
            table=table,
            filter=f"user_id=eq.{user_id}",
            callback=_make_table_callback(table),
        )

    def users_callback(payload: PostgresChangesPayload) -> None:
        on_change("users")

    channel.on_postgres_changes(
        event=all_events, schema="public", table="users",
        filter=f"id=eq.{user_id}",
        callback=users_callback,
    )

    for table in ("user_subject_exams", "question_results"):
        channel.on_postgres_changes(
            event=all_events, schema="public", table=table,
            callback=_make_table_callback(table),
        )

    await channel.subscribe()
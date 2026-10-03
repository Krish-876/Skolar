"""
Nova QA CLI
Usage:
    python -m nova
    python -m nova --token BEARER_TOKEN
    python -m nova --email user@example.com
"""

import argparse
import getpass
import logging
import os
import sys

from nova.schemas.chat import ChatTurn
from nova.services.chat_service import GROQ_MODEL, ask_nova
from nova.services.clients import (
    get_clients,
    get_supabase_credentials,
    start_facts_listener_threaded,
)
from nova.services.facts_state import FactsState

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger(__name__)


def authenticate_cli_user(supabase, token: str | None = None, email: str | None = None) -> str:
    """
    Authenticates the CLI operator via Supabase Auth and returns the verified user ID.
    Supports explicit CLI args, environment variables, or interactive prompts.
    """
    auth_token = token or os.getenv("NOVA_BEARER_TOKEN")
    if auth_token:
        try:
            res = supabase.auth.get_user(auth_token)
            if res.user:
                return res.user.id
        except Exception as e:
            logger.error("Bearer token verification failed: %s", e)
            print("Provided bearer token is invalid or expired.")
            sys.exit(1)

    user_email = email or os.getenv("NOVA_USER_EMAIL")
    if not user_email:
        try:
            user_email = input("Supabase Email: ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            sys.exit(1)

    user_password = os.getenv("NOVA_USER_PASSWORD")
    if not user_password:
        try:
            user_password = getpass.getpass("Supabase Password: ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            sys.exit(1)

    try:
        auth_res = supabase.auth.sign_in_with_password({
            "email": user_email,
            "password": user_password,
        })
        if not auth_res.user:
            print("Authentication failed: No user returned.")
            sys.exit(1)
        return auth_res.user.id
    except Exception as e:
        print(f"Authentication failed: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Nova QA CLI with authenticated session.")
    parser.add_argument("--token", help="Supabase auth bearer token", default=None)
    parser.add_argument("--email", help="Supabase user email", default=None)
    args = parser.parse_args()

    supabase, groq, groq_backup = get_clients()
    user_id = authenticate_cli_user(supabase, token=args.token, email=args.email)
    print(f"Authenticated session established for user: {user_id}\n")

    facts_state = FactsState(supabase, user_id)
    try:
        facts_state.get()
    except Exception as e:
        logging.exception("facts_state.get() failed on startup")
        print(f"Could not reach student data right now: {e}")
        sys.exit(1)

    facts_state.commit()
    supabase_url, supabase_key = get_supabase_credentials()
    start_facts_listener_threaded(supabase_url, supabase_key, user_id, facts_state.mark_dirty)
    history: list[ChatTurn] = []
    print("Ask Nova anything. Ctrl+C to quit.\n")

    while True:
        try:
            question = input("> ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            break
        if not question:
            continue
        try:
            snapshot, _ = facts_state.get()
            answer = ask_nova(groq, snapshot.model_dump(), question, history, groq_backup, GROQ_MODEL)
        except Exception as e:
            logging.exception("ask_nova turn failed")
            print(f"\nSomething went wrong: {e}\n")
            continue

        facts_state.commit()
        print(f"\n{answer}\n")
        history.append(ChatTurn(role="user", content=question))
        history.append(ChatTurn(role="assistant", content=answer))


if __name__ == "__main__":
    main()
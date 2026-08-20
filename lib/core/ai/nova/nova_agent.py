"""
Nova Q&A CLI

Usage:
    python nova_agent.py <user_id>
"""

import sys

from nova.services.clients import (
    get_clients,
    get_supabase_credentials,
    start_facts_listener_threaded,
)
from nova.services.facts_state import FactsState
from nova.services.chat_service import ask_nova
from nova.schemas.chat import ChatTurn


MODELS = {
    "1": ("openai/gpt-oss-120b", "thinking (default)"),
    "2": ("llama-3.1-8b-instant", "fast"),
}


def main():
    if len(sys.argv) != 2:
        print("Usage: python nova_agent.py <user_id>")
        sys.exit(1)

    user_id = sys.argv[1]
    supabase, groq, groq_backup = get_clients()

    facts_state = FactsState(supabase, user_id)
    try:
        facts_state.get()  # initial full fetch, populates the cache
    except Exception:
        print("Couldn't reach the student's data right now, try again shortly.")
        sys.exit(1)
    facts_state.commit()
    supabase_url, supabase_key = get_supabase_credentials()
    start_facts_listener_threaded(supabase_url, supabase_key, user_id, facts_state.mark_dirty)
    current_model = MODELS["1"][0]

    history: list[ChatTurn] = []
    print("Ask Nova anything. Type /model to switch models. Ctrl+C to quit.\n")
    while True:
        try:
            question = input("> ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            break
        if not question:
            continue

        if question == "/model":
            for key, (model_id, label) in MODELS.items():
                marker = " (current)" if model_id == current_model else ""
                print(f"  {key}. {label}{marker}")
            choice = input("  choose: ").strip()
            if choice in MODELS:
                current_model = MODELS[choice][0]
                print(f"\nSwitched to {MODELS[choice][1]}.\n")
            else:
                print("\nNot a valid option, keeping current model.\n")
            continue

        try:
            snapshot, _ = facts_state.get()
            answer = ask_nova(groq, snapshot.model_dump(), question, history, groq_backup, current_model)
        except Exception:
            print("\nSomething went wrong there, try that again.\n")
            continue
        facts_state.commit()  # only drain dirty tables once the turn actually landed
        print(f"\n{answer}\n")

        history.append(ChatTurn(role="user", content=question))
        history.append(ChatTurn(role="assistant", content=answer))


if __name__ == "__main__":
    main()
"""
Nova Q&A CLI
Usage:
    python nova_agent.py <user_id>
"""
import logging
import sys
from nova.services.clients import (
    get_clients,
    get_supabase_credentials,
    start_facts_listener_threaded,
)
from nova.services.facts_state import FactsState
from nova.services.chat_service import ask_nova, GROQ_MODEL
from nova.schemas.chat import ChatTurn
logging.basicConfig(level=logging.WARNING)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python nova_agent.py <user_id>")
        sys.exit(1)
    user_id = sys.argv[1]
    supabase, groq, groq_backup = get_clients()
    facts_state = FactsState(supabase, user_id)
    try:
        facts_state.get()  # initial full fetch, populates the cache
    except Exception as e:
        logging.exception("facts_state.get() failed on startup")
        print(f"Couldn't reach the student's data right now: {e}")
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
            parsed = ask_nova(groq, snapshot.model_dump(), question, history, groq_backup, GROQ_MODEL)
            answer = parsed.response.message
        except Exception as e:
            logging.exception("ask_nova turn failed")
            print(f"\nSomething went wrong there: {e}\n")
            continue
        facts_state.commit()  # only drain dirty tables once the turn actually landed
        print(f"\n{answer}\n")
        history.append(ChatTurn(role="user", content=question))
        history.append(ChatTurn(role="assistant", content=answer))
if __name__ == "__main__":
    main()
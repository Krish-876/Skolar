"""
Nova Q&A CLI

Usage:
    python nova_agent.py <user_id>
"""

import sys

from nova.services.clients import get_clients
from nova.services.facts_service import get_facts_snapshot
from nova.services.chat_service import ask_nova
from nova.schemas.chat import ChatTurn


def main():
    if len(sys.argv) != 2:
        print("Usage: python nova_agent.py <user_id>")
        sys.exit(1)

    user_id = sys.argv[1]
    supabase, groq = get_clients()

    facts = get_facts_snapshot(supabase, user_id)

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

        answer = ask_nova(groq, facts, question, history)
        print(f"\n{answer}\n")

        history.append(ChatTurn(role="user", content=question))
        history.append(ChatTurn(role="assistant", content=answer))


if __name__ == "__main__":
    main()

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

    facts = get_facts_snapshot(supabase, user_id)
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
            answer = ask_nova(groq, facts, question, history, groq_backup, current_model)
        except Exception:
            print("\nSomething went wrong there, try that again.\n")
            continue
        print(f"\n{answer}\n")

        history.append(ChatTurn(role="user", content=question))
        history.append(ChatTurn(role="assistant", content=answer))


if __name__ == "__main__":
    main()
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
from nova.services.paper_service import get_subjects_for_student, generate_paper
from nova.schemas.chat import ChatTurn
logging.basicConfig(level=logging.CRITICAL + 1)
logging.disable(logging.CRITICAL)


def _handle_paper_command(supabase, groq, groq_backup, user_id: str) -> None:
    """Handles the "/paper" flow: list subjects for the student's current
    semester, take one pick, generate a paper on-demand. Nothing here is
    persisted to the DB and nothing here is added to conversation history -
    see conflicts #1-#3 flagged alongside this function's call site."""
    subjects = get_subjects_for_student(supabase, user_id)
    if not subjects:
        print("\nYour semester/campus isn't set up yet, can't show subjects.\n")
        return

    print("\nWhich subject?")
    for i, subject in enumerate(subjects, start=1):
        print(f"  {i}. {subject['name']}")

    try:
        choice = input("Which subject? (type a number or name): ").strip()
    except (KeyboardInterrupt, EOFError):
        print()
        return

    chosen = None
    if choice.isdigit():
        idx = int(choice)
        if 1 <= idx <= len(subjects):
            chosen = subjects[idx - 1]
    if chosen is None:
        for subject in subjects:
            if subject["name"].strip().lower() == choice.lower():
                chosen = subject
                break

    if chosen is None:
        print("\nDidn't recognize that subject, cancelling.\n")
        return

    subject_name = chosen["name"]
    print(f"\nGenerating a paper for {subject_name}...\n")
    try:
        paper = generate_paper(groq, subject_name, groq_backup, GROQ_MODEL)
    except Exception as e:
        logging.exception("generate_paper failed")
        print(f"Something went wrong generating that: {e}\n")
        return

    print(f"{paper}\n")


def main():
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
    print("Ask Nova anything. Type /paper for a mock paper. Ctrl+C to quit.\n")
    while True:
        try:
            question = input("> ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            break
        if not question:
            continue
        if question.lower() == "/paper":
            _handle_paper_command(supabase, groq, groq_backup, user_id)
            continue
        try:
            snapshot, _ = facts_state.get()
            answer = ask_nova(groq, snapshot.model_dump(), question, history, groq_backup, GROQ_MODEL)
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
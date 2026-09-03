"""
Per-user session state: FactsState cache + chat history + last good
reasoning plan.

In-memory dict, same as __main__.py's history: list[ChatTurn] was
per-process. Fine for one worker/dev; swap _STORE for Redis before running
more than one uvicorn worker or scaling past a single instance - an
in-memory dict won't survive a restart or be shared across processes.
"""
from dataclasses import dataclass, field
from threading import Lock

from nova.schemas.chat import ChatTurn
from nova.services.facts_state import FactsState


@dataclass
class UserSession:
    facts_state: FactsState
    history: list[ChatTurn] = field(default_factory=list)
    last_good_plan: dict | None = None


_STORE: dict[str, UserSession] = {}
_LOCK = Lock()


def get_or_create_session(user_id: str, supabase) -> UserSession:
    with _LOCK:
        session = _STORE.get(user_id)
        if session is None:
            facts_state = FactsState(supabase, user_id)
            facts_state.get()  # initial full fetch
            facts_state.commit()
            session = UserSession(facts_state=facts_state)
            _STORE[user_id] = session
        return session
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from nova.api.routers import facts as facts_router  # noqa: E402


class _FakeSnapshot:
    def model_dump(self):
        return {"ok": True}


class _FakeFactsState:
    def get(self):
        return _FakeSnapshot(), {}

    def commit(self):
        return None

    def rollback(self):
        return None


class _FakeSession:
    facts_state = _FakeFactsState()


def test_facts_route_uses_verified_user_context(monkeypatch):
    seen = {}

    def fake_get_session(user_id: str, _clients: tuple):
        seen["user_id"] = user_id
        return _FakeSession()

    monkeypatch.setattr(facts_router, "get_session", fake_get_session)

    response = facts_router.get_facts(
        user_id="path-user",
        clients=("supabase", "groq", None),
        authorized_user_id="verified-user",
    )

    assert seen["user_id"] == "verified-user"
    assert response.snapshot == {"ok": True}

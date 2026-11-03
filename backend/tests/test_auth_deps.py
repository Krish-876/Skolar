"""
Tests for nova/api/deps.py's get_current_user_id - specifically that a
missing Authorization header is rejected the same way an invalid/expired
token is (401), rather than FastAPI's default 403 for a missing bearer
scheme.
"""

import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import nova.api.main as nova_app  # noqa: E402
from nova.api.deps import get_supabase_and_groq  # noqa: E402

USER_ID = "user-1"


@pytest.fixture
def client():
    nova_app.app.dependency_overrides[get_supabase_and_groq] = lambda: (MagicMock(), MagicMock(), None)
    with TestClient(nova_app.app) as c:
        yield c
    nova_app.app.dependency_overrides.pop(get_supabase_and_groq, None)


def test_missing_authorization_header_returns_401_not_403(client):
    """No get_current_user_id override here - the request must be rejected
    by the real dependency before reaching the route at all."""
    resp = client.post(
        f"/subjects/{USER_ID}/add",
        json={"query": "OS", "semester": "sem1"},
    )

    assert resp.status_code == 401
    assert resp.json()["detail"] == "Authentication required."

"""
Integration-style tests for the /subjects/{user_id}/add and
/subjects/{user_id}/confirm endpoints (nova/api/routers/subjects.py).

Exercises all three outcomes described in the feature spec: an auto-matched
add, a needs-confirmation add, and a student confirming one of the returned
candidates (plus the "none of these" -> new custom subject path). The Groq/
Supabase clients dependency is overridden and the service-layer functions
are monkeypatched, so no real network calls happen.
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
import nova.api.routers.subjects as subjects_router  # noqa: E402
from nova.api.deps import get_supabase_and_groq  # noqa: E402
from nova.schemas.subject_match import MatchCandidateOut, MatchResult, UserSubjectOut  # noqa: E402

USER_ID = "user-1"


@pytest.fixture
def client():
    nova_app.app.dependency_overrides[get_supabase_and_groq] = lambda: (MagicMock(), MagicMock(), None)
    with TestClient(nova_app.app) as c:
        yield c
    nova_app.app.dependency_overrides.pop(get_supabase_and_groq, None)


def test_add_subject_auto_matched(client, monkeypatch):
    monkeypatch.setattr(
        subjects_router,
        "match_subject",
        lambda *a, **kw: MatchResult(matched=True, subject_id="s1", source="subject", confidence=0.9),
    )
    monkeypatch.setattr(
        subjects_router,
        "create_user_subject",
        lambda *a, **kw: UserSubjectOut(id="us1", subject_id="s1", custom_subject_id=None, semester="sem1"),
    )

    resp = client.post(
        f"/subjects/{USER_ID}/add",
        json={"query": "OS", "institution_id": "inst-1", "campus_id": "campus-1", "semester": "sem1"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "matched"
    assert body["user_subject"]["id"] == "us1"
    assert body["user_subject"]["subject_id"] == "s1"
    assert body["candidates"] == []


def test_add_subject_needs_confirmation(client, monkeypatch):
    monkeypatch.setattr(
        subjects_router,
        "match_subject",
        lambda *a, **kw: MatchResult(
            matched=False,
            candidates=[MatchCandidateOut(id="s1", name="Operating Systems", confidence=0.4, source="subject")],
            match_log_id="log-1",
        ),
    )
    create_called = MagicMock()
    monkeypatch.setattr(subjects_router, "create_user_subject", create_called)

    resp = client.post(
        f"/subjects/{USER_ID}/add",
        json={"query": "Systms", "institution_id": "inst-1", "campus_id": "campus-1", "semester": "sem1"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "needs_confirmation"
    assert body["user_subject"] is None
    assert body["match_log_id"] == "log-1"
    assert len(body["candidates"]) == 1
    assert body["candidates"][0]["id"] == "s1"
    # A needs-confirmation outcome must never write a user_subjects row itself.
    create_called.assert_not_called()


def test_confirm_subject_with_chosen_candidate(client, monkeypatch):
    monkeypatch.setattr(
        subjects_router,
        "create_user_subject",
        lambda *a, **kw: UserSubjectOut(id="us2", subject_id="s1", custom_subject_id=None, semester="sem1"),
    )
    resolve_called = MagicMock()
    monkeypatch.setattr(subjects_router, "resolve_match_log", resolve_called)

    resp = client.post(
        f"/subjects/{USER_ID}/confirm",
        json={"semester": "sem1", "match_log_id": "log-1", "subject_id": "s1"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["user_subject"]["id"] == "us2"
    assert body["user_subject"]["subject_id"] == "s1"
    resolve_called.assert_called_once()
    assert resolve_called.call_args.args[1:] == ("log-1", "s1", None)


def test_confirm_subject_with_none_of_these_creates_custom_subject(client, monkeypatch):
    monkeypatch.setattr(subjects_router, "create_custom_subject", lambda *a, **kw: "custom-9")
    monkeypatch.setattr(
        subjects_router,
        "create_user_subject",
        lambda *a, **kw: UserSubjectOut(id="us3", subject_id=None, custom_subject_id="custom-9", semester="sem1"),
    )

    resp = client.post(
        f"/subjects/{USER_ID}/confirm",
        json={
            "semester": "sem1",
            "new_custom_subject": {
                "institution_id": "inst-1",
                "course_code": "CS999",
                "name": "Underwater Basket Weaving",
                "credits": 3,
            },
        },
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["user_subject"]["custom_subject_id"] == "custom-9"
    assert body["user_subject"]["subject_id"] is None


def test_confirm_subject_rejects_ambiguous_choice(client):
    """Neither zero nor more than one of subject_id/custom_subject_id/
    new_custom_subject may be set - the caller must pick exactly one path."""
    resp = client.post(f"/subjects/{USER_ID}/confirm", json={"semester": "sem1"})
    assert resp.status_code == 400

    resp = client.post(
        f"/subjects/{USER_ID}/confirm",
        json={"semester": "sem1", "subject_id": "s1", "custom_subject_id": "c1"},
    )
    assert resp.status_code == 400

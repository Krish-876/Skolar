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
from nova.api.deps import get_current_user_id, get_supabase_and_groq  # noqa: E402
from nova.schemas.subject_match import MatchCandidateOut, MatchResult, UserSubjectOut  # noqa: E402

USER_ID = "user-1"


@pytest.fixture
def client():
    nova_app.app.dependency_overrides[get_supabase_and_groq] = lambda: (MagicMock(), MagicMock(), None)
    nova_app.app.dependency_overrides[get_current_user_id] = lambda: USER_ID
    with TestClient(nova_app.app) as c:
        yield c
    nova_app.app.dependency_overrides.pop(get_supabase_and_groq, None)
    nova_app.app.dependency_overrides.pop(get_current_user_id, None)


def test_add_subject_auto_matched(client, monkeypatch):
    monkeypatch.setattr(
        subjects_router,
        "get_user_institution_and_campus",
        lambda *a, **kw: ("inst-1", "campus-1"),
    )
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

    resp = client.post(f"/subjects/{USER_ID}/add", json={"query": "OS", "semester": "sem1"})

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "matched"
    assert body["user_subject"]["id"] == "us1"
    assert body["user_subject"]["subject_id"] == "s1"
    assert body["candidates"] == []


def test_add_subject_needs_confirmation(client, monkeypatch):
    monkeypatch.setattr(
        subjects_router,
        "get_user_institution_and_campus",
        lambda *a, **kw: ("inst-1", "campus-1"),
    )
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

    resp = client.post(f"/subjects/{USER_ID}/add", json={"query": "Systms", "semester": "sem1"})

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "needs_confirmation"
    assert body["user_subject"] is None
    assert body["match_log_id"] == "log-1"
    assert len(body["candidates"]) == 1
    assert body["candidates"][0]["id"] == "s1"
    # A needs-confirmation outcome must never write a user_subjects row itself.
    create_called.assert_not_called()


def test_add_subject_rejects_when_profile_has_no_institution(client, monkeypatch):
    """institution_id/campus_id are derived from the user's own profile, not
    the request body - if the profile has no institution set yet, the
    request is rejected before any matching happens."""
    monkeypatch.setattr(
        subjects_router,
        "get_user_institution_and_campus",
        lambda *a, **kw: (None, None),
    )
    match_called = MagicMock()
    monkeypatch.setattr(subjects_router, "match_subject", match_called)

    resp = client.post(f"/subjects/{USER_ID}/add", json={"query": "OS", "semester": "sem1"})

    assert resp.status_code == 400
    match_called.assert_not_called()


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
    assert resolve_called.call_args.args[1:] == ("log-1", USER_ID, "s1", None)


def test_confirm_subject_with_none_of_these_creates_custom_subject(client, monkeypatch):
    monkeypatch.setattr(
        subjects_router,
        "get_user_institution_and_campus",
        lambda *a, **kw: ("inst-server", "campus-server"),
    )
    create_custom_called = MagicMock(return_value="custom-9")
    monkeypatch.setattr(subjects_router, "create_custom_subject", create_custom_called)
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
    # institution_id must come from the caller's own profile, never the
    # request body - NewCustomSubject no longer even accepts the field.
    create_custom_called.assert_called_once()
    assert create_custom_called.call_args.args[1:] == (
        "inst-server",
        "CS999",
        "Underwater Basket Weaving",
        3,
    )


def test_confirm_subject_rejects_match_log_not_owned_by_caller(client, monkeypatch):
    """resolve_match_log scopes its UPDATE to the caller's own user_id - a
    match_log_id belonging to (or nonexistent for) someone else must 404,
    not silently succeed or leak whether the row exists. This check must
    also happen before create_user_subject runs, so a 404 here never leaves
    an orphaned user_subjects row behind."""
    create_user_subject_called = MagicMock()
    monkeypatch.setattr(subjects_router, "create_user_subject", create_user_subject_called)

    def _raise_not_owned(*a, **kw):
        raise ValueError("No subject_match_log row log-1 for this student")

    monkeypatch.setattr(subjects_router, "resolve_match_log", _raise_not_owned)

    resp = client.post(
        f"/subjects/{USER_ID}/confirm",
        json={"semester": "sem1", "match_log_id": "log-1", "subject_id": "s1"},
    )

    assert resp.status_code == 404
    create_user_subject_called.assert_not_called()


def test_confirm_subject_rejects_subject_id_from_another_institution(client, monkeypatch):
    """subject_id is client-supplied input - if it doesn't belong to the
    caller's own institution, the request must 404 before any write, not
    silently enroll them in (or leak the existence of) another
    institution's catalog subject."""
    create_user_subject_called = MagicMock()
    monkeypatch.setattr(subjects_router, "create_user_subject", create_user_subject_called)

    def _raise_wrong_institution(*a, **kw):
        raise ValueError("Subject not found for your institution.")

    monkeypatch.setattr(subjects_router, "verify_subject_belongs_to_institution", _raise_wrong_institution)

    resp = client.post(
        f"/subjects/{USER_ID}/confirm",
        json={"semester": "sem1", "subject_id": "s1"},
    )

    assert resp.status_code == 404
    create_user_subject_called.assert_not_called()


def test_confirm_subject_rejects_custom_subject_id_from_another_institution(client, monkeypatch):
    """Same shape as the subject_id check, for custom_subject_id."""
    create_user_subject_called = MagicMock()
    monkeypatch.setattr(subjects_router, "create_user_subject", create_user_subject_called)

    def _raise_wrong_institution(*a, **kw):
        raise ValueError("Custom subject not found for your institution.")

    monkeypatch.setattr(subjects_router, "verify_custom_subject_belongs_to_institution", _raise_wrong_institution)

    resp = client.post(
        f"/subjects/{USER_ID}/confirm",
        json={"semester": "sem1", "custom_subject_id": "c1"},
    )

    assert resp.status_code == 404
    create_user_subject_called.assert_not_called()


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


def test_add_subject_rejects_path_user_id_mismatch(client):
    """The authenticated user must match the {user_id} path param, or the
    request is rejected before any matching/service logic runs."""
    resp = client.post(
        "/subjects/someone-else/add",
        json={"query": "OS", "semester": "sem1"},
    )
    assert resp.status_code == 403


class _FakeFilteredResult:
    def __init__(self, data):
        self.data = data


class _FakeSubjectsTable:
    """Minimal fluent stand-in for the `subjects` postgrest builder that
    actually applies .eq() filters (unlike the generic MagicMock client used
    elsewhere in this file), so it can distinguish "right institution, wrong
    campus" from a genuine match."""

    def __init__(self, rows):
        self._rows = rows
        self._filters: dict[str, object] = {}

    def select(self, *_a, **_kw):
        return self

    def eq(self, field, value):
        self._filters[field] = value
        return self

    def limit(self, *_a, **_kw):
        return self

    def execute(self):
        matched = [
            row for row in self._rows if all(row.get(k) == v for k, v in self._filters.items())
        ]
        return _FakeFilteredResult(matched)


class _FakeSupabaseWithSubjects:
    def __init__(self, subjects_rows):
        self._subjects = _FakeSubjectsTable(subjects_rows)

    def table(self, name):
        assert name == "subjects"
        return self._subjects


def test_confirm_subject_rejects_subject_id_from_different_campus(client, monkeypatch):
    """Mirrors _get_candidate_pool's own institution+campus scoping: a
    subject_id that belongs to the caller's institution but a different
    campus must 404, same as it would never have been offered as a match
    candidate in the first place."""
    monkeypatch.setattr(
        subjects_router,
        "get_user_institution_and_campus",
        lambda *a, **kw: ("inst-1", "campus-1"),
    )
    fake_supabase = _FakeSupabaseWithSubjects(
        [{"id": "s1", "institution_id": "inst-1", "campus_id": "campus-2"}]
    )
    nova_app.app.dependency_overrides[get_supabase_and_groq] = lambda: (fake_supabase, MagicMock(), None)

    create_user_subject_called = MagicMock()
    monkeypatch.setattr(subjects_router, "create_user_subject", create_user_subject_called)

    resp = client.post(
        f"/subjects/{USER_ID}/confirm",
        json={"semester": "sem1", "subject_id": "s1"},
    )

    assert resp.status_code == 404
    create_user_subject_called.assert_not_called()


def test_confirm_subject_rejects_path_user_id_mismatch(client):
    resp = client.post(
        "/subjects/someone-else/confirm",
        json={"semester": "sem1", "subject_id": "s1"},
    )
    assert resp.status_code == 403

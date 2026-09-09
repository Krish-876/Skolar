"""
Unit tests for nova/services/subject_matcher.py - the AI-assisted subject
matching used by the onboarding/subject-add flow. Groq and Supabase are both
faked; no network calls.
"""

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import nova.services.subject_matcher as matcher_mod  # noqa: E402

USER_ID = "user-1"
INSTITUTION_ID = "inst-1"
CAMPUS_ID = "campus-1"

SUBJECT_ROWS = [{"id": "s1", "name": "Operating Systems", "short_name": "OS"}]
CUSTOM_ROWS: list[dict] = []


class _FakeResult:
    def __init__(self, data):
        self.data = data


class _FakeTable:
    """Minimal fluent stand-in for a postgrest table builder. select/eq are
    no-ops that just return self; insert/upsert/update stage a row that the
    next execute() returns, mirroring what real Supabase responses shape
    (a list with the affected row)."""

    def __init__(self, select_data):
        self._select_data = select_data
        self._pending = None
        self.inserted: list[dict] = []
        self.updated: list[dict] = []

    def select(self, *_a, **_kw):
        return self

    def eq(self, *_a, **_kw):
        return self

    def insert(self, payload):
        row = {**payload, "id": payload.get("id") or f"row-{len(self.inserted) + 1}"}
        self.inserted.append(row)
        self._pending = row
        return self

    def upsert(self, payload, **_kw):
        row = {**payload, "id": payload.get("id") or "custom-1"}
        self._pending = row
        return self

    def update(self, payload):
        self.updated.append(payload)
        self._pending = payload
        return self

    def execute(self):
        if self._pending is not None:
            data, self._pending = [self._pending], None
            return _FakeResult(data)
        return _FakeResult(self._select_data)


class _FakeSupabase:
    def __init__(self, subjects=SUBJECT_ROWS, custom_subjects=CUSTOM_ROWS):
        self._tables = {
            "subjects": _FakeTable(subjects),
            "custom_subjects": _FakeTable(custom_subjects),
            "subject_match_log": _FakeTable([]),
        }

    def table(self, name):
        return self._tables[name]


def _fake_groq(content: dict) -> MagicMock:
    groq = MagicMock()
    response = MagicMock()
    response.choices = [MagicMock(message=MagicMock(content=json.dumps(content)))]
    groq.chat.completions.create.return_value = response
    return groq


# ── confident matches ───────────────────────────────────────────────────────


def test_match_subject_resolves_a_typo():
    supabase = _FakeSupabase()
    groq = _fake_groq({"match": True, "subject_id": "s1", "confidence": 0.93})

    result = matcher_mod.match_subject(
        groq, supabase, USER_ID, "Operatng Systems", INSTITUTION_ID, CAMPUS_ID
    )

    assert result.matched is True
    assert result.subject_id == "s1"
    assert result.source == "subject"
    assert result.candidates == []
    # A confident match is never logged - only ambiguous/no-match attempts are.
    assert supabase.table("subject_match_log").inserted == []


def test_match_subject_resolves_an_abbreviation():
    supabase = _FakeSupabase()
    groq = _fake_groq({"match": True, "subject_id": "s1", "confidence": 0.88})

    result = matcher_mod.match_subject(groq, supabase, USER_ID, "OS", INSTITUTION_ID, CAMPUS_ID)

    assert result.matched is True
    assert result.subject_id == "s1"
    assert result.source == "subject"


# ── no confident match ──────────────────────────────────────────────────────


def test_match_subject_returns_no_candidates_when_genuinely_unrelated():
    supabase = _FakeSupabase()
    groq = _fake_groq({"match": False, "candidates": []})

    result = matcher_mod.match_subject(
        groq, supabase, USER_ID, "Underwater Basket Weaving", INSTITUTION_ID, CAMPUS_ID
    )

    assert result.matched is False
    assert result.candidates == []
    assert result.match_log_id is not None

    logged = supabase.table("subject_match_log").inserted
    assert len(logged) == 1
    assert logged[0]["status"] == "no_match"
    assert logged[0]["query_text"] == "Underwater Basket Weaving"


def test_match_subject_returns_candidates_for_disambiguation():
    supabase = _FakeSupabase()
    groq = _fake_groq(
        {"match": False, "candidates": [{"id": "s1", "name": "Operating Systems", "confidence": 0.4}]}
    )

    result = matcher_mod.match_subject(groq, supabase, USER_ID, "Systems", INSTITUTION_ID, CAMPUS_ID)

    assert result.matched is False
    assert len(result.candidates) == 1
    assert result.candidates[0].id == "s1"
    assert result.candidates[0].source == "subject"

    logged = supabase.table("subject_match_log").inserted
    assert logged[0]["status"] == "disambiguation"


def test_match_subject_downgrades_below_threshold_match_to_no_match():
    """A model that says match=true but reports low confidence must not be
    trusted at face value - SUBJECT_MATCH_CONFIDENCE_THRESHOLD governs the
    actual auto-select decision, not the model's own boolean."""
    supabase = _FakeSupabase()
    below_threshold = matcher_mod.SUBJECT_MATCH_CONFIDENCE_THRESHOLD - 0.1
    groq = _fake_groq({"match": True, "subject_id": "s1", "confidence": below_threshold})

    result = matcher_mod.match_subject(groq, supabase, USER_ID, "Sys", INSTITUTION_ID, CAMPUS_ID)

    assert result.matched is False


def test_match_subject_ignores_hallucinated_candidate_ids():
    """A candidate id the model invents (not in the actual pool) must never
    reach the caller - it isn't a real row to disambiguate against."""
    supabase = _FakeSupabase()
    groq = _fake_groq(
        {"match": False, "candidates": [{"id": "does-not-exist", "name": "Ghost Subject", "confidence": 0.9}]}
    )

    result = matcher_mod.match_subject(groq, supabase, USER_ID, "Ghost", INSTITUTION_ID, CAMPUS_ID)

    assert result.candidates == []


def test_match_subject_with_empty_candidate_pool_logs_no_match_without_calling_model():
    supabase = _FakeSupabase(subjects=[], custom_subjects=[])
    groq = _fake_groq({"match": False, "candidates": []})

    result = matcher_mod.match_subject(groq, supabase, USER_ID, "Anything", INSTITUTION_ID, CAMPUS_ID)

    assert result.matched is False
    assert result.match_log_id is not None
    groq.chat.completions.create.assert_not_called()

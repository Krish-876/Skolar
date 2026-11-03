"""
Regression test for the ILIKE wildcard bug in _confirm_career_unit
(backend/nova/services/proposals_service.py).

.ilike("name", name) used to pass the proposed career-unit name straight
through to Postgres as a raw ILIKE pattern. Postgrest-py does not escape
`%`/`_` before sending it (see postgrest.SyncFilterRequestBuilder.filter),
so those characters in a *legitimate* name acted as SQL wildcards: a name
like "100% Placement Prep" would wildcard-match an unrelated existing row
like "100X Placement Prep" (the `%` swallowing the "X"), and an `_` would
match any single character in that position. Confirmed against a real
throwaway Postgres instance before this fix. Now fixed by comparing
name.strip().lower() in Python (same pattern as _resolve_career_unit_id).

Real Supabase test, not mocked - gated behind RUN_NOVA_E2E, same flag as
test_nova_proposals_e2e.py, but this test calls _confirm_career_unit
directly and makes no Groq calls, so GROQ_API_KEY is not required. Run in
isolation:

    cd backend
    RUN_NOVA_E2E=1 ./venv/Scripts/python.exe -m pytest tests/test_career_unit_ilike_regression.py -v -s

Requires SUPABASE_URL, SUPABASE_KEY (service/secret key - this test uses
auth.admin.create_user/delete_user, which the anon key can't do) in .env.
"""

import os
import sys
import uuid
from typing import Any

import pytest
from dotenv import load_dotenv

load_dotenv()

RUN_E2E = os.environ.get("RUN_NOVA_E2E") == "1"
_MISSING_ENV = [v for v in ("SUPABASE_URL", "SUPABASE_KEY") if not os.environ.get(v)]

pytestmark = pytest.mark.skipif(
    not RUN_E2E,
    reason="Live Supabase regression test - set RUN_NOVA_E2E=1 to run it (real writes).",
)

if RUN_E2E and _MISSING_ENV:
    pytest.skip(f"Missing required env var(s) for the live run: {_MISSING_ENV}", allow_module_level=True)

# backend/ (this file's parent dir) needs to be on sys.path to import `nova.*`,
# regardless of the cwd pytest was invoked from.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from supabase import Client, create_client  # noqa: E402

from nova.services.proposals_service import _confirm_career_unit  # noqa: E402


@pytest.fixture(scope="module")
def supabase() -> Client:
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


@pytest.fixture
def test_user(supabase):
    """Fresh throwaway student per test. Deletes it (cascading to
    career_units per its ON DELETE CASCADE FK to users) afterward, then
    asserts the cascade actually left no stray rows."""
    email = f"nova-ilike-{uuid.uuid4().hex[:10]}@skolar-test.local"
    auth_res = supabase.auth.admin.create_user(
        {"email": email, "password": "NovaIlikeTest123!", "email_confirm": True}
    )
    user_id = auth_res.user.id
    supabase.table("users").insert(
        {"id": user_id, "email": email, "full_name": "Nova ILIKE Regression Test User", "role": "student"}
    ).execute()

    yield user_id

    supabase.auth.admin.delete_user(user_id)
    leftover = supabase.table("career_units").select("id").eq("user_id", user_id).execute().data
    assert leftover == [], f"Teardown left stray career_units row(s) for {user_id}: {leftover}"


def _proposal(name: str) -> dict[str, Any]:
    return {"payload": {"name": name, "description": None}}


def _insert_career_unit(supabase: Client, user_id: str, name: str) -> dict[str, Any]:
    return (
        supabase.table("career_units")
        .insert({"user_id": user_id, "name": name, "confirmed_at": None})
        .execute()
        .data[0]
    )


def test_percent_in_name_does_not_wildcard_crossmatch(supabase, test_user):
    """"100% Placement Prep" must match only its own exact row, not
    "100X Placement Prep" - previously the % swallowed the "X" under
    ILIKE's wildcard semantics."""
    row_a = _insert_career_unit(supabase, test_user, "100% Placement Prep")
    row_b = _insert_career_unit(supabase, test_user, "100X Placement Prep")

    resulting_id = _confirm_career_unit(supabase, test_user, _proposal("100% Placement Prep"))

    assert resulting_id == row_a["id"], (
        f"expected the exact match against row_a ({row_a['id']}), got {resulting_id} - "
        "the % likely wildcard-matched row_b instead of/as well as row_a"
    )
    row_b_after = supabase.table("career_units").select("confirmed_at").eq("id", row_b["id"]).execute().data[0]
    assert row_b_after["confirmed_at"] is None, "unrelated row_b must not have been touched"


def test_underscore_in_name_does_not_wildcard_crossmatch(supabase, test_user):
    """An `_` standing in for a single character must not wildcard-match
    an unrelated row that happens to have any character in that position."""
    row_a = _insert_career_unit(supabase, test_user, "100_ Placement Prep")
    row_b = _insert_career_unit(supabase, test_user, "100X Placement Prep")

    resulting_id = _confirm_career_unit(supabase, test_user, _proposal("100_ Placement Prep"))

    assert resulting_id == row_a["id"], (
        f"expected the exact match against row_a ({row_a['id']}), got {resulting_id} - "
        "the _ likely wildcard-matched row_b instead of/as well as row_a"
    )
    row_b_after = supabase.table("career_units").select("confirmed_at").eq("id", row_b["id"]).execute().data[0]
    assert row_b_after["confirmed_at"] is None, "unrelated row_b must not have been touched"


def test_exact_case_insensitive_match_still_works(supabase, test_user):
    """The fix must not regress the actual intended behavior: a
    differently-cased repeat of an existing name should still resolve to
    that same row (pause/resume design), not create a duplicate."""
    row = _insert_career_unit(supabase, test_user, "Data Structures Track")

    resulting_id = _confirm_career_unit(supabase, test_user, _proposal("data structures track"))

    assert resulting_id == row["id"]
    all_rows = supabase.table("career_units").select("id").eq("user_id", test_user).execute().data
    assert len(all_rows) == 1, f"expected no duplicate row to be created, got: {all_rows}"

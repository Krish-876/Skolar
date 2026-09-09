"""
Real end-to-end smoke test for the Nova conversation proposals flow
(spec.md §5): a chat turn proposes a fact -> it's staged, inert, in
nova_unconfirmed_proposals -> the student confirms or rejects the whole
turn -> confirm writes the real row (and supersedes the prior active one
for the same unit, per §2a's contradiction rule); reject writes nothing.

Makes REAL, BILLED Groq calls and REAL Supabase writes. NOT part of the
default suite - gated behind RUN_NOVA_E2E=1 so it can never fire by
accident (e.g. once the unrelated collection-time hang elsewhere in
backend/tests/ is fixed and someone runs the full suite unfiltered).

Run in isolation, not via the full suite - pytest still imports every
module under tests/ to collect it even with -k, which is what triggers
that unrelated hang. Pointing pytest directly at this file avoids it:

    cd backend
    RUN_NOVA_E2E=1 ./venv/Scripts/python.exe -m pytest tests/test_nova_proposals_e2e.py -v -s

Requires SUPABASE_URL, SUPABASE_KEY, GROQ_API_KEY in .env (repo root - bare
load_dotenv() finds it by walking up from backend/, same as test_rls.py).
SUPABASE_KEY must be the service/secret key: this test uses
supabase.auth.admin.create_user/delete_user, which the anon key can't do.

Test user: created fresh per test via the Supabase Auth admin API (email
like nova-e2e-<random>@skolar-test.local), not any real account. This
repo's documented seeded test users (TEST_STUDENT_A_EMAIL/B in
test_rls.py) do not actually exist in this project - signing in with the
documented defaults fails with "Invalid login credentials" and the env
vars aren't set - and the only two real rows in `users` belong to actual
people, not safe to write standing_flags/etc. against. Deleting the auth
user in teardown cascades to public.users and every Nova table FK'd to it
(standing_flags, situation_flags, nova_history, career_units,
nova_unconfirmed_proposals all have ON DELETE CASCADE back to users, the
last one from this feature's own migration) - teardown then explicitly
re-queries those tables rather than trusting the cascade blindly.
"""

import os
import sys
import uuid

import pytest
from dotenv import load_dotenv

load_dotenv()

RUN_E2E = os.environ.get("RUN_NOVA_E2E") == "1"
_MISSING_ENV = [v for v in ("SUPABASE_URL", "SUPABASE_KEY", "GROQ_API_KEY") if not os.environ.get(v)]

pytestmark = pytest.mark.skipif(
    not RUN_E2E,
    reason="Live Groq/Supabase E2E test - set RUN_NOVA_E2E=1 to run it (billed Groq calls + real writes).",
)

if RUN_E2E and _MISSING_ENV:
    pytest.skip(f"Missing required env var(s) for the live E2E run: {_MISSING_ENV}", allow_module_level=True)

# backend/ (this file's parent dir) needs to be on sys.path to import `nova.*`,
# regardless of the cwd pytest was invoked from.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient  # noqa: E402
from nova.services.clients import get_clients  # noqa: E402
import nova.api.main as nova_app  # noqa: E402

# Every table a confirmed/rejected proposal could touch - teardown checks
# all of them are empty for the test user, not just the ones a given test
# happened to exercise.
NOVA_TABLES = [
    "nova_unconfirmed_proposals",
    "standing_flags",
    "situation_flags",
    "nova_history",
    "career_units",
]

_FLAG_KIND_TO_TABLE = {
    "standing_flag": "standing_flags",
    "situation_flag": "situation_flags",
    "nova_history": "nova_history",
}


@pytest.fixture(scope="module")
def supabase():
    client, _groq, _groq_backup = get_clients()
    return client


@pytest.fixture(scope="module")
def api_client():
    return TestClient(nova_app.app)


@pytest.fixture
def test_user(supabase):
    """Fresh throwaway student per test. Deletes it (cascading) afterward,
    then asserts every Nova table is actually clean rather than assuming
    the cascade fired."""
    email = f"nova-e2e-{uuid.uuid4().hex[:10]}@skolar-test.local"
    auth_res = supabase.auth.admin.create_user(
        {"email": email, "password": "NovaE2ETest123!", "email_confirm": True}
    )
    user_id = auth_res.user.id
    supabase.table("users").insert(
        {"id": user_id, "email": email, "full_name": "Nova E2E Test User", "role": "student"}
    ).execute()

    yield user_id

    supabase.auth.admin.delete_user(user_id)

    for table in NOVA_TABLES:
        leftover = supabase.table(table).select("id").eq("user_id", user_id).execute().data
        assert leftover == [], (
            f"Teardown left {len(leftover)} stray row(s) in {table} for {user_id} - "  # noqa: S608 -- table is from the hardcoded NOVA_TABLES list above, not external input
            "cascade delete from users did not fully clean up."
        )
    remaining_user = supabase.table("users").select("id").eq("id", user_id).execute().data
    assert remaining_user == [], "Teardown left the test user's `users` row behind."


def _get_proposal_row(supabase, proposal_id: str) -> dict:
    rows = supabase.table("nova_unconfirmed_proposals").select("*").eq("id", proposal_id).execute().data
    assert rows, f"proposal {proposal_id} is missing from nova_unconfirmed_proposals"
    return rows[0]


def test_propose_confirm_writes_and_supersedes(api_client, supabase, test_user):
    """Steps 1-5 of the requested sequence: propose a standing flag,
    confirm the turn, verify the staging row and the real standing_flags
    row it produced, then send a contradicting statement and verify the
    old row is superseded (not deleted) while a fresh facts fetch shows
    only the new one as current."""

    # --- Step 1: chat proposes a fact ---
    r1 = api_client.post(
        f"/chat/{test_user}",
        json={
            "question": (
                "From now on, always give me a 20 minute buffer before any exam. "
                "Please remember that going forward."
            )
        },
    )
    assert r1.status_code == 200, r1.text
    body1 = r1.json()

    assert body1.get("turn_id"), f"expected a non-empty turn_id, got: {body1}"
    assert len(body1.get("pending_proposals", [])) >= 1, f"expected >=1 proposal, got: {body1}"
    proposal = body1["pending_proposals"][0]
    assert proposal["kind"] == "standing_flag", (
        f"expected the model to classify a durable instruction as standing_flag, got: {proposal}"
    )
    turn_id = body1["turn_id"]

    # --- Step 2: GET pending matches what came back inline ---
    r2 = api_client.get(f"/proposals/{test_user}/pending")
    assert r2.status_code == 200, r2.text
    pending = r2.json()["proposals"]
    matched = next((p for p in pending if p["id"] == proposal["id"]), None)
    assert matched is not None, f"proposal {proposal['id']} not found in pending list: {pending}"
    assert matched["turn_id"] == turn_id
    assert matched["kind"] == "standing_flag"
    assert matched["summary"] == proposal["summary"]

    # --- Step 3: confirm the turn ---
    r3 = api_client.post(f"/proposals/{test_user}/turn/{turn_id}/confirm")
    assert r3.status_code == 200, r3.text
    resolutions = r3.json()["resolutions"]
    assert len(resolutions) == 1, resolutions
    resolution = resolutions[0]
    assert resolution["id"] == proposal["id"]
    assert resolution["status"] == "confirmed"
    assert resolution["resulting_row_id"], resolution

    # --- Step 4: staging row + real target-table row ---
    staged = _get_proposal_row(supabase, proposal["id"])
    assert staged["status"] == "confirmed"
    assert staged["resolved_at"] is not None
    assert staged["resulting_row_id"] == resolution["resulting_row_id"]

    sf_rows = (
        supabase.table("standing_flags").select("*").eq("id", resolution["resulting_row_id"]).execute().data
    )
    assert len(sf_rows) == 1, sf_rows
    sf = sf_rows[0]
    assert sf["user_id"] == test_user
    assert sf["confirmed_at"] is not None
    assert sf["superseded_at"] is None
    # Fresh test user has no enrolled subjects/career units - this must be
    # a user-level flag, not silently mis-scoped to some other unit.
    assert sf["user_subject_id"] is None
    assert sf["career_unit_id"] is None
    assert "buffer" in sf["instruction_text"].lower(), sf["instruction_text"]

    # --- Step 5: a contradicting statement should supersede the row above ---
    r4 = api_client.post(
        f"/chat/{test_user}",
        json={
            "question": (
                "Actually, I changed my mind. Please forget the exam buffer instruction "
                "and remember instead that I don't want any buffer time before exams "
                "anymore - I prefer diving straight in."
            )
        },
    )
    assert r4.status_code == 200, r4.text
    body2 = r4.json()
    assert body2.get("turn_id"), f"expected a turn_id for the contradicting turn, got: {body2}"
    assert len(body2.get("pending_proposals", [])) >= 1, f"expected >=1 proposal, got: {body2}"
    proposal2 = body2["pending_proposals"][0]
    turn_id2 = body2["turn_id"]

    r5 = api_client.post(f"/proposals/{test_user}/turn/{turn_id2}/confirm")
    assert r5.status_code == 200, r5.text
    resolution2 = r5.json()["resolutions"][0]
    assert resolution2["id"] == proposal2["id"]
    new_row_id = resolution2["resulting_row_id"]
    assert new_row_id, resolution2
    assert new_row_id != resolution["resulting_row_id"], "expected a distinct new standing_flags row"

    old_row = supabase.table("standing_flags").select("*").eq("id", resolution["resulting_row_id"]).execute().data[0]
    assert old_row["superseded_at"] is not None, (
        f"old standing_flags row {resolution['resulting_row_id']} was not marked superseded: {old_row}"
    )

    new_row = supabase.table("standing_flags").select("*").eq("id", new_row_id).execute().data[0]
    assert new_row["superseded_at"] is None
    assert new_row["supersedes_id"] == resolution["resulting_row_id"], (
        f"expected supersedes_id to point at the old row, got: {new_row}"
    )

    # A fresh facts fetch must reflect the new row as current, not the old one.
    facts = api_client.get(f"/facts/{test_user}")
    assert facts.status_code == 200, facts.text
    active_flags = facts.json()["snapshot"]["standing_flags"]
    active_ids = {f["id"] for f in active_flags}
    assert new_row_id in active_ids, f"new row not in facts snapshot: {active_flags}"
    assert resolution["resulting_row_id"] not in active_ids, (
        f"superseded row should not appear as current: {active_flags}"
    )


def test_reject_writes_nothing(api_client, supabase, test_user):
    """Step 6: propose a fact, reject it instead of confirming - nothing
    lands in the target table and the staging row reflects rejection."""

    r1 = api_client.post(
        f"/chat/{test_user}",
        json={
            "question": (
                "Just so you know, I'm feeling under the weather this week and might "
                "be slower than usual - please note that."
            )
        },
    )
    assert r1.status_code == 200, r1.text
    body = r1.json()
    assert body.get("turn_id"), f"expected a turn_id, got: {body}"
    assert len(body.get("pending_proposals", [])) >= 1, f"expected >=1 proposal, got: {body}"
    proposal = body["pending_proposals"][0]
    turn_id = body["turn_id"]
    assert proposal["kind"] in _FLAG_KIND_TO_TABLE, (
        f"unexpected proposal kind for a situational statement: {proposal}"
    )

    r2 = api_client.post(f"/proposals/{test_user}/turn/{turn_id}/reject")
    assert r2.status_code == 200, r2.text
    resolution = r2.json()["resolutions"][0]
    assert resolution["id"] == proposal["id"]
    assert resolution["status"] == "rejected"
    assert resolution["resulting_row_id"] is None

    staged = _get_proposal_row(supabase, proposal["id"])
    assert staged["status"] == "rejected"
    assert staged["resolved_at"] is not None
    assert staged["resulting_row_id"] is None

    table = _FLAG_KIND_TO_TABLE[proposal["kind"]]
    rows = supabase.table(table).select("id").eq("user_id", test_user).execute().data
    assert rows == [], f"reject should not have written to {table}, found: {rows}"

"""
RLS isolation tests for `subject_match_log` (AI-assisted subject matching's
ambiguous/no-match log). Same shape as test_rls.py, but not folded into that
file's generic `_seed_test_record`/`USER_TABLES_TO_TEST` harness: that
harness seeds rows via the authenticated student client itself, which only
works for tables with an INSERT policy for `authenticated`. subject_match_log
deliberately has none (same reasoning as nova_unconfirmed_proposals - only
the backend, via the service-role key, ever writes it) - rows here are
seeded with the service-role client instead, and a real student client is
also checked to confirm it's refused on INSERT.

Needs two real Supabase Auth accounts to sign in as (TEST_STUDENT_A_EMAIL/
TEST_STUDENT_B_EMAIL) - not run against a mocked backend. Not currently run
in CI (see test_rls.py) - run manually:

    cd backend
    pytest tests/test_subject_match_log_rls.py
"""

import os
import uuid

import pytest
from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

STUDENT_A_EMAIL = os.getenv("TEST_STUDENT_A_EMAIL", "student_a@test.com")
STUDENT_A_PASSWORD = os.getenv("TEST_STUDENT_A_PASSWORD", "TestPassword123!")
STUDENT_B_EMAIL = os.getenv("TEST_STUDENT_B_EMAIL", "student_b@test.com")
STUDENT_B_PASSWORD = os.getenv("TEST_STUDENT_B_PASSWORD", "TestPassword123!")

if not SUPABASE_URL or not SUPABASE_KEY:
    pytest.skip("Supabase environment variables not set. Skipping RLS tests.", allow_module_level=True)


@pytest.fixture
def service_client() -> Client:
    """Same key backend/nova uses in production - bypasses RLS. Used only to
    seed/clean up rows; every isolation assertion goes through a real
    authenticated per-student client instead."""
    return create_client(SUPABASE_URL, SUPABASE_KEY)


@pytest.fixture
def anon_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)


@pytest.fixture
def authenticated_clients():
    client_a = create_client(SUPABASE_URL, SUPABASE_KEY)
    client_b = create_client(SUPABASE_URL, SUPABASE_KEY)
    try:
        session_a = client_a.auth.sign_in_with_password(
            {"email": STUDENT_A_EMAIL, "password": STUDENT_A_PASSWORD}
        )
        session_b = client_b.auth.sign_in_with_password(
            {"email": STUDENT_B_EMAIL, "password": STUDENT_B_PASSWORD}
        )
        return client_a, client_b, session_a.user.id, session_b.user.id
    except Exception as e:
        pytest.skip(f"Test user authentication unavailable: {e}")


def _seed_log_row(service_client: Client, user_id: str) -> str:
    inst_rows = service_client.table("subjects").select("institution_id").limit(1).execute().data
    if not inst_rows:
        pytest.fail(
            "Cannot seed subject_match_log: no rows in 'subjects' to source an "
            "institution_id from (its FK-adjacent column isn't actually a FK, "
            "but a real institution_id keeps this test representative)."
        )
    row_id = str(uuid.uuid4())
    payload = {
        "id": row_id,
        "user_id": user_id,
        "institution_id": inst_rows[0]["institution_id"],
        "query_text": "rls isolation test",
        "status": "no_match",
        "candidates": [],
    }
    res = service_client.table("subject_match_log").insert(payload).execute()
    assert res.data, f"Seeding failed: {res}"
    return row_id


def test_unauthenticated_client_cannot_read_subject_match_log(anon_client: Client):
    response = anon_client.table("subject_match_log").select("*").execute()
    assert len(response.data) == 0, (
        f"RLS Failure: unauthenticated client read {len(response.data)} row(s) from subject_match_log"
    )


def test_student_cannot_read_another_students_subject_match_log(authenticated_clients, service_client: Client):
    client_a, client_b, user_a_id, _user_b_id = authenticated_clients
    row_id = _seed_log_row(service_client, user_a_id)
    try:
        cross_read = client_b.table("subject_match_log").select("*").eq("id", row_id).execute()
        assert len(cross_read.data) == 0, "RLS Failure: Student B read Student A's subject_match_log row"

        own_read = client_a.table("subject_match_log").select("*").eq("id", row_id).execute()
        assert len(own_read.data) == 1, "Student A could not read their own subject_match_log row"
    finally:
        service_client.table("subject_match_log").delete().eq("id", row_id).execute()


def test_authenticated_client_cannot_insert_directly(authenticated_clients):
    """Only the service-role backend writes this table - a student's own
    client must be refused, matching nova_unconfirmed_proposals' policy
    shape (SELECT-only for `authenticated`, no INSERT policy at all)."""
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    with pytest.raises(Exception):
        client_a.table("subject_match_log").insert(
            {
                "user_id": user_a_id,
                "institution_id": str(uuid.uuid4()),
                "query_text": "should be rejected",
                "status": "no_match",
                "candidates": [],
            }
        ).execute()

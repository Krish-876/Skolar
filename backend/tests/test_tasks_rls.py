"""
RLS + RPC tests for `tasks` and the `complete_task` RPC (TASKS_PLAN.md Phase 1).

Same shape as test_subject_match_log_rls.py: `tasks` has no INSERT/UPDATE/
DELETE policy for `authenticated` at all (only SELECT), so rows are seeded
with the service-role client and a real student client is checked to
confirm it's refused on direct writes. The only way a student client can
change a task is through the `complete_task` RPC.

Needs two real Supabase Auth accounts to sign in as (TEST_STUDENT_A_EMAIL/
TEST_STUDENT_B_EMAIL) and the migration in
20261012143354_add_tasks_and_complete_task_rpc.sql applied - not run against
a mocked backend. The anon-key test additionally needs SUPABASE_ANON_KEY (the
project's real publishable key, e.g. from lib/main.dart's `anonKey`, not
SUPABASE_KEY - that's the service-role secret and would bypass RLS, making
an "anon" check that uses it meaningless) and skips on its own if that's
unset. Not currently run in CI (see test_rls.py) - run manually:

    cd backend
    pytest tests/test_tasks_rls.py
"""

import os
import uuid
from datetime import date

import pytest
from dotenv import load_dotenv
from postgrest.exceptions import APIError
from supabase import Client, create_client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")

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
    """A real anon/publishable key, not SUPABASE_KEY (the service-role
    secret). Using the secret key here would bypass RLS entirely and make
    this fixture lie about being unauthenticated - it would "pass" even if
    the anon policy were wrong."""
    if not SUPABASE_ANON_KEY:
        pytest.skip("SUPABASE_ANON_KEY not set. Skipping anon-key RLS tests.")
    return create_client(SUPABASE_URL, SUPABASE_ANON_KEY)


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


def _task_payload(user_id: str, *, status: str = "pending", timer_seconds: int = 1500) -> dict:
    today_str = date.today().isoformat()
    return {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "week_start": today_str,
        "planned_for": today_str,
        "topic": "Mathematics",
        "title": "Calculus Integration",
        "timer_seconds": timer_seconds,
        "priority": 1,
        "reason": "Test reasoning",
        "status": status,
        "completed_at": "now()" if status == "done" else None,
    }


def _seed_task(service_client: Client, user_id: str, *, status: str = "pending", timer_seconds: int = 1500) -> str:
    payload = _task_payload(user_id, status=status, timer_seconds=timer_seconds)
    if status == "done":
        # completed_at can't be the literal string "now()" over PostgREST -
        # use a real timestamp instead.
        payload["completed_at"] = date.today().isoformat() + "T00:00:00Z"
    else:
        payload.pop("completed_at", None)
    res = service_client.table("tasks").insert(payload).execute()
    assert res.data, f"Seeding failed: {res}"
    return res.data[0]["id"]


def test_unauthenticated_client_cannot_read_tasks(anon_client: Client):
    response = anon_client.table("tasks").select("*").execute()
    assert len(response.data) == 0, f"RLS Failure: unauthenticated client read {len(response.data)} row(s) from tasks"


def test_student_cannot_read_another_students_tasks(authenticated_clients, service_client: Client):
    client_a, client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id)
    try:
        cross_read = client_b.table("tasks").select("*").eq("id", task_id).execute()
        assert len(cross_read.data) == 0, "RLS Failure: Student B read Student A's task"

        own_read = client_a.table("tasks").select("*").eq("id", task_id).execute()
        assert len(own_read.data) == 1, "Student A could not read their own task"
    finally:
        service_client.table("tasks").delete().eq("id", task_id).execute()


def test_authenticated_client_cannot_write_tasks_directly(authenticated_clients):
    """`tasks` has SELECT-only policy for `authenticated` - all writes must
    go through complete_task (or the backend's service-role key). All three
    denials should be the same Postgres insufficient-privilege code: table
    privilege was fully revoked for `authenticated` (SELECT only), so these
    never reach an RLS policy evaluation at all."""
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients

    with pytest.raises(APIError) as exc_info:
        client_a.table("tasks").insert(_task_payload(user_a_id)).execute()
    assert exc_info.value.code == "42501"

    with pytest.raises(APIError) as exc_info:
        client_a.table("tasks").update({"status": "done"}).eq("user_id", user_a_id).execute()
    assert exc_info.value.code == "42501"

    with pytest.raises(APIError) as exc_info:
        client_a.table("tasks").delete().eq("user_id", user_a_id).execute()
    assert exc_info.value.code == "42501"


def test_authenticated_client_cannot_insert_activity_log_with_task_id(authenticated_clients, service_client: Client):
    """Direct activity_log inserts are only allowed for ad-hoc sessions
    (task_id IS NULL). A task-linked row can only come from complete_task.
    Unlike tasks, authenticated DOES have table-level INSERT on
    activity_log - this is refused by the activity_log_insert policy's
    WITH CHECK, which Postgres also reports as 42501 ("new row violates
    row-level security policy")."""
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id)
    try:
        with pytest.raises(APIError) as exc_info:
            client_a.table("activity_log").insert(
                {
                    "id": str(uuid.uuid4()),
                    "user_id": user_a_id,
                    "completed_on": date.today().isoformat(),
                    "duration_seconds": 1500,
                    "task_id": task_id,
                }
            ).execute()
        assert exc_info.value.code == "42501"
    finally:
        service_client.table("tasks").delete().eq("id", task_id).execute()


def test_complete_task_success(authenticated_clients, service_client: Client):
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id, timer_seconds=1500)
    client_id = str(uuid.uuid4())
    try:
        result = client_a.rpc(
            "complete_task",
            {
                "p_task_id": task_id,
                "p_client_id": client_id,
                "p_duration_seconds": 1500,
                "p_completed_on": date.today().isoformat(),
            },
        ).execute()
        assert result.data["success"] is True
        assert result.data["status"] == "done"

        task_row = service_client.table("tasks").select("status, completed_at").eq("id", task_id).execute().data[0]
        assert task_row["status"] == "done"
        assert task_row["completed_at"] is not None

        activity_row = (
            service_client.table("activity_log").select("*").eq("id", client_id).execute().data[0]
        )
        assert activity_row["task_id"] == task_id
        assert activity_row["user_id"] == user_a_id
    finally:
        service_client.table("activity_log").delete().eq("id", client_id).execute()
        service_client.table("tasks").delete().eq("id", task_id).execute()


def test_complete_task_cross_student_rejected(authenticated_clients, service_client: Client):
    client_a, client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id)
    try:
        with pytest.raises(APIError) as exc_info:
            client_b.rpc(
                "complete_task",
                {
                    "p_task_id": task_id,
                    "p_client_id": str(uuid.uuid4()),
                    "p_duration_seconds": 1500,
                    "p_completed_on": date.today().isoformat(),
                },
            ).execute()
        assert exc_info.value.code == "42501"
    finally:
        service_client.table("tasks").delete().eq("id", task_id).execute()


def test_complete_task_idempotent_retry(authenticated_clients, service_client: Client):
    """Calling complete_task twice with the same p_client_id succeeds
    idempotently instead of failing on the already-done task."""
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id, timer_seconds=1500)
    client_id = str(uuid.uuid4())
    params = {
        "p_task_id": task_id,
        "p_client_id": client_id,
        "p_duration_seconds": 1500,
        "p_completed_on": date.today().isoformat(),
    }
    try:
        first = client_a.rpc("complete_task", params).execute()
        assert first.data["status"] == "done"

        second = client_a.rpc("complete_task", params).execute()
        assert second.data["success"] is True
        assert second.data["status"] == "already_completed"
    finally:
        service_client.table("activity_log").delete().eq("id", client_id).execute()
        service_client.table("tasks").delete().eq("id", task_id).execute()


_NON_PENDING_CODES = {"done": "TK001", "missed": "TK002", "dropped": "TK003"}


@pytest.mark.parametrize("seed_status", ["done", "missed", "dropped"])
def test_complete_task_rejects_non_pending_status(authenticated_clients, service_client: Client, seed_status: str):
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id, status=seed_status)
    try:
        with pytest.raises(APIError) as exc_info:
            client_a.rpc(
                "complete_task",
                {
                    "p_task_id": task_id,
                    "p_client_id": str(uuid.uuid4()),
                    "p_duration_seconds": 1500,
                    "p_completed_on": date.today().isoformat(),
                },
            ).execute()
        assert exc_info.value.code == _NON_PENDING_CODES[seed_status]
    finally:
        service_client.table("tasks").delete().eq("id", task_id).execute()


def test_complete_task_rejects_duration_shorter_than_timer(authenticated_clients, service_client: Client):
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id, timer_seconds=1500)
    try:
        with pytest.raises(APIError) as exc_info:
            client_a.rpc(
                "complete_task",
                {
                    "p_task_id": task_id,
                    "p_client_id": str(uuid.uuid4()),
                    "p_duration_seconds": 100,
                    "p_completed_on": date.today().isoformat(),
                },
            ).execute()
        assert exc_info.value.code == "TK004"
    finally:
        service_client.table("tasks").delete().eq("id", task_id).execute()


def test_complete_task_rejects_null_completed_on(authenticated_clients, service_client: Client):
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id, timer_seconds=1500)
    try:
        with pytest.raises(APIError) as exc_info:
            client_a.rpc(
                "complete_task",
                {
                    "p_task_id": task_id,
                    "p_client_id": str(uuid.uuid4()),
                    "p_duration_seconds": 1500,
                    "p_completed_on": None,
                },
            ).execute()
        assert exc_info.value.code == "22004"
    finally:
        service_client.table("tasks").delete().eq("id", task_id).execute()


def test_activity_log_task_id_unique_per_task(authenticated_clients, service_client: Client):
    """A task cannot end up with two activity_log rows via two different
    client_ids - the partial unique index on task_id enforces this even
    though complete_task's own status check would normally catch it first."""
    client_a, _client_b, user_a_id, _user_b_id = authenticated_clients
    task_id = _seed_task(service_client, user_a_id, timer_seconds=1500)
    first_client_id = str(uuid.uuid4())
    try:
        first = client_a.rpc(
            "complete_task",
            {
                "p_task_id": task_id,
                "p_client_id": first_client_id,
                "p_duration_seconds": 1500,
                "p_completed_on": date.today().isoformat(),
            },
        ).execute()
        assert first.data["status"] == "done"

        # Task is now 'done' - a second, different client_id must be
        # rejected by complete_task's own status check (TK001), which is
        # the path a real client would hit. We don't bypass it here to hit
        # the unique index directly since that would require a service-role
        # insert that violates complete_task's own invariants.
        with pytest.raises(APIError) as exc_info:
            client_a.rpc(
                "complete_task",
                {
                    "p_task_id": task_id,
                    "p_client_id": str(uuid.uuid4()),
                    "p_duration_seconds": 1500,
                    "p_completed_on": date.today().isoformat(),
                },
            ).execute()
        assert exc_info.value.code == "TK001"
    finally:
        service_client.table("activity_log").delete().eq("id", first_client_id).execute()
        service_client.table("tasks").delete().eq("id", task_id).execute()

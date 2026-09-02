import logging
import os
import uuid
from datetime import date

import pytest
from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()
logger = logging.getLogger(__name__)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

STUDENT_A_EMAIL = os.getenv("TEST_STUDENT_A_EMAIL", "student_a@test.com")
STUDENT_A_PASSWORD = os.getenv("TEST_STUDENT_A_PASSWORD", "TestPassword123!")
STUDENT_B_EMAIL = os.getenv("TEST_STUDENT_B_EMAIL", "student_b@test.com")
STUDENT_B_PASSWORD = os.getenv("TEST_STUDENT_B_PASSWORD", "TestPassword123!")

if not SUPABASE_URL or not SUPABASE_KEY:
    pytest.skip("Supabase environment variables not set. Skipping RLS tests.", allow_module_level=True)

USER_TABLES_TO_TEST = [
    "user_topic_weights",
    "nova_capacity_log",
    "standing_flags",
    "situation_flags",
    "nova_config",
    "tasks",
]


@pytest.fixture
def anon_client() -> Client:
    """Returns an unauthenticated Supabase client subject to standard RLS."""
    return create_client(SUPABASE_URL, SUPABASE_KEY)


@pytest.fixture
def authenticated_clients():
    """Signs in Student A and Student B to retrieve authentic user JWT sessions."""
    client_a = create_client(SUPABASE_URL, SUPABASE_KEY)
    client_b = create_client(SUPABASE_URL, SUPABASE_KEY)

    try:
        session_a = client_a.auth.sign_in_with_password({
            "email": STUDENT_A_EMAIL,
            "password": STUDENT_A_PASSWORD,
        })
        session_b = client_b.auth.sign_in_with_password({
            "email": STUDENT_B_EMAIL,
            "password": STUDENT_B_PASSWORD,
        })
        user_a_id = session_a.user.id
        user_b_id = session_b.user.id

        return client_a, client_b, user_a_id, user_b_id
    except Exception as e:
        pytest.skip(f"Test user authentication unavailable: {e}")


def test_unauthenticated_client_cannot_read_user_data(anon_client: Client):
    """Verifies that unauthenticated requests cannot read isolated user data."""
    for table_name in USER_TABLES_TO_TEST:
        try:
            response = anon_client.table(table_name).select("*").execute()
            assert len(response.data) == 0, f"RLS Failure: Unauthenticated user read {len(response.data)} rows from {table_name}"
        except Exception as e:
            err_msg = str(e).lower()
            assert any(term in err_msg for term in ["permission denied", "rls", "401", "403"])


def _seed_test_record(client: Client, table_name: str, user_id: str) -> tuple[str | None, dict]:
    """
    Attempts to seed a record for testing, matching known schema constraints.
    Returns (seeded_record_id, payload_used).
    """
    test_record_id = str(uuid.uuid4())
    today_str = str(date.today())

    if table_name == "user_topic_weights":
        # subject_id's FK target is `subjects` ONLY
        # (user_topic_weights_subject_id_fkey -> subjects.id).
        # Do NOT fall back to `courses` (not a valid FK target for this
        # column) or a random uuid4() (guaranteed FK violation) -- either
        # produces a confusing insert error instead of a clear diagnostic.
        subject_uuid = None
        try:
            sub_res = client.table("subjects").select("id").limit(1).execute()
            if sub_res.data and len(sub_res.data) > 0:
                subject_uuid = sub_res.data[0]["id"]
        except Exception as exc:
            logger.debug("subjects lookup failed: %s", exc)

        if not subject_uuid:
            pytest.fail(
                "Cannot seed user_topic_weights: no rows in 'subjects' "
                "(the FK target for subject_id). This environment needs "
                "seed data in 'subjects' before RLS tests can run -- "
                "falling back to another table or a random UUID would "
                "only produce a foreign-key violation, not a valid test."
            )

        payload = {
            "id": test_record_id,
            "user_id": user_id,
            "subject_id": subject_uuid,
            "topic": "test_topic",
            "weight": 1.0,
        }
        res = client.table(table_name).insert(payload).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id", test_record_id), payload

    elif table_name == "nova_capacity_log":
        payload = {
            "id": test_record_id,
            "user_id": user_id,
            "capacity": "normal",
            "logged_for_date": today_str,
        }
        res = client.table(table_name).insert(payload).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id", test_record_id), payload

    elif table_name == "standing_flags":
        payload = {
            "id": test_record_id,
            "user_id": user_id,
            "instruction_text": "test_flag",
        }
        res = client.table(table_name).insert(payload).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id", test_record_id), payload

    elif table_name == "situation_flags":
        payload = {
            "id": test_record_id,
            "user_id": user_id,
            "flag_text": "test_situation",
        }
        res = client.table(table_name).insert(payload).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id", test_record_id), payload

    elif table_name == "nova_config":
        payload = {
            "id": test_record_id,
            "user_id": user_id,
            "key": f"test_key_{test_record_id[:8]}",
            "value": "test_value",
        }
        res = client.table(table_name).insert(payload).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id", test_record_id), payload

    elif table_name == "tasks":
        # tasks has two NOT NULL FKs (study_plan_id, user_subject_id) plus
        # several other NOT NULL columns with no defaults, and no existing
        # helper in this file builds user_subjects/study_plans rows. Seed
        # the minimal parent chain scoped to this test only -- not a
        # general-purpose factory for those tables.
        subject_uuid = None
        try:
            sub_res = client.table("subjects").select("id").limit(1).execute()
            if sub_res.data and len(sub_res.data) > 0:
                subject_uuid = sub_res.data[0]["id"]
        except Exception as exc:
            logger.debug("subjects lookup failed: %s", exc)

        if not subject_uuid:
            pytest.fail(
                "Cannot seed tasks: no rows in 'subjects' (needed to seed "
                "the parent user_subjects row, the FK target for "
                "tasks.user_subject_id). This environment needs seed data "
                "in 'subjects' before RLS tests can run."
            )

        user_subject_id = str(uuid.uuid4())
        us_payload = {
            "id": user_subject_id,
            "user_id": user_id,
            "subject_id": subject_uuid,
            "semester": "1",
        }
        us_res = client.table("user_subjects").insert(us_payload).execute()
        if not (us_res.data and len(us_res.data) > 0):
            pytest.fail(f"Cannot seed tasks: failed to seed parent user_subjects row: {us_res}")

        study_plan_id = str(uuid.uuid4())
        sp_payload = {
            "id": study_plan_id,
            "user_subject_id": user_subject_id,
            "user_id": user_id,
            "subject_name": "RLS Test Subject",
            "handout_url": "https://example.com/rls-test-handout.pdf",
            "topics": [],
            "weekly_plan": {},
            "is_active": False,
        }
        sp_res = client.table("study_plans").insert(sp_payload).execute()
        if not (sp_res.data and len(sp_res.data) > 0):
            pytest.fail(f"Cannot seed tasks: failed to seed parent study_plans row: {sp_res}")

        # study_plan_id is freshly generated every run, so
        # tasks_unique_source (study_plan_id, source_week_start,
        # source_task_key) can't collide across repeated runs even with a
        # fixed key -- derived from the record id anyway so it's
        # unambiguous when inspecting the DB. study_plan_id/user_subject_id
        # ride along in the returned payload so
        # test_cross_student_data_isolation can tear both parent rows down
        # after it deletes the task row (tasks_user_subject_id_fkey is
        # ON DELETE RESTRICT, so user_subjects can't go first).
        payload = {
            "id": test_record_id,
            "user_id": user_id,
            "study_plan_id": study_plan_id,
            "user_subject_id": user_subject_id,
            "subject_name": "RLS Test Subject",
            "title": "RLS test task",
            "planned_duration_seconds": 1500,
            "source_week_start": today_str,
            "source_task_key": f"test_task_{test_record_id[:8]}",
        }
        res = client.table(table_name).insert(payload).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id", test_record_id), payload

    else:
        payload = {"id": test_record_id, "user_id": user_id}
        res = client.table(table_name).insert(payload).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id", test_record_id), payload

    return None, {}


@pytest.mark.parametrize("table_name", USER_TABLES_TO_TEST)
def test_cross_student_data_isolation(authenticated_clients, table_name: str):
    """
    1. Authenticates as Student A and Student B.
    2. Attempts to insert or query a record owned by Student A.
    3. Asserts that Student B cannot query or access any of Student A's records in table_name.
    """
    client_a, client_b, user_a_id, _ = authenticated_clients

    # Step 1: Seed row as Student A
    seeded_row_id = None
    seed_payload: dict = {}
    try:
        seeded_row_id, seed_payload = _seed_test_record(client_a, table_name, user_a_id)
    except Exception as e:
        logger.warning("Could not seed row for %s: %s", table_name, e)

    assert seeded_row_id is not None, (
        f"Setup failed: could not seed a row as Student A in {table_name}, "
        f"cannot verify isolation"
    )

    # Step 2: Attempt to read records as Student B filtered by Student A's record ID or user_id
    if seeded_row_id:
        read_response = client_b.table(table_name).select("*").eq("id", seeded_row_id).execute()
    else:
        read_response = client_b.table(table_name).select("*").eq("user_id", user_a_id).execute()

    # Step 3: Assert Student B gets 0 rows back
    assert len(read_response.data) == 0, f"RLS Failure: Student B read Student A's data in {table_name}"

    # Step 4: Cleanup seeded row
    if seeded_row_id:
        try:
            client_a.table(table_name).delete().eq("id", seeded_row_id).execute()
        except Exception as e:
            logger.warning("Cleanup failed for seeded row %s in %s: %s", seeded_row_id, table_name, e)

    # Step 5: Cleanup parent rows seeded for "tasks" -- study_plans first,
    # then user_subjects, since tasks_user_subject_id_fkey is ON DELETE
    # RESTRICT and would reject the user_subjects delete while either the
    # task (already gone, per Step 4) or the study_plan still references it.
    if table_name == "tasks" and seed_payload:
        study_plan_id = seed_payload.get("study_plan_id")
        user_subject_id = seed_payload.get("user_subject_id")
        if study_plan_id:
            try:
                client_a.table("study_plans").delete().eq("id", study_plan_id).execute()
            except Exception as e:
                logger.warning("Cleanup failed for seeded study_plans row %s: %s", study_plan_id, e)
        if user_subject_id:
            try:
                client_a.table("user_subjects").delete().eq("id", user_subject_id).execute()
            except Exception as e:
                logger.warning("Cleanup failed for seeded user_subjects row %s: %s", user_subject_id, e)

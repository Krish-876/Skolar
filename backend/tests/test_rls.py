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
        subject_uuid = None
        for lookup_table in ["subjects", "courses"]:
            try:
                sub_res = client.table(lookup_table).select("id").limit(1).execute()
                if sub_res.data and len(sub_res.data) > 0:
                    subject_uuid = sub_res.data[0]["id"]
                    break
            except Exception as exc:
                logger.debug("Lookup table %s check failed: %s", lookup_table, exc)

        if not subject_uuid:
            subject_uuid = str(uuid.uuid4())

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
    try:
        seeded_row_id, _ = _seed_test_record(client_a, table_name, user_a_id)
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

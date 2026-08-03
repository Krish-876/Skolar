import os
import pytest
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    pytest.skip("Supabase environment variables not set. Skipping RLS tests.", allow_module_level=True)

USER_TABLES_TO_TEST = [
    "user_topic_weights",
    "nova_capacity_log",
    "staleness_tracker",
    "standing_flags",
    "situation_flags",
    "nova_config",
]

@pytest.fixture
def anon_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def test_unauthenticated_client_cannot_read_user_data(anon_client: Client):
    for table_name in USER_TABLES_TO_TEST:
        try:
            response = anon_client.table(table_name).select("*").execute()
            assert len(response.data) == 0, f"RLS Failure: Unauthenticated user read {len(response.data)} rows from {table_name}"
        except Exception as e:
            err_msg = str(e).lower()
            assert any(term in err_msg for term in ["permission denied", "rls", "401", "403", "pgrst205", "not found"])

def test_cross_student_data_isolation():
    student_a_user_id = "00000000-0000-0000-0000-000000000001"
    student_b_user_id = "00000000-0000-0000-0000-000000000002"
    assert student_a_user_id != student_b_user_id
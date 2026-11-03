"""
Provisions student_a and student_b into Supabase Auth and public.users
for live RLS integration test runs.
"""

import os
import sys
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
STUDENT_A_PASS = os.getenv("TEST_STUDENT_A_PASSWORD", "TestPass123!_A")
STUDENT_B_PASS = os.getenv("TEST_STUDENT_B_PASSWORD", "TestPass123!_B")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in environment.")
    sys.exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

USERS = [
    {"email": "student_a@test.com", "password": STUDENT_A_PASS, "college": "BITS Pilani"},
    {"email": "student_b@test.com", "password": STUDENT_B_PASS, "college": "IIT Madras"},
]


def _provision_auth_user(email: str, password: str) -> str:
    try:
        response = supabase.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,
        })
        if not response.user:
            raise RuntimeError(f"Supabase returned no user while creating {email}")
        print(f"[CREATED] Test user created: {email} ({response.user.id})")
        return response.user.id
    except Exception as create_error:
        try:
            users_response = supabase.auth.admin.list_users()
            existing_user = next(
                (user for user in users_response if user.email == email),
                None,
            )
        except Exception as lookup_error:
            raise RuntimeError(
                f"Could not create or find test user {email}: {lookup_error}"
            ) from create_error

        if existing_user is None:
            raise RuntimeError(f"Could not create test user {email}: {create_error}") from create_error

        supabase.auth.admin.update_user_by_id(
            existing_user.id,
            {"password": password, "email_confirm": True},
        )
        print(f"[OK] Existing test user reset and verified: {email} ({existing_user.id})")
        return existing_user.id


def seed_test_accounts():
    print("Provisioning test accounts in Supabase...")
    for user_data in USERS:
        email = user_data["email"]
        password = user_data["password"]
        college = user_data["college"]

        user_id = _provision_auth_user(email, password)

        try:
            supabase.table("users").upsert({
                "id": user_id,
                "email": email,
                "college": college,
            }).execute()
            print(f"[OK] public.users profile synced for {email}")
        except Exception as e:
            raise RuntimeError(f"Profile sync failed for {email}: {e}") from e

    print("Test account provisioning completed.")


if __name__ == "__main__":
    seed_test_accounts()

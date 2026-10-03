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
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
STUDENT_A_PASS = os.getenv("TEST_STUDENT_A_PASSWORD", "TestPass123!_A")
STUDENT_B_PASS = os.getenv("TEST_STUDENT_B_PASSWORD", "TestPass123!_B")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Error: SUPABASE_URL and SUPABASE_KEY must be set in environment.")
    sys.exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

USERS = [
    {"email": "student_a@test.com", "password": STUDENT_A_PASS, "college": "BITS Pilani"},
    {"email": "student_b@test.com", "password": STUDENT_B_PASS, "college": "IIT Madras"},
]


def seed_test_accounts():
    print("Provisioning test accounts in Supabase...")
    for user_data in USERS:
        email = user_data["email"]
        password = user_data["password"]
        college = user_data["college"]

        try:
            res = supabase.auth.sign_in_with_password({"email": email, "password": password})
            user_id = res.user.id
            print(f"[OK] Existing test user verified: {email} ({user_id})")
        except Exception:
            try:
                res = supabase.auth.sign_up({"email": email, "password": password})
                if res.user:
                    user_id = res.user.id
                    print(f"[CREATED] New test user created: {email} ({user_id})")
                else:
                    print(f"[WARN] Sign-up returned no user object for {email}")
                    continue
            except Exception as e:
                print(f"[ERROR] Could not provision {email}: {e}")
                continue

        try:
            supabase.table("users").upsert({
                "id": user_id,
                "email": email,
                "college": college,
            }).execute()
            print(f"[OK] public.users profile synced for {email}")
        except Exception as e:
            print(f"[WARN] Profile sync for {email}: {e}")

    print("Test account provisioning completed.")


if __name__ == "__main__":
    seed_test_accounts()

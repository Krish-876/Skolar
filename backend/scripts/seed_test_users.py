"""Provision the confirmed Supabase users required by live integration tests."""

import os
import sys

from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SERVICE_ROLE_KEY:
    print("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.", file=sys.stderr)
    raise SystemExit(1)

supabase = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)

USERS = (
    ("student_a@test.com", os.getenv("TEST_STUDENT_A_PASSWORD", "TestPassword123!"), "BITS Pilani"),
    ("student_b@test.com", os.getenv("TEST_STUDENT_B_PASSWORD", "TestPassword123!"), "IIT Madras"),
)


def _find_user(email: str):
    users = supabase.auth.admin.list_users()
    return next((user for user in users if user.email == email), None)


def _ensure_user(email: str, password: str) -> str:
    existing = _find_user(email)
    if existing is None:
        response = supabase.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,
        })
        if response.user is None:
            raise RuntimeError(f"Supabase returned no user for {email}")
        return response.user.id

    supabase.auth.admin.update_user_by_id(
        existing.id,
        {"password": password, "email_confirm": True},
    )
    return existing.id


def main() -> None:
    for email, password, college in USERS:
        user_id = _ensure_user(email, password)
        supabase.table("users").upsert({
            "id": user_id,
            "email": email,
            "college": college,
        }).execute()
        print(f"Provisioned {email} ({user_id})")


if __name__ == "__main__":
    main()

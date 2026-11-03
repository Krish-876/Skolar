from types import SimpleNamespace
import sys
from pathlib import Path

import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

sys.path.insert(0, str(Path(__file__).parents[1]))

from nova.api.deps import get_authorized_user_id, get_current_user_id


def test_current_user_id_comes_from_verified_supabase_session():
    jwt_value = "session-jwt"

    class FakeAuth:
        def get_user(self, token: str):
            assert token == jwt_value
            return SimpleNamespace(user=SimpleNamespace(id="student-a"))

    clients = (SimpleNamespace(auth=FakeAuth()), None, None)
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=jwt_value)

    assert get_current_user_id(credentials, clients) == "student-a"


def test_current_user_id_rejects_invalid_session():
    class FakeAuth:
        def get_user(self, token: str):
            raise RuntimeError("expired")

    clients = (SimpleNamespace(auth=FakeAuth()), None, None)
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="expired-token")

    with pytest.raises(HTTPException) as error:
        get_current_user_id(credentials, clients)

    assert error.value.status_code == 401


def test_path_user_id_must_match_authenticated_user():
    with pytest.raises(HTTPException) as error:
        get_authorized_user_id("student-b", "student-a")

    assert error.value.status_code == 403

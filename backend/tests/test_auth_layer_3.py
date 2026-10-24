import time

import jwt
import pytest
from fastapi.testclient import TestClient

from app import main as main_module
from app.rate_limiting import SlidingWindowRateLimiter


SECRET_KEY = "skolar-super-secure-test-secret-key-32chars"


class FakeClock:
    def __init__(self):
        self.value = 0.0

    def __call__(self):
        return self.value

    def advance(self, seconds):
        self.value += seconds


def create_token(user_id):
    return jwt.encode(
        {
            "aud": "authenticated",
            "exp": int(time.time()) + 3600,
            "role": "authenticated",
            "sub": user_id,
            "app_metadata": {"roles": ["student"]},
        },
        SECRET_KEY,
        algorithm="HS256",
    )


@pytest.fixture
def limited_app(monkeypatch):
    clock = FakeClock()
    limiter = SlidingWindowRateLimiter(
        {"general": (2, 60.0), "nova": (2, 60.0)},
        clock=clock,
    )
    monkeypatch.setattr(main_module, "rate_limiter", limiter)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", SECRET_KEY)
    return TestClient(main_module.app), clock


def test_authenticated_requests_are_limited_per_verified_user(limited_app):
    client, _ = limited_app
    headers = {"Authorization": f"Bearer {create_token('user-a')}"}

    assert client.get("/me", headers=headers).status_code == 200
    assert client.get("/me", headers=headers).status_code == 200

    response = client.get("/me", headers=headers)

    assert response.status_code == 429
    assert response.json() == {"detail": "Too many requests. Please try again later."}
    assert response.headers["Retry-After"] == "60"


def test_authenticated_users_have_separate_counters(limited_app):
    client, _ = limited_app
    user_a = {"Authorization": f"Bearer {create_token('user-a')}"}
    user_b = {"Authorization": f"Bearer {create_token('user-b')}"}

    assert client.get("/me", headers=user_a).status_code == 200
    assert client.get("/me", headers=user_a).status_code == 200
    assert client.get("/me", headers=user_a).status_code == 429
    assert client.get("/me", headers=user_b).status_code == 200


def test_rate_limit_window_expires_without_real_sleep(limited_app):
    client, clock = limited_app
    headers = {"Authorization": f"Bearer {create_token('user-a')}"}

    assert client.get("/me", headers=headers).status_code == 200
    assert client.get("/me", headers=headers).status_code == 200
    assert client.get("/me", headers=headers).status_code == 429

    clock.advance(60)
    assert client.get("/me", headers=headers).status_code == 200


def test_invalid_requests_are_limited_by_socket_ip_not_forwarded_header(limited_app):
    client, _ = limited_app
    headers = {
        "Authorization": "Bearer invalid-token",
        "X-Forwarded-For": "203.0.113.20",
    }

    assert client.get("/me", headers=headers).status_code == 401
    assert client.get("/me", headers=headers).status_code == 401
    assert client.get("/me", headers=headers).status_code == 429


def test_cors_preflight_is_not_rate_limited(limited_app):
    client, _ = limited_app

    for _ in range(3):
        response = client.options(
            "/me",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )
        assert response.status_code != 429


def test_nova_requests_use_the_nova_category(limited_app):
    client, _ = limited_app
    headers = {"Authorization": f"Bearer {create_token('user-a')}"}

    assert client.post("/nova/trigger/check", headers=headers).status_code != 429
    assert client.post("/nova/trigger/check", headers=headers).status_code != 429
    assert client.post("/nova/trigger/check", headers=headers).status_code == 429

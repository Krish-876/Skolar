import pytest
import jwt
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

SECRET_KEY = "skolar-super-secure-test-secret-key-32chars"


def create_mock_jwt(user_id="student-test-uuid-123", roles=None, include_sub=True):
    if roles is None:
        roles = ["student"]
    payload = {
        "role": "authenticated",
        "app_metadata": {"roles": roles}
    }
    if include_sub:
        payload["sub"] = user_id
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


# ============================================================================
# LAYER 1: Edge Transport Security (TLS / HTTPS Enforcement) Tests
# ============================================================================

def test_layer1_https_allowed():
    """Verify that requests with x-forwarded-proto: https pass Layer 1."""
    res = client.get("/health", headers={"x-forwarded-proto": "https"})
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_layer1_local_dev_allowed_without_https():
    """Verify that local development clients (testclient / localhost / 127.0.0.1) pass Layer 1."""
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_layer1_insecure_http_rejected_for_external_clients():
    """Verify 403 Forbidden when x-forwarded-proto is 'http' from a non-local client."""
    external_client = TestClient(app, client=("198.51.100.50", 45678))
    res = external_client.get(
        "/me",
        headers={"x-forwarded-proto": "http"}
    )
    assert res.status_code == 403
    assert res.json() == {"detail": "Insecure transport protocol. HTTPS is strictly required."}


def test_layer1_utility_bypass_health_and_docs():
    """Verify open utility endpoints bypass transport checks even for non-local clients."""
    external_client = TestClient(app, client=("198.51.100.50", 45678))

    res_health = external_client.get("/health", headers={"x-forwarded-proto": "http"})
    assert res_health.status_code == 200

    res_docs = external_client.get("/docs", headers={"x-forwarded-proto": "http"})
    assert res_docs.status_code == 200

    res_openapi = external_client.get("/openapi.json", headers={"x-forwarded-proto": "http"})
    assert res_openapi.status_code == 200


# ============================================================================
# LAYER 2: Identity & Session Authentication (Supabase JWT) Tests
# ============================================================================

def test_layer2_missing_authorization_header():
    """Verify 401 Unauthorized when Authorization header is absent."""
    res = client.get("/me")
    assert res.status_code == 401
    assert res.json()["detail"] == "Missing or malformed Authorization header."


def test_layer2_malformed_authorization_header():
    """Verify 401 Unauthorized when Authorization header is not a Bearer token."""
    res = client.get("/me", headers={"Authorization": "Token 123456"})
    assert res.status_code == 401
    assert res.json()["detail"] == "Missing or malformed Authorization header."


def test_layer2_invalid_jwt_format():
    """Verify 401 Unauthorized when token string is corrupted or not a valid JWT."""
    res = client.get("/me", headers={"Authorization": "Bearer not-a-valid-jwt"})
    assert res.status_code == 401
    assert "Authentication token invalid" in res.json()["detail"]


def test_layer2_token_missing_sub_claim():
    """Verify 401 Unauthorized when token payload is missing the 'sub' claim."""
    token = create_mock_jwt(include_sub=False)
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == "Invalid token payload: User ID (sub) not found."


def test_layer2_valid_jwt_injects_identity_context():
    """Verify that a valid token decodes successfully and injects user context into request.state."""
    user_id = "student-auth-id-999"
    token = create_mock_jwt(user_id=user_id, roles=["student"])

    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    
    data = res.json()
    assert data["user_id"] == user_id
    assert data["user_role"] == "authenticated"
    assert data["custom_roles"] == ["student"]


def test_layer2_custom_roles_in_app_metadata():
    """Verify custom roles (e.g. admin) are extracted properly from app_metadata."""
    admin_id = "admin-uuid-456"
    token = create_mock_jwt(user_id=admin_id, roles=["admin", "student"])

    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200

    data = res.json()
    assert data["user_id"] == admin_id
    assert data["custom_roles"] == ["admin", "student"]

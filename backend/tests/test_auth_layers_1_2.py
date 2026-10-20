import os
import time
import jwt
from fastapi.testclient import TestClient

SECRET_KEY = "skolar-super-secure-test-secret-key-32chars"  # noqa: S105
os.environ["SUPABASE_JWT_SECRET"] = SECRET_KEY

from app.main import app  # noqa: E402

client = TestClient(app)


def create_mock_jwt(
    user_id="student-test-uuid-123",
    roles=None,
    include_sub=True,
    include_exp=True,
    include_aud=True,
    secret=SECRET_KEY,
    algorithm="HS256",
    expires_in=3600,
    audience="authenticated",
    custom_app_metadata=None,
):
    now = int(time.time())
    payload = {
        "role": "authenticated",
    }
    if include_aud:
        payload["aud"] = audience
    if include_exp:
        payload["exp"] = now + expires_in
    if include_sub:
        payload["sub"] = user_id

    if custom_app_metadata is not None:
        payload["app_metadata"] = custom_app_metadata
    elif roles is not None:
        payload["app_metadata"] = {"roles": roles}
    else:
        payload["app_metadata"] = {"roles": ["student"]}

    return jwt.encode(payload, secret, algorithm=algorithm)


# ============================================================================
# LAYER 1: Edge Transport Security (TLS / HTTPS Enforcement) Tests
# ============================================================================

def test_layer1_https_allowed():
    """Verify that requests with x-forwarded-proto: https pass Layer 1 to protected route."""
    valid_token = create_mock_jwt()
    # Call a protected route (/me) with x-forwarded-proto: https
    res = client.get(
        "/me",
        headers={
            "x-forwarded-proto": "https",
            "Authorization": f"Bearer {valid_token}"
        }
    )
    assert res.status_code == 200
    assert res.json()["user_id"] == "student-test-uuid-123"


def test_layer1_local_dev_allowed_without_https():
    """Verify that local development clients (testclient / localhost / 127.0.0.1) pass Layer 1."""
    valid_token = create_mock_jwt()
    res = client.get("/me", headers={"Authorization": f"Bearer {valid_token}"})
    assert res.status_code == 200
    assert res.json()["user_id"] == "student-test-uuid-123"


def test_layer1_insecure_http_rejected_for_external_clients():
    """Verify 403 Forbidden when x-forwarded-proto is 'http' from a non-local client."""
    external_client = TestClient(app, client=("198.51.100.50", 45678))
    res = external_client.get(
        "/me",
        headers={"x-forwarded-proto": "http"}
    )
    assert res.status_code == 403
    assert res.json() == {"detail": "Insecure transport protocol. HTTPS is strictly required."}


def test_layer1_missing_proxy_proto_header_rejected_for_external_clients():
    """Verify fallback to request.url.scheme blocks non-local HTTP when proxy header is missing."""
    external_client = TestClient(app, client=("198.51.100.50", 45678))
    res = external_client.get(
        "/me",
        headers={"Authorization": "******"}
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


def test_cors_preflight_options_bypasses_auth():
    """Verify that browser CORS preflight OPTIONS requests bypass authentication without 401."""
    res = client.options(
        "/me",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        }
    )
    # Must not be rejected with 401 Unauthorized
    assert res.status_code != 401


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
    assert res.json()["detail"] == "Invalid or expired authentication token."


def test_layer2_token_missing_sub_claim():
    """Verify 401 Unauthorized when token payload is missing the 'sub' claim."""
    token = create_mock_jwt(include_sub=False)
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == "Invalid or expired authentication token."


def test_layer2_token_signed_with_different_key():
    """Verify 401 Unauthorized when token is forged or signed with a different key."""
    forged_token = create_mock_jwt(secret="forged-unauthorized-key-with-32c!")  # noqa: S106
    res = client.get("/me", headers={"Authorization": f"Bearer {forged_token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == "Invalid or expired authentication token."


def test_layer2_expired_token():
    """Verify 401 Unauthorized when token has expired in the past."""
    expired_token = create_mock_jwt(expires_in=-300)
    res = client.get("/me", headers={"Authorization": f"Bearer {expired_token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == "Invalid or expired authentication token."


def test_layer2_wrong_audience():
    """Verify 401 Unauthorized when token audience is not 'authenticated'."""
    wrong_aud_token = create_mock_jwt(audience="wrong-aud-service")
    res = client.get("/me", headers={"Authorization": f"Bearer {wrong_aud_token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == "Invalid or expired authentication token."


def test_layer2_alg_none_rejected():
    """Verify 401 Unauthorized when token uses insecure algorithm 'none'."""
    now = int(time.time())
    payload = {
        "sub": "student-uuid-none",
        "aud": "authenticated",
        "exp": now + 3600,
        "role": "authenticated",
        "app_metadata": {"roles": ["student"]}
    }
    # Create unsigned token with alg=none
    none_token = jwt.encode(payload, key="", algorithm="none")
    res = client.get("/me", headers={"Authorization": f"Bearer {none_token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == "Invalid or expired authentication token."


def test_layer2_valid_jwt_injects_identity_context():
    """Verify that a cryptographically valid token decodes and injects user context into request.state."""
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


def test_layer2_non_dict_app_metadata_handled_gracefully():
    """Verify that non-dictionary app_metadata (e.g., string, int, null) does not raise AttributeError."""
    token = create_mock_jwt(custom_app_metadata="invalid-string-metadata")
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    assert data["custom_roles"] == ["student"]

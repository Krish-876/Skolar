import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.dependencies import get_current_user_id

client = TestClient(app)


# ============================================================================
# LAYER 1: Edge Transport Security (TLS / HTTPS Enforcement) Tests
# ============================================================================

def test_layer1_https_allowed():
    """Verify that requests with x-forwarded-proto: https pass Layer 1."""
    # When dependency is mocked so we can verify Layer 1 doesn't block the request
    app.dependency_overrides[get_current_user_id] = lambda: "test-user-123"
    try:
        res = client.get("/health", headers={"x-forwarded-proto": "https"})
        assert res.status_code == 200
        assert res.json() == {"status": "ok"}
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)


def test_layer1_local_dev_allowed_without_https():
    """Verify that local development clients (testclient / localhost / 127.0.0.1) pass Layer 1."""
    # TestClient default client host is 'testclient'
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_layer1_insecure_http_rejected_for_external_clients():
    """Verify 403 Forbidden when x-forwarded-proto is 'http' from a non-local client."""
    # Create a TestClient simulating a non-local external IP address
    external_client = TestClient(app, client=("198.51.100.50", 45678))

    res = external_client.post(
        "/nova/trigger/check",
        headers={"x-forwarded-proto": "http"}
    )
    assert res.status_code == 403
    assert res.json() == {"detail": "Insecure transport protocol. HTTPS is strictly required."}


def test_layer1_external_https_allowed():
    """Verify that external client with x-forwarded-proto: https passes Layer 1."""
    external_client = TestClient(app, client=("198.51.100.50", 45678))
    app.dependency_overrides[get_current_user_id] = lambda: "test-user-123"
    try:
        # Request with valid https proto
        res = external_client.get(
            "/health",
            headers={"x-forwarded-proto": "https"}
        )
        assert res.status_code == 200
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)


def test_layer1_utility_bypass_health_endpoint():
    """Verify /health bypasses transport checks even for non-local clients."""
    external_client = TestClient(app, client=("198.51.100.50", 45678))
    res = external_client.get("/health", headers={"x-forwarded-proto": "http"})
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_layer1_utility_bypass_docs_and_openapi():
    """Verify /docs and /openapi.json bypass transport checks even for non-local clients."""
    external_client = TestClient(app, client=("198.51.100.50", 45678))
    
    res_docs = external_client.get("/docs", headers={"x-forwarded-proto": "http"})
    assert res_docs.status_code == 200

    res_openapi = external_client.get("/openapi.json", headers={"x-forwarded-proto": "http"})
    assert res_openapi.status_code == 200

"""
SCENARIO: Auth & Security Flow
================================
Tests JWT lifecycle, token validity, and access control.

Flow:
  1.  Login → get token → access protected resource
  2.  Tampered JWT → expect 401
  3.  Expired/garbage JWT → expect 401
  4.  Missing Authorization header → expect 401
  5.  Wrong password → expect 401
  6.  Duplicate registration → expect 409 or 400
  7.  Re-login after data was created → token still works on all routes
"""
import time
import pytest
import requests


PROTECTED_ROUTES = [
    ("GET",  "/users/me"),
    ("GET",  "/workouts"),
    ("GET",  "/food"),
    ("GET",  "/body-metrics"),
    ("GET",  "/steps"),
    ("GET",  "/medical/reports"),
    ("GET",  "/health-summary/me"),
    ("GET",  "/goals"),
    ("GET",  "/nutrient/weekly-trends"),
    ("GET",  "/users/me/export"),
]


@pytest.mark.integration
def test_valid_token_grants_access(api_url, integration_user):
    """A valid JWT token must grant access to all protected routes."""
    headers = integration_user["headers"]
    failures = []

    for method, path in PROTECTED_ROUTES:
        r = requests.request(method, f"{api_url}{path}", headers=headers, timeout=10)
        if r.status_code == 401:
            failures.append(f"{method} {path} → 401 (token rejected)")

    assert not failures, "Valid token rejected by routes:\n" + "\n".join(failures)


@pytest.mark.integration
def test_tampered_jwt_returns_401(api_url, integration_user):
    """A JWT with tampered signature must be rejected as 401."""
    original = integration_user["token"]
    # Flip the last character of the token — breaks signature
    tampered = original[:-1] + ("A" if original[-1] != "A" else "B")
    headers = {"Authorization": f"Bearer {tampered}"}

    r = requests.get(f"{api_url}/users/me", headers=headers, timeout=10)
    assert r.status_code == 401, f"Tampered JWT should return 401, got {r.status_code}"


@pytest.mark.integration
def test_garbage_jwt_returns_401(api_url):
    """A completely invalid token must be rejected as 401."""
    headers = {"Authorization": "Bearer this.is.garbage"}
    r = requests.get(f"{api_url}/users/me", headers=headers, timeout=10)
    assert r.status_code == 401, f"Garbage JWT should return 401, got {r.status_code}"


@pytest.mark.integration
def test_no_auth_header_returns_401(api_url):
    """Missing Authorization header must return 401."""
    for method, path in PROTECTED_ROUTES[:3]:  # test a sample
        r = requests.request(method, f"{api_url}{path}", timeout=10)
        assert r.status_code == 401, (
            f"{method} {path} without auth should return 401, got {r.status_code}"
        )


@pytest.mark.integration
def test_wrong_password_returns_401(api_url, integration_user):
    """Login with wrong password must return 401."""
    r = requests.post(f"{api_url}/auth/login", json={
        "email": integration_user["email"],
        "password": "WrongPassword999!",
    }, timeout=10)
    assert r.status_code == 401, f"Wrong password should return 401, got {r.status_code}"


@pytest.mark.integration
def test_duplicate_registration_returns_4xx(api_url, integration_user):
    """Re-registering an existing email must return 400 or 409."""
    r = requests.post(f"{api_url}/auth/register", json={
        "email": integration_user["email"],
        "password": "AnotherPass123!",
        "age": 30,
        "gender": "Female",
        "height": 160.0,
        "goal": "Fitness",
        "dietType": "Any",
        "medicalFlags": "",
    }, timeout=10)
    assert r.status_code in (400, 409), (
        f"Duplicate email should return 4xx, got {r.status_code}: {r.text}"
    )


@pytest.mark.integration
def test_malformed_registration_returns_400(api_url):
    """Register with invalid email format must return 400."""
    cases = [
        {"email": "not-an-email", "password": "ValidPass123!", "age": 25, "gender": "Male", "height": 175.0, "goal": "Fitness", "dietType": "Any"},
        {"email": f"valid_{int(time.time())}@test.com", "password": "abc", "age": 25, "gender": "Male", "height": 175.0, "goal": "Fitness", "dietType": "Any"},
    ]
    for payload in cases:
        r = requests.post(f"{api_url}/auth/register", json=payload, timeout=10)
        assert r.status_code == 400, (
            f"Invalid payload should return 400, got {r.status_code} for {payload}"
        )

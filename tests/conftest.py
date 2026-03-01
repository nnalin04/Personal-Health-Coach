"""
Session-scoped fixtures for the Personal Health Coach E2E API test suite.

Design:
- A single test user is registered ONCE per session (not per test).
  This avoids 60+ extra DB writes and mirrors real-world token reuse.
- BASE_URL is overridable via API_BASE_URL env var for CI flexibility.
- `today` is frozen at session start so all date assertions are consistent.

Usage in tests:
    def test_something(base_url, auth_headers, today):
        r = requests.get(f"{base_url}/resource", headers=auth_headers)
"""
import os
import time
import pytest
import requests
from datetime import date

# ─── Configuration ─────────────────────────────────────────────────────────────

BASE_URL = os.getenv("API_BASE_URL",   "http://localhost:8080/api")
AI_URL   = os.getenv("AI_SERVICE_URL", "http://localhost:8000")

# ─── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def base_url() -> str:
    return BASE_URL


@pytest.fixture(scope="session")
def ai_url() -> str:
    return AI_URL


@pytest.fixture(scope="session")
def today() -> str:
    """ISO date string frozen at session start. Use in all date payloads."""
    return date.today().isoformat()


@pytest.fixture(scope="session")
def auth(base_url: str) -> dict:
    """
    Register a unique test user once per session. Returns:
      {token, headers, user_id, email}

    Timestamp suffix in email guarantees uniqueness on re-runs
    without needing to wipe the Postgres volume between runs.
    """
    email = f"e2e_{int(time.time())}@healthcoach.test"
    r = requests.post(
        f"{base_url}/auth/register",
        json={
            "email": email,
            "password": "TestPass123!",
            "age": 28,
            "gender": "Male",
            "height": 178.0,
            "goal": "Build Muscle",
            "dietType": "Omnivore",
            "medicalFlags": "",
        },
        timeout=15,
    )
    assert r.status_code in (200, 201), (
        f"Session auth setup FAILED — cannot register test user.\n"
        f"Status: {r.status_code}\nBody: {r.text}\n"
        f"Is Docker running? Try: docker compose --env-file env.dev up -d --wait"
    )
    data = r.json()
    token = data["accessToken"]
    return {
        "token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": data["user"]["id"],
        "email": email,
    }


@pytest.fixture(scope="session")
def auth_headers(auth: dict) -> dict:
    """Shortcut: just the Authorization header dict."""
    return auth["headers"]

"""
Integration test suite — Personal Health Coach
================================================
Tests real service behaviour end-to-end:
  • full cross-service data flows (food log → nutrient analysis → DB)
  • complete user journeys (register → log → AI insights → export)
  • AI service responses validated against real schemas (no mocking)

Configuration (env vars):
  INTEGRATION_TARGET   local | prod | both   (default: local)
  LOCAL_API_URL        default: http://localhost:8080/api
  LOCAL_AI_URL         default: http://localhost:8000
  PROD_API_URL         default: https://healthcoach.duckdns.org/api
"""
import os
import time
import pytest
import requests
from datetime import date

# ─── URL config ────────────────────────────────────────────────────────────────

LOCAL_API = os.getenv("LOCAL_API_URL", "http://localhost:8080/api")
LOCAL_AI  = os.getenv("LOCAL_AI_URL",  "http://localhost:8000")
PROD_API  = os.getenv("PROD_API_URL",  "https://healthcoach.duckdns.org/api")
TARGET    = os.getenv("INTEGRATION_TARGET", "local").lower()   # local | prod | both


def _targets():
    if TARGET == "both":
        return [("local", LOCAL_API, LOCAL_AI), ("prod", PROD_API, None)]
    if TARGET == "prod":
        return [("prod", PROD_API, None)]
    return [("local", LOCAL_API, LOCAL_AI)]


# ─── Session fixtures ──────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def target():
    """Primary target: (label, api_url, ai_url)."""
    targets = _targets()
    return targets[0]


@pytest.fixture(scope="session")
def api_url(target):
    return target[1]


@pytest.fixture(scope="session")
def ai_url(target):
    return target[2]


@pytest.fixture(scope="session")
def today() -> str:
    return date.today().isoformat()


@pytest.fixture(scope="session")
def integration_user(api_url):
    """
    Register a dedicated integration-test user once per session.
    Uses a unique email so re-runs never collide.
    """
    email = f"integration_{int(time.time())}@healthcoach.test"
    r = requests.post(f"{api_url}/auth/register", json={
        "email": email,
        "password": "IntegPass123!",
        "age": 29,
        "gender": "Male",
        "height": 180.0,
        "goal": "Build Muscle",
        "dietType": "Omnivore",
        "medicalFlags": "",
    }, timeout=15)
    assert r.status_code in (200, 201), (
        f"Integration test user registration FAILED\n"
        f"Status: {r.status_code}\nBody: {r.text}\n"
        f"Is the backend running? Check INTEGRATION_TARGET env var."
    )
    data = r.json()
    return {
        "email": email,
        "token": data["accessToken"],
        "headers": {"Authorization": f"Bearer {data['accessToken']}"},
        "user_id": data["user"]["id"],
    }


@pytest.fixture(scope="session")
def second_user(api_url):
    """Second user for cross-user isolation tests."""
    email = f"isolation_{int(time.time())}@healthcoach.test"
    r = requests.post(f"{api_url}/auth/register", json={
        "email": email,
        "password": "IsolPass123!",
        "age": 35,
        "gender": "Female",
        "height": 165.0,
        "goal": "Lose Weight",
        "dietType": "Vegetarian",
        "medicalFlags": "",
    }, timeout=15)
    assert r.status_code in (200, 201)
    data = r.json()
    return {
        "email": email,
        "token": data["accessToken"],
        "headers": {"Authorization": f"Bearer {data['accessToken']}"},
        "user_id": data["user"]["id"],
    }

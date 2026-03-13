"""
Steps tracking domain: POST /steps, GET /steps.
"""
import pytest
import requests


@pytest.fixture(scope="module")
def logged_steps(base_url: str, auth_headers: dict, today: str) -> dict:
    """Log steps once for all tests in this module."""
    r = requests.post(f"{base_url}/steps", headers=auth_headers, json={
        "stepCount": 8500,
        "date": today,
    })
    assert r.status_code in (200, 201), f"Steps log failed: {r.text}"
    return r.json()


@pytest.mark.crud
def test_log_steps_returns_step_count(logged_steps: dict, today: str) -> None:
    """Logged steps must echo stepCount and date."""
    s = logged_steps
    assert isinstance(s["id"], int)
    assert s["stepCount"] == 8500
    assert s["date"] == today


@pytest.mark.crud
def test_list_steps_contains_logged(
    base_url: str, auth_headers: dict, logged_steps: dict
) -> None:
    """GET /steps must include the logged step entry."""
    r = requests.get(f"{base_url}/steps", headers=auth_headers)
    assert r.status_code == 200, f"GET /steps failed: {r.text}"
    ids = [s["id"] for s in r.json()]
    assert logged_steps["id"] in ids, "Logged steps not found in list"


@pytest.mark.crud
def test_list_steps_with_date_filter(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Date-filtered GET /steps must return 200."""
    r = requests.get(
        f"{base_url}/steps",
        headers=auth_headers,
        params={"from": today, "to": today},
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_steps_negative_count_returns_400(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Negative step count must be rejected (@Min(0) constraint)."""
    r = requests.post(f"{base_url}/steps", headers=auth_headers, json={
        "stepCount": -1,
        "date": today,
    })
    assert r.status_code == 400, f"Expected 400 for negative steps, got {r.status_code}"

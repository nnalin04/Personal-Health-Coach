"""
Body metrics domain: POST /body-metrics, GET /body-metrics.
"""
import pytest
import requests


@pytest.fixture(scope="module")
def logged_metrics(base_url: str, auth_headers: dict, today: str) -> dict:
    """Log body metrics once for all tests in this module."""
    r = requests.post(f"{base_url}/body-metrics", headers=auth_headers, json={
        "weight": 78.5,
        "bmi": 24.8,
        "bodyFat": 18.0,
        "muscleMass": 36.0,
        "date": today,
    })
    assert r.status_code in (200, 201), f"Body metrics log failed: {r.text}"
    return r.json()


@pytest.mark.crud
def test_log_body_metrics_returns_fields(logged_metrics: dict, today: str) -> None:
    """Logged metrics must echo weight, bmi, bodyFat, muscleMass, date."""
    m = logged_metrics
    assert isinstance(m["id"], int)
    assert m["weight"] == 78.5
    assert m["bmi"] == 24.8
    assert m["bodyFat"] == 18.0
    assert m["muscleMass"] == 36.0
    assert m["date"] == today


@pytest.mark.crud
def test_list_body_metrics_contains_logged(
    base_url: str, auth_headers: dict, logged_metrics: dict
) -> None:
    """GET /body-metrics must include the logged entry."""
    r = requests.get(f"{base_url}/body-metrics", headers=auth_headers)
    assert r.status_code == 200, f"GET /body-metrics failed: {r.text}"
    ids = [m["id"] for m in r.json()]
    assert logged_metrics["id"] in ids, "Logged metrics not found in list"


@pytest.mark.crud
def test_log_body_metrics_weight_only(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Optional fields (bmi, bodyFat, muscleMass) should not be required."""
    r = requests.post(f"{base_url}/body-metrics", headers=auth_headers, json={
        "weight": 79.0,
        "date": today,
    })
    assert r.status_code in (200, 201), f"Weight-only metric log failed: {r.text}"
    assert r.json()["weight"] == 79.0


def test_body_metrics_zero_weight_returns_400(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Weight of 0 must be rejected (@Positive constraint)."""
    r = requests.post(f"{base_url}/body-metrics", headers=auth_headers, json={
        "weight": 0,
        "date": today,
    })
    assert r.status_code == 400, f"Expected 400 for zero weight, got {r.status_code}"

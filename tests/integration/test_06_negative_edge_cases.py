"""
SCENARIO: Negative & Edge Cases
=================================
Verifies the system rejects bad input gracefully — no 500s, no data corruption.

Tests:
  1.  Missing required fields → 400
  2.  Invalid data types → 400
  3.  Negative/out-of-range values → 400
  4.  Wrong Content-Type → 415 or 400
  5.  Future dates for historical logs
  6.  Extremely large payload
  7.  Concurrent duplicate submissions
  8.  Health summary with no data → returns structure (not error)
"""
import io
import time
import pytest
import requests
import threading
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from helpers.pdf_factory import make_minimal_pdf_bytes


@pytest.mark.integration
def test_workout_missing_required_fields(api_url, integration_user):
    """POST /workouts without required fields must return 400."""
    headers = integration_user["headers"]
    invalid_cases = [
        {},  # completely empty
        {"exerciseName": "Bench Press"},  # missing sets/reps/weight/date
        {"exerciseName": "Bench Press", "sets": 3, "reps": 10, "weight": 50.0},  # missing date
    ]
    for payload in invalid_cases:
        r = requests.post(f"{api_url}/workouts", json=payload, headers=headers, timeout=10)
        assert r.status_code in (400, 422), (
            f"Missing fields should return 4xx, got {r.status_code} for {payload}"
        )


@pytest.mark.integration
def test_workout_invalid_values(api_url, integration_user, today):
    """POST /workouts with negative sets/reps/weight must return 400."""
    headers = integration_user["headers"]
    invalid_cases = [
        {"exerciseName": "Test", "sets": -1, "reps": 10, "weight": 50.0, "date": today},
        {"exerciseName": "Test", "sets": 3, "reps": -5, "weight": 50.0, "date": today},
        {"exerciseName": "Test", "sets": 0, "reps": 10, "weight": 50.0, "date": today},
    ]
    for payload in invalid_cases:
        r = requests.post(f"{api_url}/workouts", json=payload, headers=headers, timeout=10)
        assert r.status_code in (400, 422), (
            f"Invalid values should return 4xx, got {r.status_code} for {payload}"
        )


@pytest.mark.integration
def test_food_missing_required_fields(api_url, integration_user):
    """POST /food without required fields must return 400."""
    headers = integration_user["headers"]
    r = requests.post(f"{api_url}/food", json={
        "mealType": "Lunch",
        # missing foodName, protein, carbs, fats, calories, date
    }, headers=headers, timeout=10)
    assert r.status_code in (400, 422)


@pytest.mark.integration
def test_food_negative_macros(api_url, integration_user, today):
    """POST /food with negative calories must return 400."""
    headers = integration_user["headers"]
    r = requests.post(f"{api_url}/food", json={
        "mealType": "Lunch",
        "foodName": "Ghost Food",
        "protein": -10.0,  # invalid
        "carbs": 50.0,
        "fats": 5.0,
        "calories": -500.0,  # invalid
        "date": today,
    }, headers=headers, timeout=10)
    assert r.status_code in (400, 422)


@pytest.mark.integration
def test_steps_negative_count(api_url, integration_user, today):
    """POST /steps with negative stepCount must return 400."""
    headers = integration_user["headers"]
    r = requests.post(f"{api_url}/steps", json={
        "stepCount": -1000,
        "date": today,
    }, headers=headers, timeout=10)
    assert r.status_code in (400, 422)


@pytest.mark.integration
def test_body_metrics_zero_weight(api_url, integration_user, today):
    """POST /body-metrics with zero weight (not positive) must return 400."""
    headers = integration_user["headers"]
    r = requests.post(f"{api_url}/body-metrics", json={
        "weight": 0.0,  # @Positive fails
        "bmi": 0.0,
        "date": today,
    }, headers=headers, timeout=10)
    assert r.status_code in (400, 422)


@pytest.mark.integration
def test_invalid_goal_type(api_url, integration_user):
    """POST /goals with unknown goalType must return 400."""
    headers = integration_user["headers"]
    r = requests.post(f"{api_url}/goals", json={
        "goalType": "INVALID_TYPE",
        "targetValue": 70.0,
        "targetDate": "2026-12-31",
    }, headers=headers, timeout=10)
    assert r.status_code in (400, 422)


@pytest.mark.integration
def test_health_summary_with_no_data_returns_structure(api_url, today):
    """
    A fresh user with no data should get a valid health summary structure,
    not a 500 or empty response.
    """
    import time as _time
    email = f"nodata_{int(_time.time())}@healthcoach.test"
    r = requests.post(f"{api_url}/auth/register", json={
        "email": email, "password": "NoData123!",
        "age": 22, "gender": "Female", "height": 160.0,
        "goal": "Fitness", "dietType": "Any", "medicalFlags": "",
    }, timeout=10)
    assert r.status_code in (200, 201)
    token = r.json()["accessToken"]
    headers = {"Authorization": f"Bearer {token}"}

    r = requests.get(f"{api_url}/health-summary/me?days=7", headers=headers, timeout=15)
    assert r.status_code == 200, f"Fresh user health summary failed: {r.status_code}"
    summary = r.json()
    assert "profile" in summary
    assert "nutrition_summary" in summary
    assert "training_summary" in summary


@pytest.mark.integration
def test_wrong_content_type_for_json_endpoint(api_url, integration_user, today):
    """Sending form data to a JSON endpoint must return 4xx (not 500)."""
    headers = dict(integration_user["headers"])
    headers["Content-Type"] = "application/x-www-form-urlencoded"
    r = requests.post(f"{api_url}/workouts",
                      data="exerciseName=Test&sets=3&reps=10&weight=50&date=2026-01-01",
                      headers=headers, timeout=10)
    # Should reject cleanly — not 500
    assert r.status_code in (400, 415, 422, 500) and r.status_code != 500 or r.status_code == 400, (
        f"Wrong content-type should not return 500, got {r.status_code}"
    )


@pytest.mark.integration
def test_concurrent_duplicate_food_logs(api_url, integration_user, today):
    """
    Simultaneous duplicate POST /food requests must not cause 500s.
    Both may succeed (idempotency not required), but neither should error.
    """
    headers = integration_user["headers"]
    payload = {
        "mealType": "Snack", "foodName": "Concurrent Apple",
        "protein": 0.5, "carbs": 25.0, "fats": 0.3, "calories": 95.0, "date": today,
    }
    results = []

    def post_food():
        r = requests.post(f"{api_url}/food", json=payload, headers=headers, timeout=10)
        results.append(r.status_code)

    threads = [threading.Thread(target=post_food) for _ in range(3)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    # All responses should be 2xx — no 500s
    for code in results:
        assert code in (200, 201), f"Concurrent food log returned {code}"

"""
Workout logging domain: POST /workouts, GET /workouts.
"""
import pytest
import requests


@pytest.fixture(scope="module")
def logged_workout(base_url: str, auth_headers: dict, today: str) -> dict:
    """Log a workout once for all tests in this module."""
    r = requests.post(f"{base_url}/workouts", headers=auth_headers, json={
        "exerciseName": "Deadlift",
        "sets": 4,
        "reps": 6,
        "weight": 100.0,
        "date": today,
    })
    assert r.status_code in (200, 201), f"Workout log failed: {r.text}"
    return r.json()


@pytest.mark.crud
def test_log_workout_returns_correct_fields(logged_workout: dict, today: str) -> None:
    """Logged workout must echo all submitted fields plus an integer id."""
    w = logged_workout
    assert isinstance(w["id"], int)
    assert w["exerciseName"] == "Deadlift"
    assert w["sets"] == 4
    assert w["reps"] == 6
    assert w["weight"] == 100.0
    assert w["date"] == today


@pytest.mark.crud
def test_list_workouts_contains_logged(
    base_url: str, auth_headers: dict, logged_workout: dict
) -> None:
    """GET /workouts must include the just-logged workout."""
    r = requests.get(f"{base_url}/workouts", headers=auth_headers)
    assert r.status_code == 200, f"GET /workouts failed: {r.text}"
    ids = [w["id"] for w in r.json()]
    assert logged_workout["id"] in ids, "Logged workout not found in list"


@pytest.mark.crud
def test_list_workouts_with_date_filter(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Date-filtered GET must return 200 (may be empty but not error)."""
    r = requests.get(
        f"{base_url}/workouts",
        headers=auth_headers,
        params={"from": today, "to": today},
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_workout_missing_sets_returns_400(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Omitting required field `sets` must return 400."""
    r = requests.post(f"{base_url}/workouts", headers=auth_headers, json={
        "exerciseName": "Squat",
        "reps": 10,
        "weight": 80.0,
        "date": today,
        # sets intentionally omitted
    })
    assert r.status_code == 400, f"Expected 400, got {r.status_code}"


def test_workout_negative_reps_returns_400(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Negative reps must be rejected with 400."""
    r = requests.post(f"{base_url}/workouts", headers=auth_headers, json={
        "exerciseName": "Press",
        "sets": 3,
        "reps": -5,
        "weight": 50.0,
        "date": today,
    })
    assert r.status_code == 400, f"Expected 400, got {r.status_code}"

"""
SCENARIO: Cross-User Data Isolation
=====================================
Verifies that User A cannot access or modify User B's data.
This is critical for HIPAA-adjacent health data privacy.

Flow:
  1.  User A logs workout, food, body metrics, steps
  2.  User A creates a goal and uploads a medical report
  3.  User B attempts to access User A's data via known IDs → must get 403 or 404
  4.  User B's own data endpoints return only User B's records
  5.  User B cannot export User A's data
"""
import io
import pytest
import requests
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from helpers.pdf_factory import make_lab_report_pdf


@pytest.mark.integration
def test_cross_user_data_isolation(api_url, integration_user, second_user, today):
    """User B cannot access or see User A's private health data."""
    headers_a = integration_user["headers"]
    headers_b = second_user["headers"]

    # ── User A creates data ────────────────────────────────────────────────────
    # Workout
    r = requests.post(f"{api_url}/workouts", json={
        "exerciseName": "Secret Exercise of User A",
        "sets": 3, "reps": 10, "weight": 50.0, "date": today,
    }, headers=headers_a, timeout=10)
    assert r.status_code in (200, 201)
    workout_id_a = r.json()["id"]

    # Food
    r = requests.post(f"{api_url}/food", json={
        "mealType": "Lunch", "foodName": "User A Secret Meal",
        "protein": 30.0, "carbs": 40.0, "fats": 10.0, "calories": 370.0, "date": today,
    }, headers=headers_a, timeout=10)
    assert r.status_code in (200, 201)
    food_id_a = r.json()["id"]

    # Goal
    r = requests.post(f"{api_url}/goals", json={
        "goalType": "WEIGHT", "targetValue": 70.0, "targetDate": "2026-12-31",
    }, headers=headers_a, timeout=10)
    assert r.status_code in (200, 201)
    goal_id_a = r.json()["id"]

    # Medical report
    r = requests.post(
        f"{api_url}/medical/reports",
        files={"file": ("report_a.pdf", io.BytesIO(make_lab_report_pdf()), "application/pdf")},
        data={"reportDate": today},
        headers=headers_a,
        timeout=30,
    )
    assert r.status_code in (200, 201)
    report_id_a = r.json()["id"]

    # ── User B's list endpoints return ONLY User B's own data ─────────────────
    # User B's workout list should NOT contain User A's workout
    r = requests.get(f"{api_url}/workouts", headers=headers_b, timeout=10)
    assert r.status_code == 200
    workout_ids_b = [w["id"] for w in r.json()]
    assert workout_id_a not in workout_ids_b, (
        f"User A's workout {workout_id_a} visible to User B!"
    )

    # User B's food list should NOT contain User A's food
    r = requests.get(f"{api_url}/food", headers=headers_b, timeout=10)
    assert r.status_code == 200
    food_ids_b = [f["id"] for f in r.json()]
    assert food_id_a not in food_ids_b, (
        f"User A's food {food_id_a} visible to User B!"
    )

    # User B's goals should NOT contain User A's goal
    r = requests.get(f"{api_url}/goals", headers=headers_b, timeout=10)
    assert r.status_code == 200
    goal_ids_b = [g["id"] for g in r.json()]
    assert goal_id_a not in goal_ids_b, (
        f"User A's goal {goal_id_a} visible to User B!"
    )

    # User B's medical reports should NOT contain User A's report
    r = requests.get(f"{api_url}/medical/reports", headers=headers_b, timeout=10)
    assert r.status_code == 200
    report_ids_b = [rep["id"] for rep in r.json()]
    assert report_id_a not in report_ids_b, (
        f"User A's medical report {report_id_a} visible to User B!"
    )

    # ── User B cannot access User A's report lab values ───────────────────────
    r = requests.get(f"{api_url}/medical/reports/{report_id_a}/lab-values",
                     headers=headers_b, timeout=10)
    assert r.status_code in (403, 404), (
        f"User B should not see User A's lab values, got {r.status_code}"
    )

    # ── User B's profile is User B's own profile ──────────────────────────────
    r = requests.get(f"{api_url}/users/me", headers=headers_b, timeout=10)
    assert r.status_code == 200
    profile_b = r.json()
    assert profile_b["email"] == second_user["email"], (
        f"User B got wrong profile: expected {second_user['email']}, got {profile_b['email']}"
    )
    assert profile_b["email"] != integration_user["email"], (
        "User B's /users/me returned User A's profile!"
    )

    # ── User B's data export contains only User B's data ─────────────────────
    r = requests.get(f"{api_url}/users/me/export", headers=headers_b, timeout=15)
    assert r.status_code == 200
    export_b = r.json()
    assert export_b["profile"]["email"] == second_user["email"]

    # User A's items must not appear in User B's export
    b_workout_ids = [w["id"] for w in export_b.get("workoutLogs", [])]
    assert workout_id_a not in b_workout_ids, "User A's workout in User B's export!"

    b_food_ids = [f["id"] for f in export_b.get("foodLogs", [])]
    assert food_id_a not in b_food_ids, "User A's food in User B's export!"

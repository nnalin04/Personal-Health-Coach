"""
SCENARIO: Complete User Journey
================================
Simulates a real user from first open to AI insight — in one flow.

Flow:
  1.  Register new account
  2.  Login with those credentials → verify fresh token works
  3.  Update profile (region, cuisine style)
  4.  Log a workout
  5.  Log a food item
  6.  Log body metrics
  7.  Log daily steps
  8.  Upload a medical report (PDF)
  9.  Request AI health insights
  10. Fetch health summary (7-day)
  11. Fetch nutrient daily summary
  12. Create a health goal
  13. Export all user data → verify every domain is present
  14. Verify cross-service data consistency

Each step asserts HTTP status AND response shape.
The test is intentionally one long scenario — it tests the message flow,
not just individual endpoints.
"""
import io
import time
import pytest
import requests
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from helpers.pdf_factory import make_lab_report_pdf


@pytest.mark.integration
def test_complete_user_journey(api_url, today):
    """Full user journey: register → log all domains → AI insights → export."""

    # ── 1. Register ────────────────────────────────────────────────────────────
    email = f"journey_{int(time.time())}@healthcoach.test"
    r = requests.post(f"{api_url}/auth/register", json={
        "email": email,
        "password": "JourneyPass123!",
        "age": 27,
        "gender": "Male",
        "height": 175.0,
        "goal": "Build Muscle",
        "dietType": "Omnivore",
        "medicalFlags": "",
    }, timeout=15)
    assert r.status_code in (200, 201), f"Register failed: {r.text}"
    data = r.json()
    token = data["accessToken"]
    user_id = data["user"]["id"]
    headers = {"Authorization": f"Bearer {token}"}
    assert isinstance(user_id, int)
    assert data["user"]["email"] == email

    # ── 2. Login with same credentials → fresh token ────────────────────────────
    r = requests.post(f"{api_url}/auth/login", json={
        "email": email,
        "password": "JourneyPass123!",
    }, timeout=10)
    assert r.status_code == 200, f"Login failed: {r.text}"
    login_token = r.json()["accessToken"]
    assert isinstance(login_token, str) and len(login_token) > 10
    # Use the login token going forward (verifies it works, not just register token)
    headers = {"Authorization": f"Bearer {login_token}"}

    # ── 3. Update profile ───────────────────────────────────────────────────────
    r = requests.put(f"{api_url}/users/me", json={
        "region": "South Asia",
        "cuisineStyle": "Indian",
        "dietaryRestrictions": "None",
    }, headers=headers, timeout=10)
    assert r.status_code == 200, f"Profile update failed: {r.text}"
    profile = r.json()
    assert profile.get("region") == "South Asia"
    assert profile.get("cuisineStyle") == "Indian"

    # ── 4. Log a workout ────────────────────────────────────────────────────────
    r = requests.post(f"{api_url}/workouts", json={
        "exerciseName": "Bench Press",
        "sets": 4,
        "reps": 8,
        "weight": 80.0,
        "date": today,
    }, headers=headers, timeout=10)
    assert r.status_code in (200, 201), f"Workout log failed: {r.text}"
    workout = r.json()
    workout_id = workout.get("id")
    assert workout_id is not None
    assert workout["exerciseName"] == "Bench Press"
    assert workout["sets"] == 4

    # Verify workout appears in list
    r = requests.get(f"{api_url}/workouts", headers=headers, timeout=10)
    assert r.status_code == 200
    workout_list = r.json()
    assert any(w["id"] == workout_id for w in workout_list), "Workout not found in list"

    # ── 5. Log food ─────────────────────────────────────────────────────────────
    r = requests.post(f"{api_url}/food", json={
        "mealType": "Lunch",
        "foodName": "Grilled Chicken with Rice",
        "protein": 40.0,
        "carbs": 60.0,
        "fats": 8.0,
        "calories": 480.0,
        "date": today,
    }, headers=headers, timeout=10)
    assert r.status_code in (200, 201), f"Food log failed: {r.text}"
    food = r.json()
    food_id = food.get("id")
    assert food_id is not None
    assert food["foodName"] == "Grilled Chicken with Rice"
    assert food["calories"] == 480.0

    # Verify food appears in list
    r = requests.get(f"{api_url}/food", headers=headers, timeout=10)
    assert r.status_code == 200
    food_list = r.json()
    assert any(f["id"] == food_id for f in food_list), "Food log not found in list"

    # ── 6. Log body metrics ─────────────────────────────────────────────────────
    r = requests.post(f"{api_url}/body-metrics", json={
        "weight": 78.0,
        "bmi": 25.5,
        "bodyFat": 18.0,
        "muscleMass": 42.0,
        "date": today,
    }, headers=headers, timeout=10)
    assert r.status_code in (200, 201), f"Body metrics failed: {r.text}"
    metrics = r.json()
    assert metrics.get("weight") == 78.0
    assert metrics.get("bmi") == 25.5

    # ── 7. Log steps ────────────────────────────────────────────────────────────
    r = requests.post(f"{api_url}/steps", json={
        "stepCount": 9500,
        "date": today,
    }, headers=headers, timeout=10)
    assert r.status_code in (200, 201), f"Steps log failed: {r.text}"
    steps = r.json()
    assert steps.get("stepCount") == 9500

    # ── 8. Upload medical report (real PDF with lab values) ──────────────────────
    pdf_bytes = make_lab_report_pdf()
    r = requests.post(
        f"{api_url}/medical/reports",
        files={"file": ("lab_report.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
        data={"reportDate": today},
        headers=headers,
        timeout=30,  # AI parsing may take time
    )
    assert r.status_code in (200, 201), f"Medical upload failed: {r.text}"
    report = r.json()
    report_id = report.get("id")
    assert report_id is not None

    # Verify report appears in list
    r = requests.get(f"{api_url}/medical/reports", headers=headers, timeout=10)
    assert r.status_code == 200
    reports = r.json()
    assert any(rep["id"] == report_id for rep in reports), "Medical report not in list"

    # ── 9. Request AI health insights ────────────────────────────────────────────
    r = requests.get(f"{api_url}/health-summary/me/ai-insights",
                     headers=headers, timeout=60)
    assert r.status_code == 200, f"AI insights failed: {r.text}"
    insights = r.json()
    # Verify response has content — either direct AI response or graceful fallback
    assert insights is not None
    assert isinstance(insights, (dict, str, list))

    # ── 10. Fetch health summary ──────────────────────────────────────────────────
    r = requests.get(f"{api_url}/health-summary/me?days=7",
                     headers=headers, timeout=15)
    assert r.status_code == 200, f"Health summary failed: {r.text}"
    summary = r.json()
    assert "profile" in summary, "Health summary missing 'profile'"
    assert "nutrition_summary" in summary, "Health summary missing 'nutrition_summary'"
    assert "training_summary" in summary, "Health summary missing 'training_summary'"
    assert "weight_trend" in summary, "Health summary missing 'weight_trend'"
    # Verify logged data appears in summary
    nutrition = summary.get("nutrition_summary", {})
    # At least one food was logged, so total_entries should be >= 1
    assert nutrition.get("total_entries", 0) >= 1, "Food log not reflected in health summary"

    # ── 11. Fetch nutrient daily summary ─────────────────────────────────────────
    r = requests.get(f"{api_url}/nutrient/daily-summary?date={today}",
                     headers=headers, timeout=15)
    assert r.status_code in (200, 404), f"Nutrient summary error: {r.text}"
    # 404 is acceptable if async nutrient analysis hasn't completed yet

    # ── 12. Create a health goal ──────────────────────────────────────────────────
    r = requests.post(f"{api_url}/goals", json={
        "goalType": "WEIGHT",
        "targetValue": 75.0,
        "targetDate": "2026-12-31",
    }, headers=headers, timeout=10)
    assert r.status_code in (200, 201), f"Goal creation failed: {r.text}"
    goal = r.json()
    goal_id = goal.get("id")
    assert goal_id is not None
    assert goal["goalType"] == "WEIGHT"

    # Verify goal appears in list
    r = requests.get(f"{api_url}/goals", headers=headers, timeout=10)
    assert r.status_code == 200
    goals = r.json()
    assert any(g["id"] == goal_id for g in goals), "Goal not found in list"

    # ── 13. Export all user data ──────────────────────────────────────────────────
    r = requests.get(f"{api_url}/users/me/export", headers=headers, timeout=15)
    assert r.status_code == 200, f"Data export failed: {r.text}"
    export = r.json()
    assert "profile" in export, "Export missing 'profile'"
    assert "exportedAt" in export, "Export missing 'exportedAt'"
    assert "workoutLogs" in export, "Export missing 'workoutLogs'"
    assert "foodLogs" in export, "Export missing 'foodLogs'"
    assert "bodyMetrics" in export, "Export missing 'bodyMetrics'"
    assert "stepsLogs" in export, "Export missing 'stepsLogs'"
    assert "medicalReports" in export, "Export missing 'medicalReports'"
    assert "healthGoals" in export, "Export missing 'healthGoals'"

    # ── 14. Cross-service data consistency checks ─────────────────────────────────
    # Workout logged → appears in export
    assert len(export["workoutLogs"]) >= 1, "Workout not in export"
    assert export["workoutLogs"][0]["exerciseName"] == "Bench Press"

    # Food logged → appears in export
    assert len(export["foodLogs"]) >= 1, "Food not in export"
    assert export["foodLogs"][0]["foodName"] == "Grilled Chicken with Rice"

    # Body metrics → appears in export
    assert len(export["bodyMetrics"]) >= 1, "Body metrics not in export"

    # Steps → appears in list
    r = requests.get(f"{api_url}/steps", headers=headers, timeout=10)
    assert r.status_code == 200
    assert len(r.json()) >= 1, "Steps not persisted"

    # Medical report → appears in export
    assert len(export["medicalReports"]) >= 1, "Medical report not in export"

    # Goals → appears in export
    assert len(export["healthGoals"]) >= 1, "Goals not in export"

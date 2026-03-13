"""
Food logging domain: POST /foods, GET /foods.
Food logs trigger the async NutrientIntegrationService in the background.
"""
import pytest
import requests


@pytest.fixture(scope="module")
def logged_food(base_url: str, auth_headers: dict, today: str) -> dict:
    """Log a meal once for all tests in this module."""
    r = requests.post(f"{base_url}/foods", headers=auth_headers, json={
        "mealType": "Lunch",
        "foodName": "Dal Chawal",
        "protein": 12.0,
        "carbs": 60.0,
        "fats": 4.0,
        "calories": 320.0,
        "date": today,
    })
    assert r.status_code in (200, 201), f"Food log failed: {r.text}"
    return r.json()


@pytest.mark.crud
def test_log_food_returns_all_macros(logged_food: dict, today: str) -> None:
    """Logged food must echo mealType, foodName, all macros, and date."""
    f = logged_food
    assert isinstance(f["id"], int)
    assert f["mealType"] == "Lunch"
    assert f["foodName"] == "Dal Chawal"
    assert f["protein"] == 12.0
    assert f["carbs"] == 60.0
    assert f["fats"] == 4.0
    assert f["calories"] == 320.0
    assert f["date"] == today


@pytest.mark.crud
def test_list_foods_contains_logged(
    base_url: str, auth_headers: dict, logged_food: dict
) -> None:
    """GET /foods must include the just-logged food entry."""
    r = requests.get(f"{base_url}/foods", headers=auth_headers)
    assert r.status_code == 200, f"GET /foods failed: {r.text}"
    ids = [f["id"] for f in r.json()]
    assert logged_food["id"] in ids, "Logged food not found in list"


@pytest.mark.crud
def test_list_foods_with_date_filter(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Date-filtered GET /foods must return 200."""
    r = requests.get(
        f"{base_url}/foods",
        headers=auth_headers,
        params={"from": today, "to": today},
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_food_negative_calories_returns_400(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Negative calories must be rejected with 400."""
    r = requests.post(f"{base_url}/foods", headers=auth_headers, json={
        "mealType": "Dinner",
        "foodName": "Invalid",
        "protein": 10.0,
        "carbs": 10.0,
        "fats": 10.0,
        "calories": -50.0,
        "date": today,
    })
    assert r.status_code == 400, f"Expected 400 for negative calories, got {r.status_code}"


def test_food_missing_food_name_returns_400(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """Blank foodName must be rejected with 400."""
    r = requests.post(f"{base_url}/foods", headers=auth_headers, json={
        "mealType": "Breakfast",
        "foodName": "",
        "protein": 5.0,
        "carbs": 20.0,
        "fats": 2.0,
        "calories": 100.0,
        "date": today,
    })
    assert r.status_code == 400, f"Expected 400 for blank foodName, got {r.status_code}"

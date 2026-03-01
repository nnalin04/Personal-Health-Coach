"""
User profile domain: GET /users/me, PUT /users/me.
"""
import pytest
import requests


@pytest.mark.crud
def test_get_profile_returns_registered_fields(
    base_url: str, auth_headers: dict, auth: dict
) -> None:
    """GET /users/me must return the registered user's email and core fields."""
    r = requests.get(f"{base_url}/users/me", headers=auth_headers)
    assert r.status_code == 200, f"GET /users/me failed: {r.text}"
    data = r.json()
    assert data["email"] == auth["email"]
    for field in ("id", "age", "gender", "height", "goal", "dietType"):
        assert field in data, f"Missing field: {field}"


@pytest.mark.crud
def test_update_profile_nutrition_preferences(
    base_url: str, auth_headers: dict
) -> None:
    """PUT /users/me must persist region, cuisineStyle, dietaryRestrictions."""
    r = requests.put(f"{base_url}/users/me", headers=auth_headers, json={
        "region": "Bihar, India",
        "cuisineStyle": "north_indian",
        "dietaryRestrictions": "vegetarian",
    })
    assert r.status_code == 200, f"PUT /users/me failed: {r.text}"
    data = r.json()
    assert data["region"] == "Bihar, India"
    assert data["cuisineStyle"] == "north_indian"
    assert data["dietaryRestrictions"] == "vegetarian"


@pytest.mark.crud
def test_update_profile_age_and_goal(base_url: str, auth_headers: dict) -> None:
    """Partial update — only age and goal — must not overwrite other fields."""
    r = requests.put(f"{base_url}/users/me", headers=auth_headers, json={
        "age": 30,
        "goal": "Maintain Weight",
    })
    assert r.status_code == 200, f"Partial PUT failed: {r.text}"
    data = r.json()
    assert data["age"] == 30
    assert data["goal"] == "Maintain Weight"


@pytest.mark.auth_boundary
def test_get_profile_without_token_returns_401(base_url: str) -> None:
    """GET /users/me without Authorization must return 401 or 403."""
    r = requests.get(f"{base_url}/users/me")
    assert r.status_code in (401, 403), f"Expected 401/403, got {r.status_code}"

"""
Goals domain: POST /goals, GET /goals, DELETE /goals/{id}.
"""
import pytest
import requests


@pytest.fixture(scope="module")
def created_goal(base_url: str, auth_headers: dict) -> dict:
    """Create a goal once for all tests in this module."""
    r = requests.post(f"{base_url}/goals", headers=auth_headers, json={
        "goalType": "STEPS",
        "targetValue": 10000.0,
        "targetDate": "2026-12-31",
    })
    assert r.status_code in (200, 201), f"Goal creation failed: {r.text}"
    return r.json()


@pytest.mark.crud
def test_create_goal_returns_id_and_type(created_goal: dict) -> None:
    """Created goal must have an integer id and echo goalType."""
    g = created_goal
    assert isinstance(g["id"], int)
    assert g["goalType"] == "STEPS"
    assert g["targetValue"] == 10000.0


@pytest.mark.crud
def test_list_goals_contains_created(
    base_url: str, auth_headers: dict, created_goal: dict
) -> None:
    """GET /goals must include the just-created goal."""
    r = requests.get(f"{base_url}/goals", headers=auth_headers)
    assert r.status_code == 200, f"GET /goals failed: {r.text}"
    ids = [g["id"] for g in r.json()]
    assert created_goal["id"] in ids, "Created goal not found in list"


@pytest.mark.crud
def test_create_second_goal_different_type(
    base_url: str, auth_headers: dict
) -> None:
    """Can create multiple goals with different types."""
    r = requests.post(f"{base_url}/goals", headers=auth_headers, json={
        "goalType": "WEIGHT",
        "targetValue": 75.0,
        "targetDate": "2026-06-01",
    })
    assert r.status_code in (200, 201), f"Second goal failed: {r.text}"
    assert r.json()["goalType"] == "WEIGHT"


@pytest.mark.crud
def test_delete_goal_removes_it_from_list(
    base_url: str, auth_headers: dict, created_goal: dict
) -> None:
    """DELETE /goals/{id} must remove the goal from subsequent GET."""
    goal_id = created_goal["id"]
    del_r = requests.delete(f"{base_url}/goals/{goal_id}", headers=auth_headers)
    assert del_r.status_code == 200, f"DELETE failed: {del_r.text}"

    list_r = requests.get(f"{base_url}/goals", headers=auth_headers)
    assert list_r.status_code == 200
    ids = [g["id"] for g in list_r.json()]
    assert goal_id not in ids, f"Goal {goal_id} still present after delete"

"""
Auth domain: register, login, input validation.
"""
import time
import pytest
import requests


@pytest.mark.smoke
def test_register_new_user_returns_token(base_url: str) -> None:
    """Registering a new user must return an accessToken and user object."""
    email = f"reg_{int(time.time())}@healthcoach.test"
    r = requests.post(f"{base_url}/auth/register", json={
        "email": email,
        "password": "ValidPass1!",
        "age": 25,
        "gender": "Female",
        "height": 165.0,
        "goal": "Lose Weight",
        "dietType": "Vegetarian",
        "medicalFlags": "",
    })
    assert r.status_code in (200, 201), f"Register failed: {r.text}"
    data = r.json()
    assert "accessToken" in data, "No accessToken in response"
    assert isinstance(data["user"]["id"], int)
    assert data["user"]["email"] == email


@pytest.mark.smoke
def test_register_duplicate_email_fails(base_url: str, auth: dict) -> None:
    """Re-registering with the same email must return 4xx."""
    r = requests.post(f"{base_url}/auth/register", json={
        "email": auth["email"],
        "password": "AnotherPass1!",
        "age": 30,
        "gender": "Male",
        "height": 175.0,
        "goal": "Build Muscle",
        "dietType": "Omnivore",
        "medicalFlags": "",
    })
    assert r.status_code in (400, 409), f"Expected 4xx for duplicate email, got {r.status_code}"


def test_login_valid_credentials(base_url: str, auth: dict) -> None:
    """Login with correct credentials must return an accessToken."""
    r = requests.post(f"{base_url}/auth/login", json={
        "email": auth["email"],
        "password": "TestPass123!",
    })
    assert r.status_code == 200, f"Login failed: {r.text}"
    assert "accessToken" in r.json()


@pytest.mark.auth_boundary
def test_login_wrong_password_returns_401(base_url: str, auth: dict) -> None:
    """Wrong password must return 401."""
    r = requests.post(f"{base_url}/auth/login", json={
        "email": auth["email"],
        "password": "WrongPassword999!",
    })
    assert r.status_code == 401, f"Expected 401, got {r.status_code}"


def test_register_invalid_email_returns_400(base_url: str) -> None:
    """Malformed email must return 400."""
    r = requests.post(f"{base_url}/auth/register", json={
        "email": "not-an-email",
        "password": "ValidPass1!",
        "age": 25,
        "gender": "Male",
        "height": 175.0,
        "goal": "Fitness",
        "dietType": "Any",
    })
    assert r.status_code == 400, f"Expected 400 for invalid email, got {r.status_code}"


def test_register_short_password_returns_400(base_url: str) -> None:
    """Password shorter than 8 chars must return 400."""
    r = requests.post(f"{base_url}/auth/register", json={
        "email": f"short_{int(time.time())}@test.com",
        "password": "abc",
        "age": 25,
        "gender": "Male",
        "height": 175.0,
        "goal": "Fitness",
        "dietType": "Any",
    })
    assert r.status_code == 400, f"Expected 400 for short password, got {r.status_code}"

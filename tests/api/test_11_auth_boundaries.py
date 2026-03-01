"""
Auth boundary sweep: every protected endpoint must reject requests with no token.
Parametrized so adding new endpoints only requires updating PROTECTED_ROUTES.
"""
import pytest
import requests

# Every protected route in the system.
# Format: (HTTP_METHOD, path_without_base)
PROTECTED_ROUTES = [
    ("GET",    "/users/me"),
    ("PUT",    "/users/me"),
    ("POST",   "/workouts"),
    ("GET",    "/workouts"),
    ("POST",   "/foods"),
    ("GET",    "/foods"),
    ("POST",   "/body-metrics"),
    ("GET",    "/body-metrics"),
    ("POST",   "/steps"),
    ("GET",    "/steps"),
    ("POST",   "/medical/reports"),
    ("GET",    "/medical/reports"),
    ("GET",    "/nutrient/daily-summary"),
    ("GET",    "/nutrient/weekly-trends"),
    ("POST",   "/nutrient/recommendations"),
    ("GET",    "/health-summary/me"),
    ("POST",   "/health-summary/me/ai-insights"),
    ("GET",    "/goals"),
    ("POST",   "/goals"),
]


@pytest.mark.auth_boundary
@pytest.mark.parametrize("method,path", PROTECTED_ROUTES)
def test_no_token_returns_401_or_403(base_url: str, method: str, path: str) -> None:
    """Every protected endpoint must refuse requests without a JWT token."""
    r = requests.request(method, f"{base_url}{path}", timeout=10)
    assert r.status_code in (401, 403), (
        f"{method} {path} returned {r.status_code} (expected 401 or 403). "
        f"Body: {r.text[:200]}"
    )


@pytest.mark.auth_boundary
@pytest.mark.parametrize("method,path", [
    ("GET",  "/users/me"),
    ("GET",  "/workouts"),
    ("GET",  "/health-summary/me"),
])
def test_invalid_token_returns_401_or_403(base_url: str, method: str, path: str) -> None:
    """A structurally invalid JWT must be rejected with 401 or 403."""
    headers = {"Authorization": "Bearer this.is.not.a.valid.jwt"}
    r = requests.request(method, f"{base_url}{path}", headers=headers, timeout=10)
    assert r.status_code in (401, 403), (
        f"{method} {path} with bad token returned {r.status_code}"
    )

"""
Layer 0: Service health checks.
These are the first tests to run — if they fail, everything else will fail too.
"""
import pytest
import requests


@pytest.mark.smoke
def test_backend_actuator_health(base_url: str) -> None:
    """Backend Spring Boot actuator must report status UP."""
    actuator_url = base_url.replace("/api", "/actuator/health")
    r = requests.get(actuator_url, timeout=10)
    assert r.status_code == 200, f"Actuator returned {r.status_code}: {r.text}"
    assert r.json().get("status") == "UP", f"Backend not UP: {r.json()}"


@pytest.mark.smoke
def test_ai_service_health(ai_url: str) -> None:
    """AI FastAPI service must return {status: ok}."""
    r = requests.get(f"{ai_url}/health", timeout=10)
    assert r.status_code == 200, f"AI service health returned {r.status_code}: {r.text}"
    assert r.json() == {"status": "ok"}, f"Unexpected AI health response: {r.json()}"

"""
Health summary + AI insights domain.
Aggregate tests — requires workout, food, steps, and body metrics logged first.
"""
import pytest
import requests


@pytest.mark.aggregate
def test_health_summary_has_required_sections(
    base_url: str, auth_headers: dict
) -> None:
    """GET /health-summary/me must return all top-level sections."""
    r = requests.get(f"{base_url}/health-summary/me", headers=auth_headers)
    assert r.status_code == 200, f"Health summary failed: {r.text}"
    data = r.json()
    for key in ("profile", "nutrition_summary", "training_summary",
                "weight_trend", "medical_trends", "risk_flags"):
        assert key in data, f"Missing section: {key}"


@pytest.mark.aggregate
def test_health_summary_profile_matches_user(
    base_url: str, auth_headers: dict, auth: dict
) -> None:
    """Health summary profile email must match the test user."""
    r = requests.get(f"{base_url}/health-summary/me", headers=auth_headers)
    assert r.status_code == 200
    profile = r.json().get("profile", {})
    assert profile.get("email") == auth["email"]


@pytest.mark.aggregate
@pytest.mark.ai
def test_ai_insights_returns_structured_advice(
    base_url: str, auth_headers: dict
) -> None:
    """POST /health-summary/me/ai-insights must return all insight categories."""
    r = requests.post(
        f"{base_url}/health-summary/me/ai-insights",
        headers=auth_headers,
        timeout=30,  # AI call may take a few seconds
    )
    assert r.status_code == 200, f"AI insights failed: {r.text}"
    data = r.json()
    assert "summary" in data
    assert "ai_insights" in data
    ai = data["ai_insights"]
    for key in ("dietSuggestions", "trainingSuggestions",
                "recoverySuggestions", "medicalAwarenessNotes"):
        assert key in ai, f"Missing insight key: {key}"
        assert isinstance(ai[key], list), f"{key} must be a list"
        # Fallback always returns at least one item
        assert len(ai[key]) > 0, f"{key} list is empty — fallback should populate it"


@pytest.mark.aggregate
@pytest.mark.ai
def test_ai_insights_disclaimer_is_non_empty(
    base_url: str, auth_headers: dict
) -> None:
    """AI insights disclaimer must be a non-empty string (legal safeguard)."""
    r = requests.post(
        f"{base_url}/health-summary/me/ai-insights",
        headers=auth_headers,
        timeout=30,
    )
    assert r.status_code == 200
    disclaimer = r.json()["ai_insights"].get("disclaimer", "")
    assert isinstance(disclaimer, str) and len(disclaimer) > 0, (
        "Disclaimer must be present and non-empty"
    )

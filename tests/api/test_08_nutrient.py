"""
Nutrient intelligence domain: daily summary, weekly trends, recommendations.
Requires food to have been logged (test_04 runs first due to filename ordering).
"""
import pytest
import requests


@pytest.mark.aggregate
def test_daily_nutrient_summary_has_required_keys(
    base_url: str, auth_headers: dict
) -> None:
    """GET /nutrient/daily-summary must return the expected response structure."""
    r = requests.get(f"{base_url}/nutrient/daily-summary", headers=auth_headers)
    assert r.status_code == 200, f"Daily summary failed: {r.text}"
    data = r.json()
    for key in ("date", "totalIntake", "rdaValues", "percentOfRda",
                "deficientNutrients", "adequateNutrients"):
        assert key in data, f"Missing key in daily summary: {key}"


@pytest.mark.aggregate
def test_daily_nutrient_summary_with_explicit_date(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """GET /nutrient/daily-summary?date=today must echo the requested date."""
    r = requests.get(
        f"{base_url}/nutrient/daily-summary",
        headers=auth_headers,
        params={"date": today},
    )
    assert r.status_code == 200, f"Daily summary with date failed: {r.text}"
    assert r.json()["date"] == today


@pytest.mark.aggregate
def test_weekly_nutrient_trends_has_required_keys(
    base_url: str, auth_headers: dict
) -> None:
    """GET /nutrient/weekly-trends must return the expected response structure."""
    r = requests.get(f"{base_url}/nutrient/weekly-trends", headers=auth_headers)
    assert r.status_code == 200, f"Weekly trends failed: {r.text}"
    data = r.json()
    for key in ("weekStart", "weekEnd", "dailyBreakdowns",
                "chronicDeficiencies", "totalDaysTracked"):
        assert key in data, f"Missing key in weekly trends: {key}"
    assert isinstance(data["dailyBreakdowns"], list)
    assert isinstance(data["chronicDeficiencies"], list)


@pytest.mark.aggregate
@pytest.mark.ai
def test_nutrient_recommendations_returns_three_lists(
    base_url: str, auth_headers: dict
) -> None:
    """POST /nutrient/recommendations must return the three insight lists."""
    r = requests.post(f"{base_url}/nutrient/recommendations", headers=auth_headers)
    assert r.status_code == 200, f"Nutrient recommendations failed: {r.text}"
    data = r.json()
    for key in ("deficiencyInsights", "foodRecommendations", "supplementSuggestions"):
        assert key in data, f"Missing key in recommendations: {key}"
        assert isinstance(data[key], list), f"{key} must be a list"

"""
Offline tests for the nutrient router endpoints.
Uses FastAPI TestClient — no network, no Gemini called.

The GEMINI_API_KEY is set to a dummy value before import.
When Gemini is called with an invalid key the service catches the
exception and returns a fallback response — that is exactly what
these tests validate (the degraded-mode contract).
"""
import os
import sys

# Must be set before app import so GeminiClient.__init__ doesn't raise ValueError
os.environ.setdefault("GEMINI_API_KEY", "test-key-offline-nutrient")

# Add ai-service root to path so `from app.main import app` works
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


# ── /food/analyze-nutrients ──────────────────────────────────────────────────

def test_analyze_nutrients_text_description_returns_structure() -> None:
    """Text-only food analysis must return a structured FoodAnalysisResponse."""
    r = client.post("/food/analyze-nutrients", json={
        "description": "A bowl of oatmeal with banana and honey",
        "user_context": {
            "region": "India",
            "cuisine_style": "mixed",
        },
    })
    assert r.status_code == 200, f"Unexpected status: {r.status_code} — {r.text}"
    data = r.json()
    assert "foods" in data, "Missing 'foods' key"
    assert "nutrients" in data, "Missing 'nutrients' key"
    assert isinstance(data["foods"], list)


def test_analyze_nutrients_empty_description_returns_structure() -> None:
    """Minimal request (no description, no image) should return a response, not 500."""
    r = client.post("/food/analyze-nutrients", json={
        "description": "",
        "user_context": {},
    })
    # May return 400 or 200 with empty data — either is acceptable
    assert r.status_code in (200, 400, 422), (
        f"Unexpected status: {r.status_code} — {r.text}"
    )


def test_analyze_nutrients_missing_body_returns_422() -> None:
    """Completely missing request body must return 422 (FastAPI validation)."""
    r = client.post("/food/analyze-nutrients")
    assert r.status_code == 422, f"Expected 422, got {r.status_code}"


# ── /nutrient/recommendations ────────────────────────────────────────────────

def test_nutrient_recommendations_empty_profile() -> None:
    """Empty deficiency profile must return the three result lists (may be empty)."""
    r = client.post("/nutrient/recommendations", json={
        "deficiency_profile": [],
        "user_context": {
            "region": "India",
            "cuisine_style": "south_indian",
            "dietary_restrictions": "vegetarian",
            "gender": "male",
            "age": "30",
        },
    })
    assert r.status_code == 200, f"Unexpected status: {r.status_code} — {r.text}"
    data = r.json()
    for key in ("deficiency_insights", "food_recommendations", "supplement_suggestions"):
        assert key in data, f"Missing key: {key}"
        assert isinstance(data[key], list), f"{key} must be a list"


def test_nutrient_recommendations_with_iron_deficiency() -> None:
    """Non-empty deficiency profile must produce a valid response (fallback or real)."""
    r = client.post("/nutrient/recommendations", json={
        "deficiency_profile": [
            {
                "nutrient": "Iron",
                "days_deficient": 10,
                "avg_percent_rda": 40.0,
            }
        ],
        "user_context": {
            "region": "Bihar, India",
            "cuisine_style": "north_indian",
            "dietary_restrictions": "vegetarian",
            "gender": "female",
            "age": "25",
        },
    })
    assert r.status_code == 200, f"Unexpected status: {r.status_code} — {r.text}"
    data = r.json()
    for key in ("deficiency_insights", "food_recommendations", "supplement_suggestions"):
        assert key in data


def test_nutrient_recommendations_missing_body_returns_422() -> None:
    """Missing request body must return 422."""
    r = client.post("/nutrient/recommendations")
    assert r.status_code == 422, f"Expected 422, got {r.status_code}"

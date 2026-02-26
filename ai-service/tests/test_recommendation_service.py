import pytest
from app.services.recommendation_service import RecommendationService

def test_fallback_analysis():
    service = RecommendationService()
    summary = {
        "risk_flags": ["Protein deficit"],
        "nutrition_summary": {"last_7_days": {"avg_calories": 1000}},
        "training_summary": {"workout_frequency": {"last_30_days": 1}}
    }
    response = service._fallback_analysis(summary)
    assert any("protein" in s.lower() for s in response.dietSuggestions)
    assert any("calorie" in s.lower() for s in response.medicalAwarenessNotes)

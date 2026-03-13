from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_analyze_health_offline():
    # Mocking a request that should trigger fallback or simple advice if key is missing
    payload = {
        "summary": {
            "risk_flags": ["Protein deficit"],
            "nutrition_summary": {"last_7_days": {"avg_calories": 2000}},
            "training_summary": {"workout_frequency": {"last_30_days": 1}},
        }
    }
    response = client.post("/analyze-health", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "dietSuggestions" in data
    assert "trainingSuggestions" in data

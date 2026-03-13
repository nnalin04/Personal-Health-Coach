"""
Offline tests for the metric extraction endpoint.
Uses FastAPI TestClient — no network, no Gemini called.
"""
import os
import sys

os.environ.setdefault("GEMINI_API_KEY", "test-key-offline-metrics")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_extract_metrics_with_health_text_returns_structure() -> None:
    """POST /extract-metrics with health text must return extractedText."""
    r = client.post("/extract-metrics", json={
        "text": (
            "Patient had blood sugar 110 mg/dL. "
            "Weight is 75 kg. Heart rate 72 bpm. "
            "Blood pressure 120/80 mmHg."
        ),
    })
    assert r.status_code == 200, f"extract-metrics failed: {r.status_code} {r.text}"
    data = r.json()
    assert "raw_text" in data, "Missing 'raw_text' key"
    assert "metrics" in data, "Missing 'metrics' key"
    assert isinstance(data["metrics"], list)


def test_extract_metrics_with_empty_text() -> None:
    """Empty text must not crash — should return empty metrics list."""
    r = client.post("/extract-metrics", json={"text": ""})
    assert r.status_code == 200, f"Empty text failed: {r.status_code} {r.text}"
    data = r.json()
    assert "raw_text" in data
    assert isinstance(data["metrics"], list)


def test_extract_metrics_missing_body_returns_422() -> None:
    """Missing request body must return 422."""
    r = client.post("/extract-metrics")
    assert r.status_code == 422, f"Expected 422, got {r.status_code}"


def test_extract_metrics_non_health_text() -> None:
    """Non-health text should still return 200 (AI gracefully handles irrelevant input)."""
    r = client.post("/extract-metrics", json={
        "text": "The weather today is sunny with mild winds.",
    })
    assert r.status_code == 200, f"Non-health text failed: {r.status_code} {r.text}"
    data = r.json()
    assert "raw_text" in data

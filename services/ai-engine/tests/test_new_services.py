"""
Tests for Phase 3b-5 new services:
  - gcs_helper (GCS download utility)
  - medical_parser_service (Gemini-based lab report OCR)
  - receipt_parser_service (quick-commerce receipt parser)
  - smart_router REPORT / RECEIPT branches
"""
import base64
import json
from unittest.mock import MagicMock, patch

# ── gcs_helper ────────────────────────────────────────────────────────────────

import app.utils.gcs_helper as gcs_mod


def test_gcs_helper_returns_none_for_non_gcs_uri():
    assert gcs_mod.download_gcs_bytes("https://example.com/file.jpg") is None


def test_gcs_helper_returns_none_for_none():
    assert gcs_mod.download_gcs_bytes(None) is None


def test_gcs_helper_returns_none_when_library_absent(monkeypatch):
    """Simulate google-cloud-storage not installed."""
    import builtins
    real_import = builtins.__import__

    def mock_import(name, *args, **kwargs):
        if name == "google.cloud.storage" or (name == "google.cloud" and args and "storage" in str(args)):
            raise ImportError("No module named 'google.cloud.storage'")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", mock_import)
    result = gcs_mod.download_gcs_bytes("gs://bucket/file.jpg")
    assert result is None


def test_resolve_payload_base64_path():
    b64 = base64.b64encode(b"fake-image-bytes").decode()
    data, source = gcs_mod.resolve_payload(b64)
    assert source == "base64"
    assert data is None   # base64 path returns None; caller decodes it


def test_resolve_payload_empty():
    data, source = gcs_mod.resolve_payload(None)
    assert source == "empty"
    assert data is None


def test_resolve_payload_gcs_calls_download():
    with patch.object(gcs_mod, "download_gcs_bytes", return_value=b"bytes") as mock_dl:
        data, source = gcs_mod.resolve_payload("gs://my-bucket/food/1/abc.jpg")
        mock_dl.assert_called_once_with("gs://my-bucket/food/1/abc.jpg")
        assert source == "gcs"
        assert data == b"bytes"


# ── medical_parser_service ────────────────────────────────────────────────────

import app.services.medical_parser_service as med_mod


def _mock_gemini_medical(response_json: dict):
    mock_response = MagicMock()
    mock_response.text = json.dumps(response_json)
    mock_model = MagicMock()
    mock_model.generate_content.return_value = mock_response
    return mock_model


def test_medical_parser_returns_fallback_when_no_data():
    result = med_mod.parse_medical_report(file_data=None, file_b64=None)
    assert result["parsed"] is False
    assert result["labValues"] == []
    assert result["confidence"] == 0.0


def test_medical_parser_success_with_bytes():
    mock_model = _mock_gemini_medical({
        "patient_name": "Test User",
        "report_date": "2026-03-14",
        "lab_values": [
            {"test_name": "Haemoglobin", "value": 10.5, "unit": "g/dL",
             "reference_range": "12-17.5", "status": "LOW"}
        ],
        "summary": "Haemoglobin is below normal range.",
        "flags": ["Haemoglobin LOW"],
        "confidence": 0.9,
    })
    with patch("app.services.medical_parser_service.genai") as mock_genai:
        mock_genai.GenerativeModel.return_value = mock_model
        result = med_mod.parse_medical_report(
            file_data=b"fake-pdf-bytes",
            file_b64=None,
            user_context={"region": "India"},
        )
    assert result["parsed"] is True
    assert result["patientName"] == "Test User"
    assert len(result["labValues"]) == 1
    assert result["labValues"][0]["status"] == "LOW"
    assert len(result["dietaryRecommendations"]) > 0


def test_medical_parser_success_with_b64():
    mock_model = _mock_gemini_medical({
        "lab_values": [],
        "summary": "Normal report.",
        "flags": [],
        "confidence": 0.8,
    })
    pdf_b64 = base64.b64encode(b"fake-pdf").decode()
    with patch("app.services.medical_parser_service.genai") as mock_genai:
        mock_genai.GenerativeModel.return_value = mock_model
        result = med_mod.parse_medical_report(file_data=None, file_b64=pdf_b64)
    assert result["parsed"] is True
    assert result["summary"] == "Normal report."


def test_medical_parser_json_error_returns_fallback():
    mock_model = MagicMock()
    mock_model.generate_content.return_value = MagicMock(text="not valid json {{{")
    with patch("app.services.medical_parser_service.genai") as mock_genai:
        mock_genai.GenerativeModel.return_value = mock_model
        result = med_mod.parse_medical_report(file_data=b"bytes", file_b64=None)
    assert result["parsed"] is False


def test_medical_recommendations_iron_deficiency():
    recs = med_mod._build_recommendations(
        flags=["Haemoglobin LOW"],
        lab_values=[{"test_name": "Haemoglobin", "value": 10, "unit": "g/dL", "status": "LOW"}],
        user_context={"region": "India"},
    )
    assert any("iron" in r.lower() or "rajma" in r.lower() for r in recs)


def test_medical_recommendations_high_glucose():
    recs = med_mod._build_recommendations(
        flags=["Glucose HIGH"],
        lab_values=[{"test_name": "Glucose", "value": 200, "unit": "mg/dL", "status": "HIGH"}],
        user_context={},
    )
    assert any("sugar" in r.lower() or "carb" in r.lower() for r in recs)


# ── receipt_parser_service ────────────────────────────────────────────────────

import app.services.receipt_parser_service as rcpt_mod


def _mock_gemini_receipt(response_json: dict):
    mock_response = MagicMock()
    mock_response.text = json.dumps(response_json)
    mock_model = MagicMock()
    mock_model.generate_content.return_value = mock_response
    return mock_model


def test_receipt_parser_fallback_when_no_data():
    result = rcpt_mod.parse_receipt(file_data=None, file_b64=None)
    assert result["parsed"] is False
    assert result["items"] == []


def test_receipt_parser_success():
    mock_model = _mock_gemini_receipt({
        "platform": "Blinkit",
        "order_date": "2026-03-14",
        "items": [
            {"name": "Amul Milk", "quantity_g": 500, "quantity_unit": "ml",
             "calories": 325, "protein_g": 16.5, "carbs_g": 24.0, "fats_g": 17.5,
             "confidence": 0.95},
        ],
        "total_calories": 325,
        "note": "High confidence scan",
    })
    with patch("app.services.receipt_parser_service.genai") as mock_genai:
        mock_genai.GenerativeModel.return_value = mock_model
        result = rcpt_mod.parse_receipt(
            file_data=b"fake-receipt-bytes",
            file_b64=None,
            description="Blinkit order",
        )
    assert result["parsed"] is True
    assert result["platform"] == "Blinkit"
    assert len(result["items"]) == 1
    assert result["items"][0]["name"] == "Amul Milk"
    assert result["totalCalories"] == 325
    assert "Log All" in result["message"]


def test_receipt_parser_json_error_returns_fallback():
    mock_model = MagicMock()
    mock_model.generate_content.return_value = MagicMock(text="{ bad json")
    with patch("app.services.receipt_parser_service.genai") as mock_genai:
        mock_genai.GenerativeModel.return_value = mock_model
        result = rcpt_mod.parse_receipt(file_data=b"bytes", file_b64=None)
    assert result["parsed"] is False


def test_receipt_parser_computes_total_when_missing():
    mock_model = _mock_gemini_receipt({
        "platform": "Instamart",
        "items": [
            {"name": "Rice 1kg", "quantity_g": 1000, "quantity_unit": "g",
             "calories": 3600, "protein_g": 70, "carbs_g": 790, "fats_g": 5,
             "confidence": 0.9},
            {"name": "Toor Dal 500g", "quantity_g": 500, "quantity_unit": "g",
             "calories": 1700, "protein_g": 120, "carbs_g": 300, "fats_g": 10,
             "confidence": 0.88},
        ],
        # total_calories intentionally absent → should be computed
    })
    with patch("app.services.receipt_parser_service.genai") as mock_genai:
        mock_genai.GenerativeModel.return_value = mock_model
        result = rcpt_mod.parse_receipt(file_data=b"bytes", file_b64=None)
    assert result["parsed"] is True
    assert result["totalCalories"] == 3600 + 1700

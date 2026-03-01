"""
Offline tests for the medical report parser.
Tests both the FastAPI router and the regex extraction utility directly.
"""
import os
import sys
import base64

os.environ.setdefault("GEMINI_API_KEY", "test-key-offline-medical")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient
from app.main import app
from app.services.report_parser_service import _extract_metric

client = TestClient(app)


# ── Unit tests for _extract_metric regex utility ─────────────────────────────

def test_extract_metric_finds_vitamin_d() -> None:
    """Vitamin D extraction with plain label."""
    text = "Vitamin D: 22.5 ng/mL"
    result = _extract_metric(text, [r"vitamin\s*d", r"25[-\s]?oh\s*vitamin\s*d"])
    assert result == 22.5, f"Expected 22.5, got {result}"


def test_extract_metric_finds_hemoglobin() -> None:
    """Haemoglobin / hemoglobin variants."""
    text = "Hemoglobin 14.2 g/dL"
    result = _extract_metric(text, [r"hemoglobin", r"haemoglobin"])
    assert result == 14.2, f"Expected 14.2, got {result}"


def test_extract_metric_returns_none_when_absent() -> None:
    """Returns None when the label is not present in the text."""
    text = "Patient: John Doe. Blood pressure: 120/80."
    result = _extract_metric(text, [r"vitamin\s*d"])
    assert result is None


def test_extract_metric_returns_none_for_empty_text() -> None:
    """Returns None for empty string."""
    result = _extract_metric("", [r"glucose"])
    assert result is None


def test_extract_metric_tsh_case_insensitive() -> None:
    """TSH extraction is case-insensitive."""
    text = "TSH: 2.1 mIU/L"
    result = _extract_metric(text, [r"\btsh\b", r"thyroid\s*stimulating\s*hormone"])
    assert result == 2.1, f"Expected 2.1, got {result}"


# ── /parse-medical-report router tests ──────────────────────────────────────

def _minimal_pdf_base64() -> str:
    """Returns base64-encoded minimal PDF for upload tests."""
    pdf = (
        b"%PDF-1.4\n1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
        b"2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"
        b"3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"
        b"xref\n0 4\n0000000000 65535 f \n"
        b"trailer\n<</Size 4 /Root 1 0 R>>\nstartxref\n0\n%%EOF"
    )
    return base64.b64encode(pdf).decode()


def test_parse_medical_report_with_base64_pdf() -> None:
    """POST /parse-medical-report with base64 PDF must return labValues and notes."""
    r = client.post("/parse-medical-report", json={
        "file_name": "report.pdf",
        "file_base64": _minimal_pdf_base64(),
        "extracted_text": (
            "Vitamin D: 22.5 ng/mL\n"
            "TSH: 2.1 mIU/L\n"
            "Hemoglobin: 14.2 g/dL\n"
            "Glucose: 92 mg/dL"
        ),
    })
    assert r.status_code == 200, f"parse-medical-report failed: {r.status_code} {r.text}"
    data = r.json()
    assert "labValues" in data, "Missing labValues"
    assert "extractionNotes" in data, "Missing extractionNotes"
    assert isinstance(data["extractionNotes"], list)
    # Regex fallback should extract at least vitamin_d
    labs = data["labValues"]
    assert labs.get("vitamin_d") == 22.5, f"vitamin_d mismatch: {labs}"


def test_parse_medical_report_empty_text_returns_empty_labs() -> None:
    """Sending no text and an empty PDF should return empty labs gracefully."""
    r = client.post("/parse-medical-report", json={
        "file_name": "empty.pdf",
        "file_base64": _minimal_pdf_base64(),
        "extracted_text": "",
    })
    assert r.status_code == 200, f"Unexpected status: {r.status_code} {r.text}"
    data = r.json()
    assert "labValues" in data


def test_parse_medical_report_missing_body_returns_422() -> None:
    """Missing body must return 422."""
    r = client.post("/parse-medical-report")
    assert r.status_code == 422

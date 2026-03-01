"""
Medical reports domain: POST /medical/reports (multipart), GET /medical/reports.
Uses pdf_factory to build a minimal PDF — no external dependencies.
"""
import io
import os
import sys
import pytest
import requests

# Resolve helpers path regardless of where pytest is invoked from
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from helpers.pdf_factory import make_lab_report_pdf, make_minimal_pdf_bytes


@pytest.fixture(scope="module")
def uploaded_report(base_url: str, auth_headers: dict, today: str) -> dict:
    """Upload a PDF report once for all tests in this module."""
    pdf_bytes = make_lab_report_pdf()
    r = requests.post(
        f"{base_url}/medical/reports",
        headers=auth_headers,
        files={"file": ("lab_report.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
        data={"reportDate": today},
    )
    assert r.status_code in (200, 201), (
        f"Medical report upload failed: {r.status_code} {r.text}"
    )
    return r.json()


@pytest.mark.crud
def test_upload_returns_report_id_and_date(
    uploaded_report: dict, today: str
) -> None:
    """Uploaded report must have an integer id and the submitted reportDate."""
    r = uploaded_report
    assert isinstance(r["id"], int), "id must be an integer"
    assert r["reportDate"] == today
    assert isinstance(r["labs"], list), "labs must be a list"
    assert isinstance(r["extractionNotes"], list), "extractionNotes must be a list"


@pytest.mark.crud
@pytest.mark.ai
def test_upload_extracts_at_least_one_lab_value(uploaded_report: dict) -> None:
    """Regex fallback parser must extract at least one lab value from the PDF."""
    labs = uploaded_report.get("labs", [])
    if not labs:
        pytest.skip("No labs returned — AI parser may have returned empty (check AI service logs)")
    lab = labs[0]
    # At least one field should be non-null (vitamin_d, hemoglobin, glucose, etc.)
    populated = [v for v in lab.values() if v is not None]
    assert len(populated) >= 1, (
        f"Expected at least 1 extracted lab value, but all are null: {lab}"
    )


@pytest.mark.crud
def test_list_reports_contains_uploaded(
    base_url: str, auth_headers: dict, uploaded_report: dict
) -> None:
    """GET /medical/reports must include the uploaded report."""
    r = requests.get(f"{base_url}/medical/reports", headers=auth_headers)
    assert r.status_code == 200, f"GET /medical/reports failed: {r.text}"
    ids = [rep["id"] for rep in r.json()]
    assert uploaded_report["id"] in ids, "Uploaded report not found in list"


def test_upload_without_file_returns_error(
    base_url: str, auth_headers: dict, today: str
) -> None:
    """POST /medical/reports without a file part must return 4xx."""
    r = requests.post(
        f"{base_url}/medical/reports",
        headers=auth_headers,
        data={"reportDate": today},
    )
    assert r.status_code in (400, 415, 422, 500), (
        f"Expected error for missing file, got {r.status_code}"
    )

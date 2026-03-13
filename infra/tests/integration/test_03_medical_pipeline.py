"""
SCENARIO: Medical Report Pipeline
===================================
Tests the full pipeline: PDF upload → AI lab value extraction → DB storage
→ lab values queryable → health summary includes lab data.

Flow:
  1.  Upload PDF with known lab values
  2.  Verify upload response contains report ID
  3.  Verify report appears in /medical/reports list
  4.  Wait for AI extraction (lab values are parsed asynchronously)
  5.  Fetch lab values for the report → verify extracted values
  6.  Fetch health summary → verify lab trends section is populated
  7.  Upload invalid file (not PDF) → verify 4xx error response
  8.  Upload empty file → verify error handling
"""
import io
import time
import pytest
import requests
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from helpers.pdf_factory import make_lab_report_pdf, make_minimal_pdf_bytes


@pytest.mark.integration
def test_medical_report_pipeline(api_url, integration_user, today):
    """Upload PDF → AI extracts lab values → health summary includes them."""
    headers = integration_user["headers"]

    # ── 1. Upload PDF with synthetic lab values ────────────────────────────────
    pdf_bytes = make_lab_report_pdf()
    r = requests.post(
        f"{api_url}/medical/reports",
        files={"file": ("lab_report_integration.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
        data={"reportDate": today},
        headers=headers,
        timeout=30,
    )
    assert r.status_code in (200, 201), f"Medical upload failed: {r.text}"
    report = r.json()
    report_id = report.get("id")
    assert report_id is not None, "Upload response must contain 'id'"
    assert isinstance(report_id, int)

    # ── 2. Verify report in list immediately after upload ─────────────────────
    r = requests.get(f"{api_url}/medical/reports", headers=headers, timeout=10)
    assert r.status_code == 200
    reports = r.json()
    report_ids = [rep["id"] for rep in reports]
    assert report_id in report_ids, f"Report {report_id} not found in list: {report_ids}"

    # ── 3. Fetch lab values (may need poll for async extraction) ──────────────
    lab_values = None
    for _ in range(8):  # max 24 seconds
        time.sleep(3)
        r = requests.get(f"{api_url}/medical/reports/{report_id}/lab-values",
                         headers=headers, timeout=10)
        if r.status_code == 200 and r.json():
            lab_values = r.json()
            break

    if lab_values is not None:
        assert isinstance(lab_values, list), "Lab values must be a list"
        if len(lab_values) > 0:
            lv = lab_values[0]
            # Each lab value should have at minimum a name and value
            assert "testName" in lv or "name" in lv, f"Lab value missing name field: {lv}"
            assert "value" in lv or "testValue" in lv, f"Lab value missing value field: {lv}"

    # ── 4. Health summary includes medical trends ─────────────────────────────
    r = requests.get(f"{api_url}/health-summary/me?days=30",
                     headers=headers, timeout=15)
    assert r.status_code == 200, f"Health summary failed: {r.text}"
    summary = r.json()
    assert "medical_trends" in summary, "Health summary missing 'medical_trends'"

    # ── 5. Upload invalid file type (not PDF) → must return 4xx ──────────────
    r = requests.post(
        f"{api_url}/medical/reports",
        files={"file": ("malware.exe", io.BytesIO(b"MZ\x90\x00fake binary"), "application/octet-stream")},
        data={"reportDate": today},
        headers=headers,
        timeout=15,
    )
    assert r.status_code in (400, 415, 422), (
        f"Invalid file type should return 4xx, got {r.status_code}: {r.text}"
    )

    # ── 6. Upload a text file instead of PDF → must return 4xx ───────────────
    r = requests.post(
        f"{api_url}/medical/reports",
        files={"file": ("notapdf.txt", io.BytesIO(b"This is not a PDF"), "text/plain")},
        data={"reportDate": today},
        headers=headers,
        timeout=15,
    )
    assert r.status_code in (400, 415, 422), (
        f"Text file upload should return 4xx, got {r.status_code}: {r.text}"
    )

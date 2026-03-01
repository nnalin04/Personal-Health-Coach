"""
Builds minimal valid PDF bytes for medical report upload tests.
Uses only stdlib — no pip dependency.

The generated PDF is PDF-1.4 conforming and readable by pypdf.
"""


def make_minimal_pdf_bytes(text: str = "") -> bytes:
    """
    Returns a valid PDF-1.4 document containing `text` in a single page.
    Safe to submit to the /api/medical/reports multipart endpoint.
    """
    # Encode content stream
    content = f"BT /F1 12 Tf 72 720 Td ({text}) Tj ET".encode("latin-1", errors="replace")
    content_len = len(content)

    pdf = (
        b"%PDF-1.4\n"
        b"1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
        b"2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"
        b"3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]"
        b" /Contents 4 0 R /Resources <</Font <</F1 <</Type /Font"
        b" /Subtype /Type1 /BaseFont /Helvetica>>>>>>>>\nendobj\n"
        b"4 0 obj\n<</Length " + str(content_len).encode() + b">>\n"
        b"stream\n" + content + b"\nendstream\nendobj\n"
        b"xref\n0 5\n"
        b"0000000000 65535 f \n"
        b"0000000009 00000 n \n"
        b"0000000058 00000 n \n"
        b"0000000115 00000 n \n"
        b"0000000302 00000 n \n"
        b"trailer\n<</Size 5 /Root 1 0 R>>\n"
        b"startxref\n420\n%%EOF"
    )
    return pdf


def make_lab_report_pdf() -> bytes:
    """
    Returns a PDF with synthetic lab values that the regex fallback parser
    in ReportParserService._regex_parse can extract.
    """
    lab_text = (
        "Lab Report 2026-01-15  "
        "Vitamin D: 22.5 ng/mL  "
        "TSH: 2.1 mIU/L  "
        "LDL Cholesterol: 110 mg/dL  "
        "HDL Cholesterol: 55 mg/dL  "
        "Hemoglobin: 14.2 g/dL  "
        "Glucose: 92 mg/dL  "
        "Creatinine: 0.9 mg/dL"
    )
    return make_minimal_pdf_bytes(lab_text)

"""
Medical PDF parser — uses Gemini Vision to extract structured lab values
from a medical report image or PDF.

Triggered by the REPORT branch in smart_router when a PDF is uploaded
via OmniChat. Supports:
  - CBC (Complete Blood Count): Hb, WBC, platelets, RBC
  - Metabolic: glucose, HbA1c, creatinine, urea, uric acid
  - Lipid panel: total cholesterol, LDL, HDL, triglycerides
  - Thyroid: TSH, T3, T4
  - Vitamins/minerals: B12, D3, iron, ferritin, calcium
  - Liver: ALT, AST, bilirubin, ALP

Input can be:
  - bytes (PDF or image)  — passed as inline Gemini Part
  - base64 string         — decoded to bytes first

Output: dict with labValues, summary, recommendations, confidence
"""
import base64
import logging
from typing import Optional

from app.ai.gemini_client import GeminiClient, GeminiError
from app.ai.base_client import BaseAIClient
from app.ai.paddleocr_client import PaddleOCRClient

logger = logging.getLogger(__name__)

_EXTRACTION_SYSTEM = """You are a clinical lab report analyst.
Extract ALL numerical lab values from the provided medical report.
For each value, record: name, value (number), unit, reference_range, status (LOW/NORMAL/HIGH/CRITICAL).
Return ONLY valid JSON — no markdown, no extra text."""

_EXTRACTION_PROMPT = """Extract every lab value from this medical report.

Return JSON in EXACTLY this format:
{
  "patient_name": "string or null",
  "report_date": "YYYY-MM-DD or null",
  "lab_values": [
    {
      "test_name": "Haemoglobin",
      "value": 11.2,
      "unit": "g/dL",
      "reference_range": "12.0-17.5",
      "status": "LOW"
    }
  ],
  "summary": "One paragraph plain-English summary of key findings",
  "flags": ["list of any critical or out-of-range results"],
  "confidence": 0.9
}

status must be one of: LOW, NORMAL, HIGH, CRITICAL
If a field cannot be determined, use null."""


class MedicalParserService:
    def __init__(self) -> None:
        # temperature=0.1 — deterministic extraction for medical data
        self._client = GeminiClient()
        self._ocr = PaddleOCRClient()

    def parse_report(
        self,
        file_data: bytes | None,
        file_b64: str | None,
        mime_type: str = "application/pdf",
        user_context: dict | None = None,
        client: BaseAIClient | None = None,
    ) -> dict:
        """
        Parse a medical report and return structured lab values.

        :param file_data:    Raw bytes of the PDF/image (takes priority over b64)
        :param file_b64:     Base64-encoded file as fallback
        :param mime_type:    MIME type of the document
        :param user_context: User preferences (used for personalised recommendations)
        :returns:            Structured dict with labValues, summary, recommendations
        """
        raw_bytes: Optional[bytes] = None
        if file_data:
            raw_bytes = file_data
        elif file_b64:
            try:
                raw_bytes = base64.b64decode(file_b64)
            except Exception:
                pass

        if raw_bytes is None:
            return _fallback("No file data received")

        active_client = client or self._client

        try:
            # OCR pre-pass: extract text locally to cut LLM token cost ~80%
            extracted_text = self._ocr.extract_text(raw_bytes, mime_type)

            if extracted_text is not None:
                # Text-only call — much cheaper than vision inference
                logger.info(
                    "OCR pre-pass succeeded (%d chars) — using text-only LLM call",
                    len(extracted_text),
                )
                result = active_client.generate_json(
                    _EXTRACTION_SYSTEM,
                    f"{_EXTRACTION_PROMPT}\n\nExtracted report text:\n{extracted_text}",
                    contents=None,
                    temperature=0.1,
                )
            else:
                # OCR unavailable or failed — fall through to vision path
                logger.info("OCR pre-pass returned None — using vision LLM call")
                file_part = {"mime_type": mime_type, "data": raw_bytes}
                result = active_client.generate_json(
                    _EXTRACTION_SYSTEM,
                    _EXTRACTION_PROMPT,
                    contents=[file_part],
                    temperature=0.1,
                )

            flags = result.get("flags", [])
            recommendations = _build_recommendations(
                result.get("lab_values", []), user_context
            )
            result["dietary_recommendations"] = recommendations

            return {
                "parsed": True,
                "patientName":            result.get("patient_name"),
                "reportDate":             result.get("report_date"),
                "labValues":              result.get("lab_values", []),
                "summary":                result.get("summary", ""),
                "flags":                  flags,
                "dietaryRecommendations": recommendations,
                "confidence":             result.get("confidence", 0.7),
            }

        except Exception as e:
            logger.error("Medical parser error: %s", e, exc_info=True)
            return _fallback(str(e))


# ── module-level convenience wrapper (preserves existing call sites) ──────────

_service: Optional[MedicalParserService] = None


def parse_medical_report(
    file_data: bytes | None,
    file_b64: str | None,
    mime_type: str = "application/pdf",
    user_context: dict | None = None,
    client: "BaseAIClient | None" = None,
) -> dict:
    """Module-level wrapper — lazily creates a shared MedicalParserService."""
    global _service
    if _service is None:
        _service = MedicalParserService()
    return _service.parse_report(file_data, file_b64, mime_type, user_context, client)


# ── helpers ───────────────────────────────────────────────────────────────────

def _build_recommendations(lab_values: list, user_context: dict | None) -> list[str]:
    """Generate simple dietary recommendations based on flagged values."""
    recs: list[str] = []
    region = (user_context or {}).get("region", "India")

    low_tests = {v["test_name"].lower() for v in lab_values if v.get("status") == "LOW"}
    high_tests = {v["test_name"].lower() for v in lab_values if v.get("status") in ("HIGH", "CRITICAL")}

    if any(k in low_tests for k in ("haemoglobin", "hemoglobin", "iron", "ferritin")):
        if region.lower() in ("india", "south asia"):
            recs.append("Increase iron: spinach, rajma, horse gram, jaggery, sesame seeds")
        else:
            recs.append("Increase dietary iron: leafy greens, legumes, lean red meat")

    if any(k in low_tests for k in ("vitamin b12", "b12", "cobalamin")):
        recs.append("B12 is low — consider fortified dairy, eggs, or consult doctor about supplementation")

    if any(k in low_tests for k in ("vitamin d", "25-oh vitamin d", "25-hydroxyvitamin d")):
        recs.append("Vitamin D is low — aim for 15 min morning sun daily; add fortified milk or eggs")

    if any(k in high_tests for k in ("glucose", "hba1c", "fasting blood sugar")):
        recs.append("Blood sugar is elevated — reduce refined carbs, increase fibre, eat smaller frequent meals")

    if any(k in high_tests for k in ("ldl", "total cholesterol", "triglycerides")):
        recs.append("Lipid levels high — reduce saturated fat; add oats, flaxseeds, omega-3 rich fish")

    if not recs:
        recs.append("Lab values look broadly normal — maintain a balanced diet and schedule routine follow-up")

    return recs


def _fallback(reason: str) -> dict:
    return {
        "parsed":       False,
        "labValues":    [],
        "summary":      "Could not extract lab values from this document.",
        "flags":        [],
        "error":        reason,
        "confidence":   0.0,
        "dietaryRecommendations": [
            "Please upload a clearer image or typed PDF of your lab report."
        ],
    }

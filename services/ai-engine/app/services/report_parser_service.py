import json
import logging
import re
from app.ai.gemini_client import GeminiClient
from app.schemas.medical import ParsedLabValues, ParseMedicalReportResponse
from app.utils.text_extract import decode_base64_to_text

logger = logging.getLogger(__name__)


class ReportParserService:
    def __init__(self) -> None:
        self.gemini_client = GeminiClient()

    def parse(self, file_name: str | None, file_base64: str | None, extracted_text: str | None) -> ParseMedicalReportResponse:
        notes: list[str] = []
        report_text = (extracted_text or "").strip()

        # If it's a vision-supported file (image), try vision first
        is_image = file_name and file_name.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
        if is_image and file_base64:
            try:
                parsed = self._vision_parse(file_base64, file_name)
                notes.append("Lab values extracted with Gemini Vision")
                return ParseMedicalReportResponse(labValues=parsed, extractionNotes=notes)
            except Exception as e:
                notes.append(f"Vision parsing failed: {str(e)}")

        if not report_text and file_base64:
            report_text = decode_base64_to_text(file_base64, file_name)
            notes.append("Report text extracted from uploaded file")

        if not report_text:
            notes.append("No text content available for parsing")
            return ParseMedicalReportResponse(labValues=ParsedLabValues(), extractionNotes=notes)

        try:
            parsed = self._gemini_parse(report_text)
            notes.append("Lab values extracted with LLM")
            return ParseMedicalReportResponse(labValues=parsed, extractionNotes=notes)
        except Exception:
            logger.exception("Gemini medical report parsing failed — using regex fallback")
            parsed = self._regex_parse(report_text)
            notes.append("Fallback parser used (regex)")
            return ParseMedicalReportResponse(labValues=parsed, extractionNotes=notes)

    def _vision_parse(self, file_base64: str, file_name: str) -> ParsedLabValues:
        mime_type = "image/jpeg"
        if file_name.lower().endswith(".png"): mime_type = "image/png"
        elif file_name.lower().endswith(".webp"): mime_type = "image/webp"

        image_data = {
            "mime_type": mime_type,
            "data": file_base64
        }
        
        system_prompt = "You are a medical data extraction expert. Extract lab values from this report image. Return strict JSON with numeric or null values only."
        user_prompt = "Extract: vitamin_d, tsh, ldl, hdl, triglycerides, hba1c, creatinine, hemoglobin, alt, ast, glucose, testosterone."
        
        out = self.gemini_client.generate_json(system_prompt, user_prompt, contents=[image_data])
        return ParsedLabValues(
            vitamin_d=_as_float(out.get("vitamin_d")),
            tsh=_as_float(out.get("tsh")),
            ldl=_as_float(out.get("ldl")),
            hdl=_as_float(out.get("hdl")),
            triglycerides=_as_float(out.get("triglycerides")),
            hba1c=_as_float(out.get("hba1c")),
            creatinine=_as_float(out.get("creatinine")),
            hemoglobin=_as_float(out.get("hemoglobin")),
            alt=_as_float(out.get("alt")),
            ast=_as_float(out.get("ast")),
            glucose=_as_float(out.get("glucose")),
            testosterone=_as_float(out.get("testosterone")),
        )

    def _gemini_parse(self, report_text: str) -> ParsedLabValues:
        system_prompt = "Extract lab values from medical text. Return strict JSON with numeric or null values only."
        user_prompt = (
            "Extract these keys if present: vitamin_d, tsh, ldl, hdl, triglycerides, hba1c, creatinine, hemoglobin, alt, ast, glucose, testosterone.\n"
            "Text:\n" + report_text[:15000]
        )
        out = self.gemini_client.generate_json(system_prompt, user_prompt)
        return ParsedLabValues(
            vitamin_d=_as_float(out.get("vitamin_d")),
            tsh=_as_float(out.get("tsh")),
            ldl=_as_float(out.get("ldl")),
            hdl=_as_float(out.get("hdl")),
            triglycerides=_as_float(out.get("triglycerides")),
            hba1c=_as_float(out.get("hba1c")),
            creatinine=_as_float(out.get("creatinine")),
            hemoglobin=_as_float(out.get("hemoglobin")),
            alt=_as_float(out.get("alt")),
            ast=_as_float(out.get("ast")),
            glucose=_as_float(out.get("glucose")),
            testosterone=_as_float(out.get("testosterone")),
        )

    def _regex_parse(self, report_text: str) -> ParsedLabValues:
        return ParsedLabValues(
            vitamin_d=_extract_metric(report_text, [r"vitamin\s*d", r"25[-\s]?oh\s*vitamin\s*d"]),
            tsh=_extract_metric(report_text, [r"\btsh\b", r"thyroid\s*stimulating\s*hormone"]),
            ldl=_extract_metric(report_text, [r"\bldl\b", r"ldl\s*cholesterol"]),
            hdl=_extract_metric(report_text, [r"\bhdl\b", r"hdl\s*cholesterol"]),
            triglycerides=_extract_metric(report_text, [r"triglycerides?"]),
            hba1c=_extract_metric(report_text, [r"hba1c", r"glycated\s*hemoglobin", r"a1c"]),
            creatinine=_extract_metric(report_text, [r"creatinine"]),
            hemoglobin=_extract_metric(report_text, [r"hemoglobin", r"haemoglobin"]),
            alt=_extract_metric(report_text, [r"alt\b", r"sgpt", r"alanine\s*aminotransferase"]),
            ast=_extract_metric(report_text, [r"ast\b", r"sgot", r"aspartate\s*aminotransferase"]),
            glucose=_extract_metric(report_text, [r"glucose", r"fasting\s*blood\s*sugar"]),
            testosterone=_extract_metric(report_text, [r"testosterone"]),
        )


def _extract_metric(text: str, labels: list[str]) -> float | None:
    for label in labels:
        pattern = re.compile(rf"{label}[^0-9]{{0,20}}([0-9]+(?:\.[0-9]+)?)", re.IGNORECASE)
        match = pattern.search(text)
        if match:
            try:
                return float(match.group(1))
            except ValueError:
                return None
    return None


def _as_float(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

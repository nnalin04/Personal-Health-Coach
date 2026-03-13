"""
Smart Router — classifies incoming Omni-Chat payloads and dispatches
to the appropriate AI pipeline.

Classification:
  FOOD   → Gemini Vision pipeline  (nutrient_analysis_service.analyze_food)
  REPORT → Document AI OCR pipeline (medical_parser_service)
  TEXT   → RAG Correlation Engine   (rag_service)

The router is called by the RabbitMQ consumer when processing tasks
published by the Spring Boot Orchestrator.
"""
import enum
import logging

from app.ai.gemini_client import GeminiClient

logger = logging.getLogger(__name__)

_CLASSIFICATION_SYSTEM = """You are a health data routing assistant.
Classify the user's input into exactly one of: FOOD, REPORT, TEXT.

FOOD   = food image analysis or meal description (e.g. "I ate dal rice", "here's my lunch photo")
REPORT = medical lab report or clinical document (e.g. "my blood test results", "CBC report")
TEXT   = general health question, symptom description, or anything else

Respond with ONLY one word: FOOD, REPORT, or TEXT."""


class InputType(str, enum.Enum):
    FOOD   = "FOOD"
    REPORT = "REPORT"
    TEXT   = "TEXT"


class SmartRouter:
    """Lightweight input classifier — uses Gemini Flash for low-latency routing."""

    def __init__(self):
        self._client = GeminiClient()

    def classify(self, text: str | None, has_image: bool, has_pdf: bool) -> InputType:
        """
        Determine input type from content hints.
        Image/PDF presence takes priority over text classification.
        """
        if has_image:
            return InputType.FOOD
        if has_pdf:
            return InputType.REPORT
        if not text:
            return InputType.TEXT

        try:
            result = self._client.generate_json(
                _CLASSIFICATION_SYSTEM,
                f"Classify this input: {text[:500]}",
            )
            # generate_json expects JSON, but classification returns a word.
            # Fall back to raw generation.
        except Exception:
            pass

        # Direct text classification via raw generate (not JSON mode)
        try:
            import google.generativeai as genai
            import os
            genai.configure(api_key=os.getenv("GEMINI_API_KEY", ""))
            model = genai.GenerativeModel(
                os.getenv("GEMINI_MODEL", "gemini-2.5-flash"),
                system_instruction=_CLASSIFICATION_SYSTEM,
            )
            response = model.generate_content(f"Classify: {text[:500]}")
            label = response.text.strip().upper()
            if label in InputType.__members__:
                return InputType(label)
        except Exception as e:
            logger.warning("Smart Router classification failed: %s — defaulting to TEXT", e)

        return InputType.TEXT


def route_task(
    task_type: str,
    task_id: str,
    user_id: str,
    payload: dict,
    user_context: dict,
) -> dict:
    """
    Dispatch a RabbitMQ task to the correct service pipeline.

    Returns a result dict to be stored in omni_chat_tasks.result_json
    and pushed back to the Orchestrator.
    """
    from app.services.nutrient_analysis_service import NutrientAnalysisService
    # Medical parser and RAG services to be wired in Phase 3/4
    # from app.services.medical_parser_service import MedicalParserService
    # from app.services.rag_service import RagService

    logger.info("Routing task %s type=%s user=%s", task_id, task_type, user_id)

    input_type = InputType(task_type.upper()) if task_type.upper() in InputType.__members__ else InputType.TEXT

    if input_type == InputType.FOOD:
        service = NutrientAnalysisService()
        image_b64 = payload.get("image_base64")
        description = payload.get("description")
        result = service.analyze_food(
            image_base64=image_b64,
            description=description,
            image_mime_type=payload.get("mime_type", "image/jpeg"),
            user_context=user_context,
        )
        return {
            "type": "FOOD",
            "taskId": task_id,
            "status": "COMPLETED",
            "mealLog": {
                "dishName":    description or "Unknown food",
                "calories":    result.total_calories,
                "proteinG":    result.protein_g,
                "carbsG":      result.carbs_g,
                "fatsG":       result.fats_g,
                "confidence":  result.confidence_note,
            },
        }

    if input_type == InputType.REPORT:
        # Phase 4: wire in Document AI OCR
        return {
            "type":    "REPORT",
            "taskId":  task_id,
            "status":  "PARTIAL",
            "message": "Medical OCR pipeline coming in Phase 4",
        }

    # TEXT / RAG
    return {
        "type":    "TEXT",
        "taskId":  task_id,
        "status":  "PARTIAL",
        "message": "RAG correlation engine coming in Phase 4",
    }

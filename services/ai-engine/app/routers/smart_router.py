"""
Smart Router — classifies incoming Omni-Chat payloads and dispatches
to the appropriate AI pipeline.

Classification:
  FOOD    → Gemini Vision pipeline  (nutrient_analysis_service.analyze_food)
  REPORT  → Gemini Vision medical OCR (medical_parser_service)
  RECEIPT → Quick-commerce receipt parser (receipt_parser_service)
  TEXT    → RAG Correlation Engine   (rag_service)

The router is called by the RabbitMQ consumer when processing tasks
published by the Spring Boot Orchestrator.

File payloads:
  GCS URI (gs://...)  → gcs_helper.download_gcs_bytes() → raw bytes → Gemini
  Base64 string       → existing base64 path (local dev fallback)
"""
import enum
import logging

from app.ai.gemini_client import GeminiClient
from app.ai.model_router import get_client, get_vision_client

logger = logging.getLogger(__name__)

_CLASSIFICATION_SYSTEM = """You are a health data routing assistant.
Classify the user's input into exactly one of: FOOD, REPORT, RECEIPT, TEXT.

FOOD    = food image analysis or meal description (e.g. "I ate dal rice", "here's my lunch photo")
REPORT  = medical lab report or clinical document (e.g. "my blood test results", "CBC report")
RECEIPT = grocery/quick-commerce receipt (e.g. "Blinkit order", "Instamart receipt", "grocery bill")
TEXT    = general health question, symptom description, or anything else

Respond with ONLY one word: FOOD, REPORT, RECEIPT, or TEXT."""


class InputType(str, enum.Enum):
    FOOD    = "FOOD"
    REPORT  = "REPORT"
    RECEIPT = "RECEIPT"
    TEXT    = "TEXT"


class SmartRouter:
    """Lightweight input classifier — uses Gemini Flash for low-latency routing."""

    def __init__(self):
        self._client = GeminiClient()

    def classify(self, text: str | None, has_image: bool, has_pdf: bool) -> InputType:
        """
        Determine input type from content hints.
        PDF presence → REPORT. Image + receipt keywords → RECEIPT. Image alone → FOOD.
        """
        if has_pdf:
            return InputType.REPORT

        # Receipt detection from text keywords (before general image check)
        if text and any(kw in text.lower() for kw in
                        ("blinkit", "instamart", "zepto", "bigbasket", "swiggy instamart",
                         "grocery receipt", "order receipt", "grocery bill")):
            return InputType.RECEIPT

        if has_image:
            return InputType.FOOD

        if not text:
            return InputType.TEXT

        # Direct text classification via Gemini
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
    and pushed back to the Orchestrator via WebSocket.
    """
    from app.services.nutrient_analysis_service import NutrientAnalysisService
    from app.services.medical_parser_service import parse_medical_report
    from app.services.receipt_parser_service import parse_receipt
    from app.services.rag_service import answer_query
    from app.utils.gcs_helper import resolve_payload

    logger.info("Routing task %s type=%s user=%s", task_id, task_type, user_id)

    input_type = (
        InputType(task_type.upper())
        if task_type.upper() in InputType.__members__
        else InputType.TEXT
    )

    # ── FOOD ──────────────────────────────────────────────────────────────────
    if input_type == InputType.FOOD:
        service = NutrientAnalysisService()
        raw_url  = payload.get("imageUrl") or payload.get("image_base64")
        file_bytes, source = resolve_payload(raw_url)
        image_b64 = None if source == "gcs" else raw_url

        try:
            client = get_vision_client("FOOD")
        except Exception as exc:
            logger.warning("model_router.get_vision_client FOOD failed (%s) — using default", exc)
            client = None

        description = payload.get("description") or payload.get("chatId", "")
        result = service.analyze_food(
            image_base64=image_b64,
            image_bytes=file_bytes,        # new param — used when source=="gcs"
            description=description,
            image_mime_type=payload.get("mime_type", "image/jpeg"),
            user_context=user_context,
            client=client,
        )

        confidences = [f.confidence for f in (result.foods or []) if f.confidence is not None]
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0.5

        meal_log = {
            "dishName":   ", ".join(f.name for f in result.foods) if result.foods else (description or "Unknown food"),
            "calories":   result.total_calories,
            "proteinG":   result.protein_g,
            "carbsG":     result.carbs_g,
            "fatsG":      result.fats_g,
            "confidence": result.confidence_note,
        }

        if avg_confidence < 0.80:
            food_label = meal_log["dishName"] or "this food"
            return {
                "type":       "FOOD",
                "taskId":     task_id,
                "status":     "PARTIAL",
                "message":    (
                    f"I'm not fully confident about '{food_label}' "
                    f"(confidence: {avg_confidence:.0%}). "
                    "Could you add more detail — dish name, ingredients, or portion size? "
                    "I'll re-analyse once you confirm."
                ),
                "mealLog":    meal_log,
                "confidence": avg_confidence,
            }

        return {
            "type":    "FOOD",
            "taskId":  task_id,
            "status":  "COMPLETED",
            "mealLog": meal_log,
        }

    # ── REPORT ────────────────────────────────────────────────────────────────
    if input_type == InputType.REPORT:
        raw_url    = payload.get("documentUrl") or payload.get("imageUrl")
        mime_type  = payload.get("mime_type", "application/pdf")
        file_bytes, source = resolve_payload(raw_url)
        file_b64   = None if source == "gcs" else raw_url

        try:
            client = get_client("REPORT")
        except Exception as exc:
            logger.warning("model_router.get_client REPORT failed (%s) — using default", exc)
            client = None

        parsed = parse_medical_report(
            file_data=file_bytes,
            file_b64=file_b64,
            mime_type=mime_type,
            user_context=user_context,
            client=client,
        )

        status = "COMPLETED" if parsed.get("parsed") else "PARTIAL"
        return {
            "type":    "REPORT",
            "taskId":  task_id,
            "status":  status,
            "message": parsed.get("summary", "Lab report processed."),
            "result":  parsed,
        }

    # ── RECEIPT ───────────────────────────────────────────────────────────────
    if input_type == InputType.RECEIPT:
        raw_url    = payload.get("imageUrl") or payload.get("documentUrl")
        mime_type  = payload.get("mime_type", "image/jpeg")
        file_bytes, source = resolve_payload(raw_url)
        file_b64   = None if source == "gcs" else raw_url
        description = payload.get("message") or payload.get("description", "")

        try:
            client = get_vision_client("RECEIPT")
        except Exception as exc:
            logger.warning("model_router.get_vision_client RECEIPT failed (%s) — using default", exc)
            client = None

        parsed = parse_receipt(
            file_data=file_bytes,
            file_b64=file_b64,
            mime_type=mime_type,
            description=description,
            user_context=user_context,
        )

        status = "COMPLETED" if parsed.get("parsed") else "PARTIAL"
        return {
            "type":      "RECEIPT",
            "taskId":    task_id,
            "status":    status,
            "message":   parsed.get("message", "Receipt processed."),
            "result":    parsed,
        }

    # ── TEXT / RAG ────────────────────────────────────────────────────────────
    query = payload.get("message", payload.get("text", ""))
    if not query:
        return {
            "type":    "TEXT",
            "taskId":  task_id,
            "status":  "COMPLETED",
            "message": "Please send a health question and I'll do my best to help!",
        }

    try:
        text_client = get_client("TEXT")
    except Exception as exc:
        logger.warning("model_router.get_client TEXT failed (%s) — using default", exc)
        text_client = None

    rag_result = answer_query(query=query, user_context=user_context, client=text_client)
    return {
        "type":       "TEXT",
        "taskId":     task_id,
        "status":     "COMPLETED",
        "message":    rag_result["answer"],
        "sources":    rag_result.get("sources", []),
        "chunksUsed": rag_result.get("chunks_used", 0),
    }

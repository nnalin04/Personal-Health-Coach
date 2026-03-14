"""
Quick-commerce receipt parser — extracts grocery items from a
Blinkit / Instamart / Zepto / BigBasket receipt image/screenshot.

Uses Gemini Vision to read the receipt and returns a structured list
of food items with estimated nutritional values ready for bulk-logging
to the food_logs table via the WatermelonDB sync endpoint.

Triggered by RECEIPT route type in smart_router (detected either via
explicit type="RECEIPT" upload or by text classification matching
receipt / grocery / order keywords).
"""
import base64
import json
import logging
import os
import re

import google.generativeai as genai

logger = logging.getLogger(__name__)

_RECEIPT_SYSTEM = """You are a grocery receipt analyst that extracts food items from
quick-commerce receipts (Blinkit, Instamart, Zepto, BigBasket, Swiggy Instamart).
Return ONLY valid JSON — no markdown, no extra text."""

_RECEIPT_PROMPT = """Extract all food/grocery items from this receipt image.

For each item estimate realistic nutritional values per the purchased quantity.

Return JSON in EXACTLY this format:
{
  "platform": "Blinkit or Instamart or Unknown",
  "order_date": "YYYY-MM-DD or null",
  "items": [
    {
      "name": "Amul Milk Full Fat",
      "quantity_g": 500,
      "quantity_unit": "ml",
      "calories": 325,
      "protein_g": 16.5,
      "carbs_g": 24.0,
      "fats_g": 17.5,
      "confidence": 0.9
    }
  ],
  "total_calories": 0,
  "note": "optional note about estimation accuracy"
}

- quantity_g should be total grams (convert ml/litre/kg as needed)
- Skip non-food items (cleaning products, toiletries, packaging)
- confidence is per-item 0-1 based on how recognisable the item is
- If quantity is unclear, assume one standard unit"""


def parse_receipt(
    file_data: bytes | None,
    file_b64: str | None,
    mime_type: str = "image/jpeg",
    description: str | None = None,
    user_context: dict | None = None,
) -> dict:
    """
    Parse a quick-commerce receipt and return structured food items.

    :param file_data:    Raw bytes of the receipt image
    :param file_b64:     Base64-encoded receipt as fallback
    :param mime_type:    Image MIME type
    :param description:  Optional text description (e.g. "Blinkit order 2kg rice")
    :param user_context: User preferences for personalised logging
    :returns:            Structured dict with items ready for bulk food-log
    """
    try:
        genai.configure(api_key=os.getenv("GEMINI_API_KEY", ""))
        model = genai.GenerativeModel(
            os.getenv("GEMINI_MODEL", "gemini-2.5-flash"),
            system_instruction=_RECEIPT_SYSTEM,
        )

        parts: list = []

        # Add image if available
        raw_bytes: bytes | None = None
        if file_data:
            raw_bytes = file_data
        elif file_b64:
            try:
                raw_bytes = base64.b64decode(file_b64)
            except Exception:
                pass

        if raw_bytes:
            parts.append({"mime_type": mime_type, "data": raw_bytes})

        # Add text description as supplementary context
        prompt = _RECEIPT_PROMPT
        if description:
            prompt += f"\n\nAdditional context from user: {description[:500]}"
        parts.append(prompt)

        if not parts or (len(parts) == 1 and isinstance(parts[0], str)):
            return _fallback("No receipt image or description provided")

        response = model.generate_content(parts)
        raw = response.text.strip()
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)

        result = json.loads(raw)
        items = result.get("items", [])

        # Compute total_calories if not present
        if not result.get("total_calories") and items:
            result["total_calories"] = sum(i.get("calories", 0) for i in items)

        return {
            "parsed":        True,
            "platform":      result.get("platform", "Unknown"),
            "orderDate":     result.get("order_date"),
            "items":         items,
            "totalCalories": result.get("total_calories", 0),
            "itemCount":     len(items),
            "note":          result.get("note", ""),
            "message": (
                f"Found {len(items)} food items from your {result.get('platform','receipt')}. "
                "Tap 'Log All' to add them to today's food diary."
            ),
        }

    except json.JSONDecodeError as e:
        logger.warning("Receipt parser JSON decode failed: %s", e)
        return _fallback(f"Could not parse receipt structure: {e}")
    except Exception as e:
        logger.error("Receipt parser error: %s", e, exc_info=True)
        return _fallback(str(e))


def _fallback(reason: str) -> dict:
    return {
        "parsed":   False,
        "items":    [],
        "error":    reason,
        "message":  "Could not read this receipt. Please try a clearer image.",
    }

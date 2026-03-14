"""
Profile Update Service — parse natural language profile update intents.

Detects when a user message intends to update a profile field and extracts
the structured values. Handles:
  - weight (kg)
  - height (cm)
  - region / state
  - health goal
  - gender
  - cuisine style / diet type
  - dietary restrictions
  - age

Returns { isProfileUpdate, fields, confirmationMessage }.
"""
import json
import logging
import os
from typing import Any

import google.generativeai as genai

logger = logging.getLogger(__name__)

_SYSTEM = """You are a profile update parser for a health app.

The user may say something like:
  "Update my weight to 75 kg"
  "Change my region to Punjab"
  "My health goal is now to build muscle"
  "I am 28 years old"
  "I prefer vegetarian food"
  "My height is 175 cm"

Extract any profile field updates from the message and return a JSON object.

Supported fields (use these exact keys):
  weightKg        — number (user's weight in kg, e.g. 75.5)
  heightCm        — number (user's height in cm, e.g. 175)
  region          — string (state or region in India, e.g. "Punjab", "Maharashtra")
  healthGoal      — string, one of: "Lose weight", "Build muscle", "Manage diabetes", "Improve fitness", "Maintain weight"
  gender          — string, one of: "Male", "Female", "Other", "Prefer not to say"
  cuisineStyle    — string, one of: "Vegetarian", "Non-vegetarian", "Vegan", "Jain", "Eggetarian"
  dietaryRestrictions — string (free text, e.g. "no onion-garlic", "gluten-free", "none")
  age             — integer (user's age in years)

Rules:
1. If the message contains NO profile update intent, return: {"isProfileUpdate": false}
2. If it does contain profile updates, return:
   {
     "isProfileUpdate": true,
     "fields": { <only the fields that were mentioned> },
     "confirmationMessage": "<friendly confirmation like 'Got it! I've updated your weight to 75 kg.'>"
   }
3. Do not make up values. Only include fields explicitly mentioned.
4. For healthGoal, map synonyms: "lose fat" → "Lose weight", "gain muscle" → "Build muscle", etc.
5. Return ONLY valid JSON. No markdown, no explanation."""


class ProfileUpdateService:

    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY", "")
        if api_key:
            genai.configure(api_key=api_key)
        self._model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

    def parse(self, message: str) -> dict[str, Any]:
        """
        Parse a natural language message for profile update intent.

        Returns a dict with:
          isProfileUpdate: bool
          fields: dict (only present if isProfileUpdate is True)
          confirmationMessage: str (only present if isProfileUpdate is True)
        """
        if not message or not message.strip():
            return {"isProfileUpdate": False}

        api_key = os.getenv("GEMINI_API_KEY", "")
        if not api_key:
            logger.warning("GEMINI_API_KEY not set — profile update parsing unavailable")
            return {"isProfileUpdate": False}

        try:
            model = genai.GenerativeModel(
                self._model_name,
                system_instruction=_SYSTEM,
                generation_config={"response_mime_type": "application/json"},
            )
            response = model.generate_content(f"Message: {message[:600]}")
            raw = response.text.strip()
            result = json.loads(raw)

            if not isinstance(result, dict) or "isProfileUpdate" not in result:
                return {"isProfileUpdate": False}

            if not result.get("isProfileUpdate"):
                return {"isProfileUpdate": False}

            fields = result.get("fields", {})
            if not fields:
                return {"isProfileUpdate": False}

            return {
                "isProfileUpdate": True,
                "fields": fields,
                "confirmationMessage": result.get(
                    "confirmationMessage",
                    "Got it! Your profile has been updated.",
                ),
            }

        except Exception as e:
            logger.warning("Profile update parsing failed: %s", e)
            return {"isProfileUpdate": False}

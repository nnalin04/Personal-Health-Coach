import base64

from pydantic import ValidationError

from app.ai.gemini_client import GeminiClient, GeminiError
from app.ai.base_client import BaseAIClient
from app.schemas.nutrient import (
    FoodAnalysisResponse, NutrientRecommendationResponse,
    IdentifiedFood, VitaminProfile, MineralProfile, NutrientProfile,
    DeficiencyInsight, FoodRecommendation, SupplementSuggestion
)

FOOD_ANALYSIS_SYSTEM = """You are a certified nutrition expert AI.
Analyze the provided food image and/or description to identify all food items and estimate their
macronutrient content (protein, carbohydrates, fats, calories) and micronutrient content (vitamins and minerals).
Use your broad knowledge of food composition to provide realistic estimates even for common dishes described
in natural language (e.g. "1 plate veg biryani", "90g peanuts", "2 eggs and dal").
Return ONLY valid JSON in the exact format requested. Be precise and realistic with nutrient values.
If you cannot determine a value reliably, return null for that field."""

RECOMMENDATION_SYSTEM = """You are a culturally-sensitive nutrition expert AI.
Your recommendations must respect the user's regional cuisine, cultural preferences, and dietary restrictions.
Suggest foods that are actually available and commonly eaten in the user's region.
Prefer food-first solutions over supplements. Return ONLY valid JSON."""


class NutrientAnalysisService:
    def __init__(self):
        self.client = GeminiClient()

    def analyze_food(self, image_base64: str | None, description: str | None,
                     image_mime_type: str, user_context: dict,
                     image_bytes: bytes | None = None,
                     client: BaseAIClient | None = None) -> FoodAnalysisResponse:
        region = user_context.get("region", "India")
        cuisine = user_context.get("cuisine_style", "mixed")
        restrictions = user_context.get("dietary_restrictions", "none")

        user_prompt = f"""Analyze this meal and return its micronutrient content.

User context: Region={region}, Cuisine preference={cuisine}, Dietary restrictions={restrictions}
{"Food description: " + description if description else ""}

Return JSON in this exact format:
{{
  "foods": [
    {{"name": "food name", "portion_g": 150, "confidence": 0.9}}
  ],
  "protein_g": 0,
  "carbs_g": 0,
  "fats_g": 0,
  "total_calories": 0,
  "nutrients": {{
    "vitamins": {{
      "a_mcg": null, "b1_mg": null, "b2_mg": null, "b3_mg": null,
      "b6_mg": null, "b9_mcg": null, "b12_mcg": null, "c_mg": null,
      "d_mcg": null, "e_mg": null, "k_mcg": null
    }},
    "minerals": {{
      "calcium_mg": null, "iron_mg": null, "zinc_mg": null,
      "magnesium_mg": null, "potassium_mg": null, "selenium_mcg": null, "iodine_mcg": null
    }}
  }},
  "confidence_note": "brief note about analysis confidence"
}}"""

        from app.ai.groq_client import GroqClient
        active_client = client or self.client

        try:
            if image_bytes:
                # GCS path: raw bytes from cloud storage
                if isinstance(active_client, GroqClient):
                    result = active_client.generate_vision_json(
                        FOOD_ANALYSIS_SYSTEM, user_prompt, image_bytes, image_mime_type
                    )
                else:
                    image_part = {"mime_type": image_mime_type, "data": image_bytes}
                    result = active_client.generate_json(FOOD_ANALYSIS_SYSTEM, user_prompt, [image_part])
            elif image_base64:
                # Local-dev path: base64-encoded bytes
                if isinstance(active_client, GroqClient):
                    img_data = base64.b64decode(image_base64)
                    result = active_client.generate_vision_json(
                        FOOD_ANALYSIS_SYSTEM, user_prompt, img_data, image_mime_type
                    )
                else:
                    image_part = {"mime_type": image_mime_type, "data": image_base64}
                    result = active_client.generate_json(FOOD_ANALYSIS_SYSTEM, user_prompt, [image_part])
            else:
                # Text-only call (description only, no image)
                result = active_client.generate_json(FOOD_ANALYSIS_SYSTEM, user_prompt)

            foods = [IdentifiedFood(**f) for f in result.get("foods", [])]
            raw_n = result.get("nutrients", {})
            vitamins = VitaminProfile(**raw_n.get("vitamins", {}))
            minerals = MineralProfile(**raw_n.get("minerals", {}))

            return FoodAnalysisResponse(
                foods=foods,
                nutrients=NutrientProfile(vitamins=vitamins, minerals=minerals),
                protein_g=result.get("protein_g"),
                carbs_g=result.get("carbs_g"),
                fats_g=result.get("fats_g"),
                total_calories=result.get("total_calories"),
                confidence_note=result.get("confidence_note")
            )
        except (GeminiError, ValidationError) as e:
            # Fallback: return empty profile on failure
            return FoodAnalysisResponse(
                foods=[IdentifiedFood(name=description or "Unknown food")],
                nutrients=NutrientProfile(),
                confidence_note=f"Analysis unavailable: {str(e)}"
            )

    def get_recommendations(self, deficiency_profile: list, food_history_summary: str | None,
                            user_context: dict,
                            client: BaseAIClient | None = None) -> NutrientRecommendationResponse:
        region = user_context.get("region", "India")
        cuisine = user_context.get("cuisine_style", "mixed")
        restrictions = user_context.get("dietary_restrictions", "none")
        gender = user_context.get("gender", "unknown")
        age = user_context.get("age", "adult")

        deficiency_text = "\n".join(
            f"- {d.get('nutrient')}: {d.get('avg_percent_rda', 0):.0f}% of RDA ({d.get('days_deficient', 0)} of 14 days)"
            for d in deficiency_profile
        )

        user_prompt = f"""User Nutrition Profile:
Region: {region}
Cuisine preference: {cuisine}
Dietary restrictions: {restrictions}
Gender: {gender}, Age: {age}

Deficiencies (last 14 days):
{deficiency_text}

{"Recent food history: " + food_history_summary if food_history_summary else ""}

Provide culturally-appropriate recommendations. For someone in {region} who eats {cuisine} food,
suggest improvements using familiar local foods. Never suggest foods that violate their dietary restrictions.

Return JSON:
{{
  "deficiency_insights": [
    {{"nutrient": "Iron", "level": "below 60% RDA for 10 of 14 days", "impact": "fatigue, reduced immunity"}}
  ],
  "food_recommendations": [
    {{
      "for_deficiency": "Iron",
      "food": "Palak Dal (spinach lentil curry)",
      "reason": "Iron-rich spinach combined with vitamin C from tomatoes improves absorption",
      "how_to_add": "Replace plain dal with palak dal 3 times per week"
    }}
  ],
  "supplement_suggestions": [
    {{
      "for_deficiency": "Vitamin D",
      "supplement": "Vitamin D3 1000IU daily",
      "reason": "Limited dietary sources in vegetarian diet",
      "food_alternative": "Fortified milk or sunlight-exposed mushrooms"
    }}
  ]
}}"""

        active_client = client or self.client
        try:
            result = active_client.generate_json(RECOMMENDATION_SYSTEM, user_prompt)
            return NutrientRecommendationResponse(
                deficiency_insights=[DeficiencyInsight(**d) for d in result.get("deficiency_insights", [])],
                food_recommendations=[FoodRecommendation(**r) for r in result.get("food_recommendations", [])],
                supplement_suggestions=[SupplementSuggestion(**s) for s in result.get("supplement_suggestions", [])]
            )
        except (GeminiError, ValidationError) as e:
            return NutrientRecommendationResponse(
                deficiency_insights=[],
                food_recommendations=[],
                supplement_suggestions=[]
            )

from pydantic import BaseModel
from typing import Optional


class VitaminProfile(BaseModel):
    a_mcg: Optional[float] = None
    b1_mg: Optional[float] = None
    b2_mg: Optional[float] = None
    b3_mg: Optional[float] = None
    b6_mg: Optional[float] = None
    b9_mcg: Optional[float] = None
    b12_mcg: Optional[float] = None
    c_mg: Optional[float] = None
    d_mcg: Optional[float] = None
    e_mg: Optional[float] = None
    k_mcg: Optional[float] = None


class MineralProfile(BaseModel):
    calcium_mg: Optional[float] = None
    iron_mg: Optional[float] = None
    zinc_mg: Optional[float] = None
    magnesium_mg: Optional[float] = None
    potassium_mg: Optional[float] = None
    selenium_mcg: Optional[float] = None
    iodine_mcg: Optional[float] = None


class NutrientProfile(BaseModel):
    vitamins: VitaminProfile = VitaminProfile()
    minerals: MineralProfile = MineralProfile()


class IdentifiedFood(BaseModel):
    name: str
    portion_g: Optional[float] = None
    confidence: Optional[float] = None


class FoodAnalysisRequest(BaseModel):
    image_base64: Optional[str] = None      # base64 encoded image
    image_mime_type: Optional[str] = "image/jpeg"  # e.g. image/jpeg, image/png
    description: Optional[str] = None       # free text description
    user_context: Optional[dict] = {}       # {region, cuisine_style, dietary_restrictions}


class FoodAnalysisResponse(BaseModel):
    foods: list[IdentifiedFood]
    nutrients: NutrientProfile
    total_calories: Optional[float] = None
    confidence_note: Optional[str] = None


class NutrientRecommendationRequest(BaseModel):
    deficiency_profile: list[dict]          # [{nutrient, days_deficient, avg_percent_rda}]
    food_history_summary: Optional[str] = None  # compressed 7-day food log summary
    user_context: dict                      # {region, cuisine_style, dietary_restrictions, gender, age}


class DeficiencyInsight(BaseModel):
    nutrient: str
    level: str
    impact: str


class FoodRecommendation(BaseModel):
    for_deficiency: str
    food: str
    reason: str
    how_to_add: str


class SupplementSuggestion(BaseModel):
    for_deficiency: str
    supplement: str
    reason: str
    food_alternative: str


class NutrientRecommendationResponse(BaseModel):
    deficiency_insights: list[DeficiencyInsight]
    food_recommendations: list[FoodRecommendation]
    supplement_suggestions: list[SupplementSuggestion]

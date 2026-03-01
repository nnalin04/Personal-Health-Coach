from fastapi import APIRouter, HTTPException
from app.schemas.nutrient import (
    FoodAnalysisRequest, FoodAnalysisResponse,
    NutrientRecommendationRequest, NutrientRecommendationResponse
)
from app.services.nutrient_analysis_service import NutrientAnalysisService

router = APIRouter()
nutrient_service = NutrientAnalysisService()


@router.post("/food/analyze-nutrients", response_model=FoodAnalysisResponse)
async def analyze_food_nutrients(request: FoodAnalysisRequest):
    """Analyze a food photo or description to extract micronutrient content."""
    if not request.image_base64 and not request.description:
        raise HTTPException(status_code=400, detail="Provide either image_base64 or description")
    return nutrient_service.analyze_food(
        image_base64=request.image_base64,
        description=request.description,
        image_mime_type=request.image_mime_type or "image/jpeg",
        user_context=request.user_context or {}
    )


@router.post("/nutrient/recommendations", response_model=NutrientRecommendationResponse)
async def get_nutrient_recommendations(request: NutrientRecommendationRequest):
    """Generate culturally-aware food and supplement recommendations based on deficiency profile."""
    return nutrient_service.get_recommendations(
        deficiency_profile=request.deficiency_profile,
        food_history_summary=request.food_history_summary,
        user_context=request.user_context
    )

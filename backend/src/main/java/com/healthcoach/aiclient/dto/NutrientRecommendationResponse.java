package com.healthcoach.aiclient.dto;

import java.util.List;
import java.util.Map;

public record NutrientRecommendationResponse(
    List<Map<String, Object>> deficiencyInsights,
    List<Map<String, Object>> foodRecommendations,
    List<Map<String, Object>> supplementSuggestions
) {}

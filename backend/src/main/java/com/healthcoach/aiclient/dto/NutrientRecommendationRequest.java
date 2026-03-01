package com.healthcoach.aiclient.dto;

import java.util.List;
import java.util.Map;

public record NutrientRecommendationRequest(
    List<Map<String, Object>> deficiencyProfile,
    String foodHistorySummary,
    Map<String, Object> userContext
) {}

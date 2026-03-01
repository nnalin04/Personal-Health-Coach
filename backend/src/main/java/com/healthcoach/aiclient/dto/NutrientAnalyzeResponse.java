package com.healthcoach.aiclient.dto;

import java.util.List;
import java.util.Map;

public record NutrientAnalyzeResponse(
    List<Map<String, Object>> foods,
    Map<String, Object> nutrients,
    Double totalCalories,
    String confidenceNote
) {}

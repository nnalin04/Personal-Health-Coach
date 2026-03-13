package com.healthcoach.aiclient.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import java.util.Map;

public record NutrientAnalyzeResponse(
    List<Map<String, Object>> foods,
    Map<String, Object> nutrients,
    @JsonProperty("protein_g")       Double proteinG,
    @JsonProperty("carbs_g")         Double carbsG,
    @JsonProperty("fats_g")          Double fatsG,
    @JsonProperty("total_calories")  Double totalCalories,
    @JsonProperty("confidence_note") String confidenceNote
) {}

package com.healthcoach.nutrient.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record NutrientSummaryDTO(
    LocalDate date,
    Map<String, Double> totalIntake,       // nutrientKey → total value today
    Map<String, Double> rdaValues,          // nutrientKey → RDA for this user
    Map<String, Double> percentOfRda,       // nutrientKey → % achieved
    List<String> deficientNutrients,        // nutrients below 80% RDA
    List<String> adequateNutrients          // nutrients at or above 80% RDA
) {}

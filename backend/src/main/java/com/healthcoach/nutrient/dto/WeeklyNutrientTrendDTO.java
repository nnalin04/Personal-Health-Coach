package com.healthcoach.nutrient.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record WeeklyNutrientTrendDTO(
    LocalDate from,
    LocalDate to,
    List<DailyNutrientDTO> days,
    Map<String, Double> weeklyAvgIntake,
    Map<String, Double> rdaValues,
    Map<String, Double> weeklyAvgPercentOfRda,
    List<String> chronicDeficiencies    // deficient 4+ of last 7 days
) {}

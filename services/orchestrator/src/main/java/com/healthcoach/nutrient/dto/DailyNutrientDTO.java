package com.healthcoach.nutrient.dto;

import java.time.LocalDate;
import java.util.Map;

public record DailyNutrientDTO(
    LocalDate date,
    Map<String, Double> intake,
    Map<String, Double> percentOfRda
) {}

package com.healthcoach.food.dto;

import com.healthcoach.food.FoodLog;
import java.time.LocalDate;

public record FoodLogResponse(
        Long id,
        String mealType,
        String foodName,
        Double protein,
        Double carbs,
        Double fats,
        Double calories,
        LocalDate date
) {
    public static FoodLogResponse from(FoodLog log) {
        return new FoodLogResponse(
                log.getId(),
                log.getMealType(),
                log.getFoodName(),
                log.getProtein(),
                log.getCarbs(),
                log.getFats(),
                log.getCalories(),
                log.getDate()
        );
    }
}

package com.healthcoach.food.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import java.time.LocalDate;

public record FoodLogRequest(
        @NotBlank String mealType,
        @NotBlank String foodName,
        @NotNull @PositiveOrZero Double protein,
        @NotNull @PositiveOrZero Double carbs,
        @NotNull @PositiveOrZero Double fats,
        @NotNull @PositiveOrZero Double calories,
        @NotNull LocalDate date
) {
}

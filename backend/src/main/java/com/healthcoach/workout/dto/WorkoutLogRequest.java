package com.healthcoach.workout.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record WorkoutLogRequest(
        @NotBlank @Size(max = 255) String exerciseName,
        @NotNull @Min(1) Integer sets,
        @NotNull @Min(1) Integer reps,
        @NotNull @PositiveOrZero Double weight,
        @NotNull LocalDate date
) {
}

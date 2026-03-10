package com.healthcoach.goals.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import java.time.LocalDate;

public record CreateGoalRequest(
        @NotBlank
        @Pattern(regexp = "WEIGHT|STEPS|CALORIES|PROTEIN|WORKOUTS_PER_WEEK",
                message = "goalType must be one of: WEIGHT, STEPS, CALORIES, PROTEIN, WORKOUTS_PER_WEEK")
        String goalType,

        @NotNull
        @Positive(message = "targetValue must be a positive number")
        Double targetValue,

        LocalDate targetDate
) {}

package com.healthcoach.bodymetrics.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import java.time.LocalDate;

public record BodyMetricsRequest(
        @NotNull @Positive Double weight,
        @PositiveOrZero Double bmi,
        @PositiveOrZero Double bodyFat,
        @PositiveOrZero Double muscleMass,
        @NotNull LocalDate date
) {
}

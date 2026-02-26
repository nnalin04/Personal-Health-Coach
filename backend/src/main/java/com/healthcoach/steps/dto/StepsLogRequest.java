package com.healthcoach.steps.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record StepsLogRequest(
        @NotNull @Min(0) Integer stepCount,
        @NotNull LocalDate date
) {
}

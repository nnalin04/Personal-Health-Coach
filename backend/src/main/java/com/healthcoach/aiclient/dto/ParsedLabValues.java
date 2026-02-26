package com.healthcoach.aiclient.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record ParsedLabValues(
        @JsonProperty("vitamin_d") Double vitaminD,
        Double tsh,
        Double ldl,
        Double hdl,
        Double triglycerides,
        Double hba1c,
        Double creatinine,
        Double hemoglobin,
        Double alt,
        Double ast,
        Double glucose,
        Double testosterone
) {
}

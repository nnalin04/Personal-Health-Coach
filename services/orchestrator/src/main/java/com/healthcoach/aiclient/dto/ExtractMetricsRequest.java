package com.healthcoach.aiclient.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ExtractMetricsRequest(
        @NotBlank @Size(max = 10000) String text
) {
}

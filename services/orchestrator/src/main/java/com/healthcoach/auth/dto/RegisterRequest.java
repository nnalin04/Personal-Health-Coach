package com.healthcoach.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @Email @NotBlank String email,
        @NotBlank @Size(min = 8, max = 64) String password,
        @NotNull @Min(1) @Max(120) Integer age,
        @NotBlank @Size(max = 40) String gender,
        @NotNull @Positive Double height,
        @NotBlank @Size(max = 120) String goal,
        @NotBlank @Size(max = 60) String dietType,
        String medicalFlags
) {
}

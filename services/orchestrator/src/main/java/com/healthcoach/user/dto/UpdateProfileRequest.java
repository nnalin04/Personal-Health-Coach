package com.healthcoach.user.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Min(1) @Max(120) Integer age,
        @Size(max = 40) String gender,
        @Positive Double height,
        @Size(max = 120) String goal,
        @Size(max = 60) String dietType,
        String medicalFlags,
        @Size(max = 255) String region,
        @Size(max = 100) String cuisineStyle,
        String dietaryRestrictions
) {
}

package com.healthcoach.user.dto;

import com.healthcoach.user.User;
import com.healthcoach.user.UserRole;
import java.time.Instant;

public record UserProfileResponse(
        Long id,
        String email,
        Integer age,
        String gender,
        Double height,
        String goal,
        String dietType,
        String medicalFlags,
        UserRole role,
        Instant createdAt,
        String region,
        String cuisineStyle,
        String dietaryRestrictions
) {
    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getAge(),
                user.getGender(),
                user.getHeight(),
                user.getGoal(),
                user.getDietType(),
                user.getMedicalFlags(),
                user.getRole(),
                user.getCreatedAt(),
                user.getRegion(),
                user.getCuisineStyle(),
                user.getDietaryRestrictions()
        );
    }
}

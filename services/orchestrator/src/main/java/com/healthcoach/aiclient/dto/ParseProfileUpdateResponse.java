package com.healthcoach.aiclient.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.Map;

/**
 * Response from AI engine's POST /api/v1/chat/parse-profile-update.
 *
 * When isProfileUpdate=true, fields contains the parsed profile fields:
 *   weightKg, heightCm, region, healthGoal, gender, cuisineStyle,
 *   dietaryRestrictions, age
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ParseProfileUpdateResponse(
        boolean isProfileUpdate,
        Map<String, Object> fields,
        String confirmationMessage
) {}

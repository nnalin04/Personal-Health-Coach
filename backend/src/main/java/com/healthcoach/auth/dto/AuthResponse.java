package com.healthcoach.auth.dto;

import com.healthcoach.user.dto.UserProfileResponse;

public record AuthResponse(
        String accessToken,
        String tokenType,
        UserProfileResponse user
) {
}

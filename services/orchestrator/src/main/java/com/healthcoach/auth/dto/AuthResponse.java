package com.healthcoach.auth.dto;

import com.healthcoach.user.dto.UserProfileResponse;

public record AuthResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresIn,        // access token TTL in seconds (for client countdown)
        UserProfileResponse user
) {
}

package com.healthcoach.auth;

import com.healthcoach.common.BadRequestException;
import com.healthcoach.user.User;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RefreshTokenService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final RefreshTokenRepository refreshTokenRepository;

    @Value("${app.jwt.refresh-expiration-ms:604800000}") // 7 days default
    private long refreshExpirationMs;

    public RefreshTokenService(RefreshTokenRepository refreshTokenRepository) {
        this.refreshTokenRepository = refreshTokenRepository;
    }

    /**
     * Generate a cryptographically-secure refresh token, store its SHA-256 hash,
     * and return the raw token to be sent to the client once.
     */
    @Transactional
    public String createRefreshToken(User user) {
        // 32 random bytes → URL-safe Base64 (43 chars)
        byte[] bytes = new byte[32];
        SECURE_RANDOM.nextBytes(bytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);

        RefreshToken entity = new RefreshToken();
        entity.setUser(user);
        entity.setTokenHash(sha256(rawToken));
        entity.setExpiresAt(Instant.now().plusMillis(refreshExpirationMs));
        refreshTokenRepository.save(entity);

        return rawToken;
    }

    /**
     * Validate the raw refresh token and return the associated entity.
     * Throws BadRequestException on any invalid / expired / revoked state.
     */
    @Transactional
    public RefreshToken validateAndRotate(String rawToken, User user) {
        String hash = sha256(rawToken);
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> new BadRequestException("Invalid refresh token"));

        if (stored.isRevoked()) {
            // Token reuse detected — revoke all tokens for this user (defence-in-depth)
            refreshTokenRepository.revokeAllForUser(user.getId());
            throw new BadRequestException("Refresh token already revoked");
        }
        if (stored.getExpiresAt().isBefore(Instant.now())) {
            throw new BadRequestException("Refresh token expired");
        }
        if (!stored.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("Refresh token user mismatch");
        }

        // Rotate: revoke old token (token-family rotation — prevents replay)
        stored.setRevoked(true);
        refreshTokenRepository.save(stored);

        return stored;
    }

    @Transactional
    public void revokeAll(Long userId) {
        refreshTokenRepository.revokeAllForUser(userId);
    }

    public java.util.Optional<RefreshToken> findByHash(String hash) {
        return refreshTokenRepository.findByTokenHash(hash);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Public static accessor so AuthService can compute the hash for lookup. */
    public static String sha256Public(String input) {
        return sha256(input);
    }

    private static String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(64);
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}

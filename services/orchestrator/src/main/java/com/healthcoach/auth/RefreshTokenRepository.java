package com.healthcoach.auth;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /** Revoke all active tokens for a user (logout / password change). */
    @Modifying
    @Transactional
    @Query("UPDATE RefreshToken r SET r.revoked = true WHERE r.user.id = :userId AND r.revoked = false")
    int revokeAllForUser(Long userId);

    /** Cleanup job: delete expired or revoked tokens older than cutoff. */
    @Modifying
    @Transactional
    @Query("DELETE FROM RefreshToken r WHERE r.revoked = true OR r.expiresAt < :cutoff")
    int deleteExpiredOrRevoked(Instant cutoff);
}

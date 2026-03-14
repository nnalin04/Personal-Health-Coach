package com.healthcoach.compliance;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * DPDP Act 2023 consent management service.
 *
 * Manages the lifecycle of user data processing consent:
 *   ACCEPT  — user agrees to current consent version; recorded immutably
 *   WITHDRAW — user requests data deletion; flags account for erasure
 *
 * Current consent version is defined in CURRENT_CONSENT_VERSION.
 * When the privacy policy changes, bump this constant and all existing
 * users will be prompted to re-consent on next login.
 */
@Service
public class ConsentService {

    public static final String CURRENT_CONSENT_VERSION = "1.0";

    private final JdbcTemplate jdbc;

    public ConsentService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Record a CONSENT ACCEPT event for the given user.
     *
     * @param userId       authenticated user
     * @param ipAddress    client IP (for audit trail)
     * @param userAgent    client User-Agent header
     */
    @Transactional
    public void acceptConsent(Long userId, String ipAddress, String userAgent) {
        // Update user row with current consent version
        jdbc.update(
            "UPDATE users SET consent_version = ?, withdrawal_requested = FALSE, withdrawal_at = NULL WHERE id = ?",
            CURRENT_CONSENT_VERSION, userId
        );
        // Append to audit log
        jdbc.update(
            "INSERT INTO consent_records (user_id, event_type, consent_version, ip_address, user_agent) VALUES (?, 'ACCEPT', ?, ?, ?)",
            userId, CURRENT_CONSENT_VERSION, ipAddress, userAgent
        );
    }

    /**
     * Record a WITHDRAWAL request. Flags the account so the erasure job
     * can delete all personal data within 30 days (DPDP Act Article 13).
     *
     * @param userId authenticated user
     * @param reason optional withdrawal reason
     */
    @Transactional
    public void withdrawConsent(Long userId, String reason, String ipAddress) {
        jdbc.update(
            "UPDATE users SET withdrawal_requested = TRUE, withdrawal_at = NOW() WHERE id = ?",
            userId
        );
        jdbc.update(
            "INSERT INTO consent_records (user_id, event_type, consent_version, ip_address, withdrawal_reason) VALUES (?, 'WITHDRAW', ?, ?, ?)",
            userId, CURRENT_CONSENT_VERSION, ipAddress, reason
        );
    }

    /**
     * Return the current consent status for a user.
     */
    public Map<String, Object> getConsentStatus(Long userId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT consent_version, withdrawal_requested, withdrawal_at FROM users WHERE id = ?",
            userId
        );
        if (rows.isEmpty()) return Map.of("error", "User not found");

        Map<String, Object> u = rows.get(0);
        String userVersion = (String) u.get("consent_version");
        boolean upToDate   = CURRENT_CONSENT_VERSION.equals(userVersion);

        return Map.of(
            "consentVersion",    Optional.ofNullable(userVersion).orElse("none"),
            "currentVersion",    CURRENT_CONSENT_VERSION,
            "consentUpToDate",   upToDate,
            "withdrawalRequested", Boolean.TRUE.equals(u.get("withdrawal_requested")),
            "withdrawalAt",      Optional.ofNullable(u.get("withdrawal_at")).orElse("")
        );
    }
}

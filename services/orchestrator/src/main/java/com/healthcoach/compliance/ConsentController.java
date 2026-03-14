package com.healthcoach.compliance;

import com.healthcoach.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * DPDP Act 2023 consent API.
 *
 *   GET  /api/users/me/consent         — current consent status
 *   POST /api/users/me/consent/accept  — record consent acceptance
 *   POST /api/users/me/consent/withdraw — request data withdrawal / erasure
 */
@RestController
@RequestMapping("/api/users/me/consent")
public class ConsentController {

    private final ConsentService consentService;

    public ConsentController(ConsentService consentService) {
        this.consentService = consentService;
    }

    /** Returns current consent version and whether the user's consent is up to date. */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getStatus(
            @AuthenticationPrincipal UserPrincipal currentUser
    ) {
        return ResponseEntity.ok(consentService.getConsentStatus(currentUser.getId()));
    }

    /**
     * Record that the user has read and accepted the current privacy policy.
     * Must be called on first login and whenever CURRENT_CONSENT_VERSION changes.
     */
    @PostMapping("/accept")
    public ResponseEntity<Map<String, Object>> accept(
            @AuthenticationPrincipal UserPrincipal currentUser,
            HttpServletRequest request
    ) {
        consentService.acceptConsent(
            currentUser.getId(),
            resolveClientIp(request),
            request.getHeader("User-Agent")
        );
        return ResponseEntity.ok(Map.of(
            "status",  "accepted",
            "version", ConsentService.CURRENT_CONSENT_VERSION
        ));
    }

    /**
     * Request data withdrawal / erasure under DPDP Act Article 13.
     * Flags the account; a scheduled job will delete all personal data within 30 days.
     */
    @PostMapping("/withdraw")
    public ResponseEntity<Map<String, Object>> withdraw(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestBody(required = false) Map<String, String> body,
            HttpServletRequest request
    ) {
        String reason = body != null ? body.getOrDefault("reason", null) : null;
        consentService.withdrawConsent(currentUser.getId(), reason, resolveClientIp(request));
        return ResponseEntity.ok(Map.of(
            "status",  "withdrawal_requested",
            "message", "Your data deletion request has been recorded. All personal data will be erased within 30 days."
        ));
    }

    private String resolveClientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) return xff.split(",")[0].trim();
        return request.getRemoteAddr();
    }
}

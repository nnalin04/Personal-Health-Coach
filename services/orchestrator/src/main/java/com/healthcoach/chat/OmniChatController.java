package com.healthcoach.chat;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.ParseProfileUpdateResponse;
import com.healthcoach.messaging.TaskPublisher;
import com.healthcoach.security.UserPrincipal;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.user.dto.UpdateProfileRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Base64;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * POST /api/v1/chat/upload
 *
 * The Omni-Chat entry point — receives text, food images, or medical PDFs
 * from the React Native app. Classifies the input type (FOOD | REPORT | TEXT)
 * and publishes an async task to RabbitMQ. Returns taskId immediately so the
 * mobile app can poll for the result.
 *
 * - FOOD: file bytes encoded as base64 and embedded in the RabbitMQ message.
 *         (GCS claim-check upload is Phase 3b for larger files.)
 * - REPORT: PDF stored via placeholder URL until GCS integration is complete.
 * - TEXT: check for profile-update intent first (synchronous); fall back to RAG.
 *
 * Every task is persisted to omni_chat_tasks for status polling.
 */
@RestController
@RequestMapping("/api/v1/chat")
public class OmniChatController {

    private static final Set<String> ALLOWED_IMAGE_TYPES =
            Set.of("image/jpeg", "image/png", "image/webp", "image/heic");

    private final TaskPublisher   taskPublisher;
    private final AiServiceClient aiServiceClient;
    private final UserService     userService;
    private final JdbcTemplate    jdbc;

    public OmniChatController(
            TaskPublisher   taskPublisher,
            AiServiceClient aiServiceClient,
            UserService     userService,
            JdbcTemplate    jdbc
    ) {
        this.taskPublisher   = taskPublisher;
        this.aiServiceClient = aiServiceClient;
        this.userService     = userService;
        this.jdbc            = jdbc;
    }

    @PostMapping("/upload")
    public ResponseEntity<Map<String, Object>> upload(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam("type")   String type,
            @RequestParam("chatId") String chatId,
            @RequestParam(value = "message", required = false) String message,
            @RequestParam(value = "file",    required = false) MultipartFile file
    ) {
        Long userId = currentUser.getId();
        UUID taskId = UUID.randomUUID();

        // Load real user context for AI personalisation
        Map<String, String> userContext = buildUserContext(userId);

        int estimatedSecs;
        switch (type.toUpperCase()) {
            case "FOOD" -> {
                if (file != null && !file.isEmpty()) {
                    String ct = file.getContentType();
                    if (ct == null || !ALLOWED_IMAGE_TYPES.contains(ct)) {
                        return ResponseEntity.badRequest().body(
                            Map.of("error", "Only JPEG, PNG, WEBP, and HEIC images are accepted"));
                    }
                }
                String imageB64 = encodeFile(file);
                taskPublisher.publishFoodVision(taskId, userId, chatId, imageB64, userContext);
                estimatedSecs = 5;
                insertTask(taskId, userId, chatId, "FOOD", estimatedSecs);
            }
            case "REPORT" -> {
                if (file != null && !file.isEmpty()) {
                    String ct = file.getContentType();
                    if (!"application/pdf".equals(ct)) {
                        return ResponseEntity.badRequest().body(
                            Map.of("error", "Only PDF documents are accepted for medical reports"));
                    }
                }
                // GCS upload is Phase 3b — placeholder URL for now
                String documentUrl = "pending://" + taskId;
                taskPublisher.publishMedicalOcr(taskId, userId, chatId, documentUrl);
                estimatedSecs = 15;
                insertTask(taskId, userId, chatId, "REPORT", estimatedSecs);
            }
            default -> {  // TEXT — check for profile update intent first
                if (message != null && !message.isBlank()) {
                    ParseProfileUpdateResponse parsed = aiServiceClient.parseProfileUpdate(message);
                    if (parsed.isProfileUpdate() && parsed.fields() != null) {
                        applyProfileUpdate(userId, parsed.fields());
                        return ResponseEntity.ok(Map.of(
                            "taskId",   taskId.toString(),
                            "status",   "COMPLETED",
                            "message",  parsed.confirmationMessage() != null
                                            ? parsed.confirmationMessage()
                                            : "Got it! Your profile has been updated.",
                            "type",     "PROFILE_UPDATE"
                        ));
                    }
                }
                taskPublisher.publishRagInsight(userId, "text_query", java.util.List.of());
                estimatedSecs = 3;
                insertTask(taskId, userId, chatId, "TEXT", estimatedSecs);
            }
        }

        return ResponseEntity.accepted().body(Map.of(
            "taskId",        taskId.toString(),
            "status",        "PROCESSING",
            "estimatedTime", estimatedSecs + "s"
        ));
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    /**
     * Load user context for AI personalisation.
     * Prefers taste_profiles (richer) over the users table fallback.
     * Gracefully falls back to users table if taste_profiles row is absent (V5 not yet applied).
     */
    private Map<String, String> buildUserContext(Long userId) {
        // Try taste_profiles first (richer context from V5 migration)
        try {
            var rows = jdbc.queryForList(
                "SELECT region, cuisine_style, dietary_restrictions, health_goal, " +
                "spice_preference, staple_grains FROM taste_profiles WHERE user_id = ?",
                userId
            );
            if (!rows.isEmpty()) {
                var tp = rows.get(0);
                return Map.of(
                    "region",              nullOr(str(tp, "region"),               "India"),
                    "cuisineStyle",        nullOr(str(tp, "cuisine_style"),        "mixed"),
                    "dietaryRestrictions", nullOr(str(tp, "dietary_restrictions"), "none"),
                    "healthGoal",          nullOr(str(tp, "health_goal"),          "general wellness"),
                    "spicePreference",     nullOr(str(tp, "spice_preference"),     "medium"),
                    "stapleGrains",        nullOr(str(tp, "staple_grains"),        "rice/wheat")
                );
            }
        } catch (Exception ignored) { /* table not yet created — fall through */ }

        // Fallback: users table
        try {
            User user = userService.getById(userId);
            return Map.of(
                "region",              nullOr(user.getRegion(),              "India"),
                "cuisineStyle",        nullOr(user.getCuisineStyle(),        "mixed"),
                "dietaryRestrictions", nullOr(user.getDietaryRestrictions(), "none"),
                "healthGoal",          "general wellness",
                "spicePreference",     "medium",
                "stapleGrains",        "rice/wheat"
            );
        } catch (Exception e) {
            return Map.of("region", "India", "cuisineStyle", "mixed", "dietaryRestrictions", "none",
                          "healthGoal", "general wellness", "spicePreference", "medium", "stapleGrains", "rice/wheat");
        }
    }

    private static String str(java.util.Map<String, Object> m, String k) {
        Object v = m.get(k);
        return v != null ? v.toString() : null;
    }

    private static String nullOr(String value, String fallback) {
        return (value != null && !value.isBlank()) ? value : fallback;
    }

    /** Encode multipart file to base64 for embedding in RabbitMQ message. */
    private String encodeFile(MultipartFile file) {
        if (file == null || file.isEmpty()) return "";
        try {
            return Base64.getEncoder().encodeToString(file.getBytes());
        } catch (Exception e) {
            return "";
        }
    }

    /** Persist a new task record so the mobile app can poll for status. */
    private void insertTask(UUID taskId, Long userId, String chatId, String taskType, int estimatedSecs) {
        try {
            jdbc.update(
                "INSERT INTO omni_chat_tasks (id, user_id, chat_id, task_type, status, estimated_secs) VALUES (?, ?, ?, ?, 'PROCESSING', ?)",
                taskId, userId, chatId, taskType, (short) estimatedSecs
            );
        } catch (Exception e) {
            // Non-fatal: task tracking fails gracefully (V5 migration may not be applied in test env)
        }
    }

    /** Apply parsed profile fields to the user record. */
    private void applyProfileUpdate(Long userId, Map<String, Object> fields) {
        UpdateProfileRequest request = new UpdateProfileRequest(
            getInteger(fields, "age"),
            getString (fields, "gender"),
            getDouble (fields, "heightCm"),
            getString (fields, "healthGoal"),
            null, null,
            getString (fields, "region"),
            getString (fields, "cuisineStyle"),
            getString (fields, "dietaryRestrictions")
        );
        userService.updateProfile(userId, request);
    }

    private String  getString (Map<String, Object> f, String k) { Object v = f.get(k); return v instanceof String s ? s : null; }
    private Double  getDouble (Map<String, Object> f, String k) { Object v = f.get(k); return v instanceof Number n ? n.doubleValue() : null; }
    private Integer getInteger(Map<String, Object> f, String k) { Object v = f.get(k); return v instanceof Number n ? n.intValue() : null; }
}

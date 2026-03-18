package com.healthcoach.chat;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.ParseProfileUpdateResponse;
import com.healthcoach.messaging.TaskPublisher;
import com.healthcoach.storage.GcsStorageService;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.user.dto.UpdateProfileRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.Base64;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Orchestrates the OmniChat upload pipeline:
 *   FOOD   — validate image → GCS upload (claim-check) or base64 fallback → RabbitMQ
 *   REPORT — validate PDF   → GCS upload or base64 fallback → RabbitMQ
 *   TEXT   — detect profile-update intent (sync) → apply or forward to RAG via RabbitMQ
 *
 * Returns an {@link UploadResult} value type; {@link OmniChatController} translates it to HTTP.
 */
@Service
public class OmniChatService {

    private static final Logger log = LoggerFactory.getLogger(OmniChatService.class);

    private static final Set<String> ALLOWED_IMAGE_TYPES =
            Set.of("image/jpeg", "image/png", "image/webp", "image/heic");

    private final TaskPublisher     taskPublisher;
    private final AiServiceClient   aiServiceClient;
    private final UserService       userService;
    private final JdbcTemplate      jdbc;
    private final GcsStorageService gcsStorage;

    public OmniChatService(
            TaskPublisher     taskPublisher,
            AiServiceClient   aiServiceClient,
            UserService       userService,
            JdbcTemplate      jdbc,
            GcsStorageService gcsStorage
    ) {
        this.taskPublisher   = taskPublisher;
        this.aiServiceClient = aiServiceClient;
        this.userService     = userService;
        this.jdbc            = jdbc;
        this.gcsStorage      = gcsStorage;
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public UploadResult handleUpload(
            Long         userId,
            String       type,
            String       chatId,
            String       message,
            MultipartFile file
    ) {
        UUID taskId = UUID.randomUUID();
        Map<String, String> userContext = buildUserContext(userId);

        return switch (type.toUpperCase()) {
            case "FOOD"   -> handleFood  (taskId, userId, chatId, file,    userContext);
            case "REPORT" -> handleReport(taskId, userId, chatId, file);
            default       -> handleText  (taskId, userId, chatId, message, userContext);
        };
    }

    // ── Pipeline branches ─────────────────────────────────────────────────────

    private UploadResult handleFood(
            UUID taskId, Long userId, String chatId,
            MultipartFile file, Map<String, String> userContext
    ) {
        if (file != null && !file.isEmpty()) {
            String ct = file.getContentType();
            if (ct == null || !ALLOWED_IMAGE_TYPES.contains(ct)) {
                return UploadResult.error("Only JPEG, PNG, WEBP, and HEIC images are accepted");
            }
        }
        String gcsUri      = gcsStorage.uploadFoodImage(file, userId);
        String imagePayload = (gcsUri != null) ? gcsUri : encodeFile(file);
        taskPublisher.publishFoodVision(taskId, userId, chatId, imagePayload, userContext);
        int estimatedSecs = 5;
        insertTask(taskId, userId, chatId, "FOOD", estimatedSecs);
        return UploadResult.accepted(taskId.toString(), estimatedSecs);
    }

    private UploadResult handleReport(
            UUID taskId, Long userId, String chatId, MultipartFile file
    ) {
        if (file != null && !file.isEmpty()) {
            String ct = file.getContentType();
            if (!"application/pdf".equals(ct)) {
                return UploadResult.error("Only PDF documents are accepted for medical reports");
            }
        }
        String gcsUri      = gcsStorage.uploadMedicalPdf(file, userId);
        String documentUrl = (gcsUri != null) ? gcsUri : encodeFile(file);
        taskPublisher.publishMedicalOcr(taskId, userId, chatId, documentUrl);
        int estimatedSecs = 15;
        insertTask(taskId, userId, chatId, "REPORT", estimatedSecs);
        return UploadResult.accepted(taskId.toString(), estimatedSecs);
    }

    private UploadResult handleText(
            UUID taskId, Long userId, String chatId,
            String message, Map<String, String> userContext
    ) {
        if (message != null && !message.isBlank()) {
            ParseProfileUpdateResponse parsed = aiServiceClient.parseProfileUpdate(message);
            if (parsed.isProfileUpdate() && parsed.fields() != null) {
                applyProfileUpdate(userId, parsed.fields());
                String confirmation = parsed.confirmationMessage() != null
                        ? parsed.confirmationMessage()
                        : "Got it! Your profile has been updated.";
                return UploadResult.profileUpdated(taskId.toString(), confirmation);
            }
        }
        taskPublisher.publishTextQuery(taskId, userId, message, userContext);
        int estimatedSecs = 3;
        insertTask(taskId, userId, chatId, "TEXT", estimatedSecs);
        return UploadResult.accepted(taskId.toString(), estimatedSecs);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Load user context for AI personalisation.
     * Prefers taste_profiles (richer) over the users table fallback.
     */
    Map<String, String> buildUserContext(Long userId) {
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
        } catch (Exception ignored) { /* taste_profiles not yet created — fall through */ }

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
            log.warn("Could not load user context for userId={}: {}", userId, e.getMessage());
            return Map.of(
                "region", "India", "cuisineStyle", "mixed", "dietaryRestrictions", "none",
                "healthGoal", "general wellness", "spicePreference", "medium", "stapleGrains", "rice/wheat"
            );
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
            log.debug("Task insert skipped (omni_chat_tasks may not exist): {}", e.getMessage());
        }
    }

    /** Apply parsed profile fields returned by the AI profile-update intent classifier. */
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

    /** Encode multipart file to base64 for embedding in RabbitMQ message (local-dev fallback). */
    private static String encodeFile(MultipartFile file) {
        if (file == null || file.isEmpty()) return "";
        try {
            return Base64.getEncoder().encodeToString(file.getBytes());
        } catch (Exception e) {
            return "";
        }
    }

    private static String str(java.util.Map<String, Object> m, String k) {
        Object v = m.get(k); return v != null ? v.toString() : null;
    }

    private static String nullOr(String value, String fallback) {
        return (value != null && !value.isBlank()) ? value : fallback;
    }

    private String  getString (Map<String, Object> f, String k) { Object v = f.get(k); return v instanceof String  s ? s : null; }
    private Double  getDouble (Map<String, Object> f, String k) { Object v = f.get(k); return v instanceof Number  n ? n.doubleValue() : null; }
    private Integer getInteger(Map<String, Object> f, String k) { Object v = f.get(k); return v instanceof Number  n ? n.intValue()    : null; }
}

package com.healthcoach.chat;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.ParseProfileUpdateResponse;
import com.healthcoach.messaging.TaskPublisher;
import com.healthcoach.security.JwtTokenProvider;
import com.healthcoach.user.UserService;
import com.healthcoach.user.dto.UpdateProfileRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;
import java.util.UUID;

/**
 * POST /api/v1/chat/upload
 *
 * The Omni-Chat entry point — receives text, food images, or medical PDFs
 * from the React Native app. Classifies the input type (FOOD | REPORT | TEXT)
 * and publishes an async task to RabbitMQ. Returns taskId immediately so the
 * mobile app can show a "processing" state.
 *
 * Special case for TEXT: if the AI engine detects a profile update intent
 * (e.g. "Update my weight to 75 kg"), the update is applied synchronously
 * and status "COMPLETED" is returned with the confirmation message — no
 * RabbitMQ task is published.
 *
 * For large files (PDFs), stores in GCS first, then publishes the GCS URL
 * (Claim Check Pattern) to avoid large message payloads in RabbitMQ.
 */
@RestController
@RequestMapping("/api/v1/chat")
public class OmniChatController {

    private final TaskPublisher taskPublisher;
    private final JwtTokenProvider jwtUtil;
    private final AiServiceClient aiServiceClient;
    private final UserService userService;

    public OmniChatController(
            TaskPublisher taskPublisher,
            JwtTokenProvider jwtUtil,
            AiServiceClient aiServiceClient,
            UserService userService
    ) {
        this.taskPublisher = taskPublisher;
        this.jwtUtil = jwtUtil;
        this.aiServiceClient = aiServiceClient;
        this.userService = userService;
    }

    @PostMapping("/upload")
    public ResponseEntity<Map<String, Object>> upload(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam("type")   String type,
            @RequestParam("chatId") String chatId,
            @RequestParam(value = "message", required = false) String message,
            @RequestParam(value = "file",    required = false) MultipartFile file
    ) {
        Long userId = jwtUtil.getUserIdFromToken(authHeader.replace("Bearer ", ""));
        UUID taskId = UUID.randomUUID();

        // Fetch user context for AI personalisation
        // (region, cuisineStyle, dietaryRestrictions — resolved from TasteProfile)
        Map<String, String> userContext = Map.of(
            "region",              "India",   // TODO: load from taste_profiles table
            "cuisineStyle",        "mixed",
            "dietaryRestrictions", "none"
        );

        int estimatedSecs;
        switch (type.toUpperCase()) {
            case "FOOD" -> {
                // TODO: upload file to GCS, get imageUrl
                String imageUrl = "gs://health-coach-uploads/" + taskId + ".jpg";
                taskPublisher.publishFoodVision(taskId, userId, chatId, imageUrl, userContext);
                estimatedSecs = 5;
            }
            case "REPORT" -> {
                // TODO: upload PDF to GCS, get documentUrl
                String documentUrl = "gs://health-coach-uploads/" + taskId + ".pdf";
                taskPublisher.publishMedicalOcr(taskId, userId, chatId, documentUrl);
                estimatedSecs = 15;
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
            }
        }

        return ResponseEntity.accepted().body(Map.of(
            "taskId",        taskId.toString(),
            "status",        "PROCESSING",
            "estimatedTime", estimatedSecs + "s"
        ));
    }

    /**
     * Apply parsed profile fields to the user record.
     * Weight (weightKg) is NOT in the User entity — it lives in body_metrics.
     * For now weight is acknowledged in the confirmation message only.
     */
    private void applyProfileUpdate(Long userId, Map<String, Object> fields) {
        Double heightCm = getDouble(fields, "heightCm");
        String region   = getString(fields, "region");
        String goal     = getString(fields, "healthGoal");
        String gender   = getString(fields, "gender");
        String cuisine  = getString(fields, "cuisineStyle");
        String dietary  = getString(fields, "dietaryRestrictions");
        Integer age     = getInteger(fields, "age");

        UpdateProfileRequest request = new UpdateProfileRequest(
            age, gender, heightCm, goal, null, null, region, cuisine, dietary
        );
        userService.updateProfile(userId, request);
    }

    private String getString(Map<String, Object> fields, String key) {
        Object v = fields.get(key);
        return v instanceof String s ? s : null;
    }

    private Double getDouble(Map<String, Object> fields, String key) {
        Object v = fields.get(key);
        if (v instanceof Number n) return n.doubleValue();
        return null;
    }

    private Integer getInteger(Map<String, Object> fields, String key) {
        Object v = fields.get(key);
        if (v instanceof Number n) return n.intValue();
        return null;
    }
}

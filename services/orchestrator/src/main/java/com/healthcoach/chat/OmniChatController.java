package com.healthcoach.chat;

import com.healthcoach.messaging.TaskPublisher;
import com.healthcoach.security.JwtTokenProvider;
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
 * For large files (PDFs), stores in GCS first, then publishes the GCS URL
 * (Claim Check Pattern) to avoid large message payloads in RabbitMQ.
 */
@RestController
@RequestMapping("/api/v1/chat")
public class OmniChatController {

    private final TaskPublisher taskPublisher;
    private final JwtTokenProvider jwtUtil;

    public OmniChatController(TaskPublisher taskPublisher, JwtTokenProvider jwtUtil) {
        this.taskPublisher = taskPublisher;
        this.jwtUtil = jwtUtil;
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
            default -> {  // TEXT
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
}

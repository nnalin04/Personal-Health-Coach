package com.healthcoach.chat;

import com.healthcoach.security.UserPrincipal;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

/**
 * POST /api/v1/chat/upload
 *
 * Thin HTTP adapter — delegates all orchestration to {@link OmniChatService}.
 * Translates the {@link UploadResult} value type to the appropriate HTTP response.
 */
@RestController
@RequestMapping("/api/v1/chat")
public class OmniChatController {

    private final OmniChatService omniChatService;

    public OmniChatController(OmniChatService omniChatService) {
        this.omniChatService = omniChatService;
    }

    @PostMapping("/upload")
    public ResponseEntity<Map<String, Object>> upload(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam("type")   String type,
            @RequestParam("chatId") String chatId,
            @RequestParam(value = "message", required = false) String message,
            @RequestParam(value = "file",    required = false) MultipartFile file
    ) {
        UploadResult result = omniChatService.handleUpload(
                currentUser.getId(), type, chatId, message, file
        );

        return switch (result.kind()) {
            case ERROR -> ResponseEntity.badRequest().body(
                    Map.of("error", result.message()));

            case PROFILE_UPDATED -> ResponseEntity.ok(Map.of(
                    "taskId",  result.taskId(),
                    "status",  "COMPLETED",
                    "message", result.message(),
                    "type",    "PROFILE_UPDATE"));

            case ACCEPTED -> ResponseEntity.accepted().body(Map.of(
                    "taskId",        result.taskId(),
                    "status",        "PROCESSING",
                    "estimatedTime", result.estimatedSecs() + "s"));
        };
    }
}

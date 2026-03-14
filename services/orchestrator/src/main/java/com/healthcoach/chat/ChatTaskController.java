package com.healthcoach.chat;

import com.healthcoach.security.UserPrincipal;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * GET /api/v1/chat/tasks/{taskId}
 *
 * Polled by the mobile app after receiving a PROCESSING response from
 * POST /api/v1/chat/upload. Returns the current task status and, when
 * COMPLETED, the result_json payload.
 *
 * The authenticated user must own the task (user_id check prevents enumeration).
 */
@RestController
@RequestMapping("/api/v1/chat")
public class ChatTaskController {

    private final JdbcTemplate jdbc;

    public ChatTaskController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/tasks/{taskId}")
    public ResponseEntity<Map<String, Object>> getTask(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable("taskId")  String taskId
    ) {
        Long userId = currentUser.getId();

        // Validate UUID format
        try { UUID.fromString(taskId); } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid taskId format"));
        }

        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT status, task_type, result_json, error_message, estimated_secs, created_at, completed_at " +
            "FROM omni_chat_tasks WHERE id = ?::uuid AND user_id = ?",
            taskId, userId
        );

        if (rows.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Map<String, Object> row = rows.get(0);
        String status = String.valueOf(row.get("status"));

        Map<String, Object> response = new java.util.LinkedHashMap<>();
        response.put("taskId",       taskId);
        response.put("status",       status);
        response.put("type",         row.get("task_type"));
        response.put("estimatedSecs", row.get("estimated_secs"));
        response.put("createdAt",    row.get("created_at"));
        response.put("completedAt",  row.get("completed_at"));

        if ("COMPLETED".equals(status) || "PARTIAL".equals(status)) {
            response.put("result", row.get("result_json"));
        }
        if ("FAILED".equals(status)) {
            response.put("error", row.get("error_message"));
        }

        return ResponseEntity.ok(response);
    }
}

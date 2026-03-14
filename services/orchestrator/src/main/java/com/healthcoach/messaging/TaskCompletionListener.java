package com.healthcoach.messaging;

import com.healthcoach.config.RabbitMqConfig;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.logging.Logger;

/**
 * Bridges the RabbitMQ task-completed-queue to WebSocket subscribers.
 *
 * Flow:
 *   AI Engine (Python) → publishes {taskId, userId, status, result} to RabbitMQ
 *   → This listener receives the message
 *   → Pushes to STOMP topic /topic/tasks/{userId}
 *   → Mobile client receives instant notification (no polling needed)
 *
 * The mobile app subscribes on connection:
 *   client.subscribe('/topic/tasks/' + userId, handler)
 */
@Component
public class TaskCompletionListener {

    private static final Logger log = Logger.getLogger(TaskCompletionListener.class.getName());

    private final SimpMessagingTemplate messagingTemplate;

    public TaskCompletionListener(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    @RabbitListener(queues = RabbitMqConfig.COMPLETED_QUEUE)
    public void onTaskCompleted(Map<String, Object> message) {
        String taskId = String.valueOf(message.getOrDefault("taskId", "unknown"));
        String userId = String.valueOf(message.getOrDefault("userId", "0"));
        String status = String.valueOf(message.getOrDefault("status",  "COMPLETED"));

        log.info("Task completed: taskId=" + taskId + " userId=" + userId + " status=" + status);

        // Push to the user-specific topic — mobile subscribes to this
        messagingTemplate.convertAndSend("/topic/tasks/" + userId, message);
    }
}

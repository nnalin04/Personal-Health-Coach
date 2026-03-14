package com.healthcoach.messaging;

import com.healthcoach.config.RabbitMqConfig;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Publishes async tasks to the health_os.tasks RabbitMQ exchange.
 *
 * The AI Engine (FastAPI) consumes these and pushes results back
 * via the omni_chat_tasks table + WebSocket notification.
 */
@Service
public class TaskPublisher {

    private final RabbitTemplate rabbitTemplate;

    public TaskPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    /**
     * Publish a food vision task — triggers Gemini Vision pipeline in AI Engine.
     *
     * @param taskId     UUID of the OmniChatTask row (already persisted)
     * @param userId     The authenticated user's ID
     * @param chatId     WatermelonDB chat session ID
     * @param imageUrl   GCS URL of the uploaded food photo
     * @param userContext region, cuisineStyle, dietaryRestrictions
     */
    public void publishFoodVision(UUID taskId, Long userId, String chatId,
                                  String imageUrl, Map<String, String> userContext) {
        Map<String, Object> payload = Map.of(
            "taskId",      taskId.toString(),
            "userId",      userId.toString(),
            "chatId",      chatId,
            "imageUrl",    imageUrl,
            "userContext", userContext,
            "timestamp",   Instant.now().toEpochMilli()
        );
        rabbitTemplate.convertAndSend(RabbitMqConfig.EXCHANGE, RabbitMqConfig.FOOD_KEY, payload);
    }

    /**
     * Publish a medical OCR task — triggers Document AI pipeline in AI Engine.
     * Uses Claim Check pattern: only the GCS URL is in the message body.
     *
     * @param taskId      UUID of the OmniChatTask row
     * @param userId      The authenticated user's ID
     * @param chatId      WatermelonDB chat session ID
     * @param documentUrl GCS URL of the uploaded medical PDF
     */
    public void publishMedicalOcr(UUID taskId, Long userId, String chatId, String documentUrl) {
        Map<String, Object> payload = Map.of(
            "taskId",      taskId.toString(),
            "userId",      userId.toString(),
            "chatId",      chatId,
            "documentUrl", documentUrl,
            "config",      Map.of("extractEntities", true, "normalizeUnits", true),
            "timestamp",   Instant.now().toEpochMilli()
        );
        rabbitTemplate.convertAndSend(RabbitMqConfig.EXCHANGE, RabbitMqConfig.MEDICAL_KEY, payload);
    }

    /**
     * Publish a RAG text-query task from OmniChat.
     * Uses the same taskId that was already persisted to omni_chat_tasks so the
     * WS notification lands on the correct polling slot in the mobile app.
     *
     * @param taskId     UUID already persisted to omni_chat_tasks
     * @param userId     The authenticated user's ID
     * @param message    Raw user text query
     * @param userContext region, cuisineStyle, dietaryRestrictions
     */
    public void publishTextQuery(UUID taskId, Long userId, String message,
                                 Map<String, String> userContext) {
        Map<String, Object> payload = Map.of(
            "taskId",      taskId.toString(),
            "userId",      userId.toString(),
            "message",     message != null ? message : "",
            "userContext", userContext,
            "timestamp",   Instant.now().toEpochMilli()
        );
        rabbitTemplate.convertAndSend(RabbitMqConfig.EXCHANGE, RabbitMqConfig.RAG_KEY, payload);
    }

    /**
     * Publish a RAG insight task triggered by internal events (not user queries).
     * Generates its own taskId since there is no omni_chat_tasks row for these.
     *
     * @param userId            The authenticated user's ID
     * @param triggerEvent      "meal_logged" | "report_processed" | "daily_summary"
     * @param deficiencyMarkers nutrients currently below threshold
     */
    public void publishRagInsight(Long userId, String triggerEvent, java.util.List<String> deficiencyMarkers) {
        Map<String, Object> payload = Map.of(
            "taskId",             UUID.randomUUID().toString(),
            "userId",             userId.toString(),
            "triggerEvent",       triggerEvent,
            "deficiencyMarkers",  deficiencyMarkers,
            "timestamp",          Instant.now().toEpochMilli()
        );
        rabbitTemplate.convertAndSend(RabbitMqConfig.EXCHANGE, RabbitMqConfig.RAG_KEY, payload);
    }
}

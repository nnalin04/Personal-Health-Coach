package com.healthcoach.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Spring Boot health indicator for the FastAPI AI service.
 * Exposed via GET /actuator/health as the "aiService" component.
 */
@Component("aiService")
public class AiServiceHealthIndicator implements HealthIndicator {

    private final String aiBaseUrl;
    private final RestClient restClient;

    public AiServiceHealthIndicator(
            @Value("${app.ai.base-url}") String aiBaseUrl
    ) {
        this.aiBaseUrl = aiBaseUrl;
        this.restClient = RestClient.builder()
                .baseUrl(aiBaseUrl)
                .build();
    }

    @Override
    public Health health() {
        try {
            String response = restClient.get()
                    .uri("/health")
                    .retrieve()
                    .onStatus(status -> !status.is2xxSuccessful(),
                            (req, res) -> { throw new RuntimeException("AI service returned " + res.getStatusCode()); })
                    .body(String.class);

            return Health.up()
                    .withDetail("url", aiBaseUrl)
                    .withDetail("response", response)
                    .build();
        } catch (Exception ex) {
            return Health.down()
                    .withDetail("url", aiBaseUrl)
                    .withDetail("error", ex.getMessage())
                    .build();
        }
    }
}

package com.healthcoach.aiclient;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

/**
 * Transparent proxy for AI-service endpoints that the mobile client calls directly.
 * nginx routes all traffic to Spring Boot; the AI service is internal-only.
 * These endpoints forward the request as-is to the AI service and return its response.
 */
@RestController
@RequestMapping("/api")
public class AiProxyController {

    private final RestTemplate restTemplate;
    private final String aiBaseUrl;

    public AiProxyController(RestTemplate restTemplate, @Value("${app.ai.base-url}") String aiBaseUrl) {
        this.restTemplate = restTemplate;
        this.aiBaseUrl = aiBaseUrl;
    }

    @PostMapping("/food/analyze-nutrients")
    public Map analyzeNutrients(@RequestBody Map<String, Object> request) {
        return restTemplate.postForObject(aiBaseUrl + "/food/analyze-nutrients", request, Map.class);
    }

}

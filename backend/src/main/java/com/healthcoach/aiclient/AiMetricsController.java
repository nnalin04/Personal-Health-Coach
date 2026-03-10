package com.healthcoach.aiclient;

import com.healthcoach.aiclient.dto.ExtractMetricsRequest;
import com.healthcoach.aiclient.dto.ExtractMetricsResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class AiMetricsController {

    private final AiServiceClient aiServiceClient;

    public AiMetricsController(AiServiceClient aiServiceClient) {
        this.aiServiceClient = aiServiceClient;
    }

    @PostMapping("/extract-metrics")
    public ExtractMetricsResponse extractMetrics(@Valid @RequestBody ExtractMetricsRequest request) {
        return aiServiceClient.extractMetrics(request.text());
    }
}

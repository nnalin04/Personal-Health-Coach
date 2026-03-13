package com.healthcoach.healthsummary;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.AiHealthResponse;
import com.healthcoach.security.UserPrincipal;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/health-summary")
public class HealthSummaryController {

    private final HealthSummaryService healthSummaryService;
    private final AiServiceClient aiServiceClient;

    public HealthSummaryController(HealthSummaryService healthSummaryService, AiServiceClient aiServiceClient) {
        this.healthSummaryService = healthSummaryService;
        this.aiServiceClient = aiServiceClient;
    }

    @GetMapping("/me")
    public Map<String, Object> getMySummary(@AuthenticationPrincipal UserPrincipal principal) {
        return healthSummaryService.buildSummary(principal.getId());
    }

    @PostMapping("/me/ai-insights")
    public Map<String, Object> getMyAiInsights(@AuthenticationPrincipal UserPrincipal principal) {
        Map<String, Object> summary = healthSummaryService.buildSummary(principal.getId());
        AiHealthResponse insights = aiServiceClient.analyzeHealth(summary);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("summary", summary);
        response.put("ai_insights", insights);
        return response;
    }
}

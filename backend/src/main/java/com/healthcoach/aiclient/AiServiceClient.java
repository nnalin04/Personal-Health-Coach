package com.healthcoach.aiclient;

import com.healthcoach.aiclient.dto.AiHealthResponse;
import com.healthcoach.aiclient.dto.AnalyzeHealthRequest;
import com.healthcoach.aiclient.dto.ExtractMetricsRequest;
import com.healthcoach.aiclient.dto.ExtractMetricsResponse;
import com.healthcoach.aiclient.dto.ParseMedicalReportRequest;
import com.healthcoach.aiclient.dto.ParseMedicalReportResponse;
import com.healthcoach.aiclient.dto.ParsedLabValues;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

@Service
public class AiServiceClient {

    private final RestTemplate restTemplate;
    private final String aiBaseUrl;

    public AiServiceClient(RestTemplate restTemplate, @Value("${app.ai.base-url}") String aiBaseUrl) {
        this.restTemplate = restTemplate;
        this.aiBaseUrl = aiBaseUrl;
    }

    public AiHealthResponse analyzeHealth(Map<String, Object> summary) {
        try {
            AnalyzeHealthRequest request = new AnalyzeHealthRequest(summary);
            AiHealthResponse response = restTemplate.postForObject(
                    aiBaseUrl + "/analyze-health",
                    request,
                    AiHealthResponse.class
            );
            if (response == null) {
                return defaultInsights();
            }
            return response;
        } catch (RestClientException ex) {
            return defaultInsights();
        }
    }

    public ExtractMetricsResponse extractMetrics(String text) {
        try {
            ExtractMetricsRequest request = new ExtractMetricsRequest(text);
            ExtractMetricsResponse response = restTemplate.postForObject(
                    aiBaseUrl + "/extract-metrics",
                    request,
                    ExtractMetricsResponse.class
            );
            if (response == null) {
                return new ExtractMetricsResponse(Collections.emptyList(), text);
            }
            return response;
        } catch (RestClientException ex) {
            return new ExtractMetricsResponse(Collections.emptyList(), text);
        }
    }

    public ParseMedicalReportResponse parseMedicalReport(String fileName, String fileBase64, String extractedText) {
        try {
            ParseMedicalReportRequest request = new ParseMedicalReportRequest(fileName, fileBase64, extractedText);
            ParseMedicalReportResponse response = restTemplate.postForObject(
                    aiBaseUrl + "/parse-medical-report",
                    request,
                    ParseMedicalReportResponse.class
            );
            if (response == null) {
                return new ParseMedicalReportResponse(emptyParsedLabValues(),
                        List.of("No parsed output from AI parser"));
            }
            return response;
        } catch (RestClientException ex) {
            return new ParseMedicalReportResponse(emptyParsedLabValues(),
                    List.of("AI parser unavailable; report stored without extracted labs"));
        }
    }

    private AiHealthResponse defaultInsights() {
        return new AiHealthResponse(
                List.of("Increase whole-food protein intake spread across meals."),
                List.of("Prioritize 3-4 resistance sessions per week with progressive overload."),
                List.of("Maintain 7-9 hours of sleep and one lighter training day weekly."),
                List.of("Track trends and discuss persistent abnormalities with your clinician."),
                "This is educational guidance only and not a diagnosis."
        );
    }

    private ParsedLabValues emptyParsedLabValues() {
        return new ParsedLabValues(
                null, null, null, null, null, null, null, null,
                null, null, null, null
        );
    }
}

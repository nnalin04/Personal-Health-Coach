package com.healthcoach.aiclient;

import com.healthcoach.aiclient.dto.AiHealthResponse;
import com.healthcoach.aiclient.dto.AnalyzeHealthRequest;
import com.healthcoach.aiclient.dto.ExtractMetricsRequest;
import com.healthcoach.aiclient.dto.ExtractMetricsResponse;
import com.healthcoach.aiclient.dto.NutrientAnalyzeRequest;
import com.healthcoach.aiclient.dto.NutrientAnalyzeResponse;
import com.healthcoach.aiclient.dto.NutrientRecommendationRequest;
import com.healthcoach.aiclient.dto.NutrientRecommendationResponse;
import com.healthcoach.aiclient.dto.ParseMedicalReportRequest;
import com.healthcoach.aiclient.dto.ParseMedicalReportResponse;
import com.healthcoach.aiclient.dto.ParseProfileUpdateRequest;
import com.healthcoach.aiclient.dto.ParseProfileUpdateResponse;
import com.healthcoach.aiclient.dto.ParsedLabValues;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

@Service
public class AiServiceClient {

    private static final Logger logger = Logger.getLogger(AiServiceClient.class.getName());

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

    public NutrientAnalyzeResponse analyzeNutrients(String foodDescription, String region, String cuisineStyle, String dietary) {
        try {
            NutrientAnalyzeRequest request = new NutrientAnalyzeRequest(foodDescription, region, cuisineStyle, dietary);
            NutrientAnalyzeResponse response = restTemplate.postForObject(
                aiBaseUrl + "/food/analyze-nutrients",
                request,
                NutrientAnalyzeResponse.class
            );
            return response != null ? response : emptyNutrientResponse();
        } catch (RestClientException ex) {
            return emptyNutrientResponse();
        }
    }

    public NutrientRecommendationResponse getNutrientRecommendations(
            List<Map<String, Object>> deficiencyProfile,
            String foodHistorySummary,
            Map<String, Object> userContext) {
        try {
            NutrientRecommendationRequest request = new NutrientRecommendationRequest(deficiencyProfile, foodHistorySummary, userContext);
            NutrientRecommendationResponse response = restTemplate.postForObject(
                aiBaseUrl + "/nutrient/recommendations",
                request,
                NutrientRecommendationResponse.class
            );
            return response != null ? response : emptyRecommendationResponse();
        } catch (RestClientException ex) {
            return emptyRecommendationResponse();
        }
    }

    /**
     * Call AI engine to classify and parse a natural-language profile update.
     * Returns a non-null response; isProfileUpdate=false on any failure.
     */
    public ParseProfileUpdateResponse parseProfileUpdate(String message) {
        try {
            ParseProfileUpdateRequest request = new ParseProfileUpdateRequest(message);
            ParseProfileUpdateResponse response = restTemplate.postForObject(
                    aiBaseUrl + "/api/v1/chat/parse-profile-update",
                    request,
                    ParseProfileUpdateResponse.class
            );
            return response != null ? response : new ParseProfileUpdateResponse(false, null, null);
        } catch (RestClientException ex) {
            logger.warning("Profile update parsing unavailable: " + ex.getMessage());
            return new ParseProfileUpdateResponse(false, null, null);
        }
    }

    private NutrientAnalyzeResponse emptyNutrientResponse() {
        return new NutrientAnalyzeResponse(Collections.emptyList(), Collections.emptyMap(),
                null, null, null, null, "AI analysis unavailable");
    }

    private NutrientRecommendationResponse emptyRecommendationResponse() {
        return new NutrientRecommendationResponse(Collections.emptyList(), Collections.emptyList(), Collections.emptyList());
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

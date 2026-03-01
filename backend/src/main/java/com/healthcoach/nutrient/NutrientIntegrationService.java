package com.healthcoach.nutrient;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.NutrientAnalyzeResponse;
import com.healthcoach.food.FoodLog;
import com.healthcoach.user.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Map;

@Service
public class NutrientIntegrationService {

    private static final Logger log = LoggerFactory.getLogger(NutrientIntegrationService.class);

    private final AiServiceClient aiServiceClient;
    private final NutrientLogRepository nutrientLogRepository;

    public NutrientIntegrationService(AiServiceClient aiServiceClient, NutrientLogRepository nutrientLogRepository) {
        this.aiServiceClient = aiServiceClient;
        this.nutrientLogRepository = nutrientLogRepository;
    }

    @Async
    public void analyzeAndSaveAsync(FoodLog foodLog, User user) {
        try {
            String description = foodLog.getFoodName();
            String region = user.getRegion() != null ? user.getRegion() : "India";
            String cuisine = user.getCuisineStyle() != null ? user.getCuisineStyle() : "mixed";
            String dietary = user.getDietaryRestrictions() != null ? user.getDietaryRestrictions() : "none";

            NutrientAnalyzeResponse response = aiServiceClient.analyzeNutrients(description, region, cuisine, dietary);

            if (response == null || response.nutrients() == null) return;

            NutrientLog nutrientLog = new NutrientLog();
            nutrientLog.setUser(user);
            nutrientLog.setFoodLogId(foodLog.getId());
            nutrientLog.setLogDate(foodLog.getDate());
            nutrientLog.setFoodDescription(description);
            nutrientLog.setConfidence(null);

            @SuppressWarnings("unchecked")
            Map<String, Object> vitamins = (Map<String, Object>) response.nutrients().get("vitamins");
            @SuppressWarnings("unchecked")
            Map<String, Object> minerals = (Map<String, Object>) response.nutrients().get("minerals");

            if (vitamins != null) {
                nutrientLog.setVitaminAMcg(toDouble(vitamins.get("a_mcg")));
                nutrientLog.setVitaminB1Mg(toDouble(vitamins.get("b1_mg")));
                nutrientLog.setVitaminB2Mg(toDouble(vitamins.get("b2_mg")));
                nutrientLog.setVitaminB3Mg(toDouble(vitamins.get("b3_mg")));
                nutrientLog.setVitaminB6Mg(toDouble(vitamins.get("b6_mg")));
                nutrientLog.setVitaminB9Mcg(toDouble(vitamins.get("b9_mcg")));
                nutrientLog.setVitaminB12Mcg(toDouble(vitamins.get("b12_mcg")));
                nutrientLog.setVitaminCMg(toDouble(vitamins.get("c_mg")));
                nutrientLog.setVitaminDMcg(toDouble(vitamins.get("d_mcg")));
                nutrientLog.setVitaminEMg(toDouble(vitamins.get("e_mg")));
                nutrientLog.setVitaminKMcg(toDouble(vitamins.get("k_mcg")));
            }
            if (minerals != null) {
                nutrientLog.setCalciumMg(toDouble(minerals.get("calcium_mg")));
                nutrientLog.setIronMg(toDouble(minerals.get("iron_mg")));
                nutrientLog.setZincMg(toDouble(minerals.get("zinc_mg")));
                nutrientLog.setMagnesiumMg(toDouble(minerals.get("magnesium_mg")));
                nutrientLog.setPotassiumMg(toDouble(minerals.get("potassium_mg")));
                nutrientLog.setSeleniumMcg(toDouble(minerals.get("selenium_mcg")));
                nutrientLog.setIodineMcg(toDouble(minerals.get("iodine_mcg")));
            }

            nutrientLogRepository.save(nutrientLog);
        } catch (Exception e) {
            log.warn("Async nutrient analysis failed for foodLog {}: {}", foodLog.getId(), e.getMessage());
        }
    }

    private Double toDouble(Object value) {
        if (value == null) return null;
        if (value instanceof Number n) return n.doubleValue();
        try { return Double.parseDouble(value.toString()); } catch (NumberFormatException e) { return null; }
    }
}

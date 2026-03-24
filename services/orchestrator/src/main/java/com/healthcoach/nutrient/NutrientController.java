package com.healthcoach.nutrient;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.food.FoodLog;
import com.healthcoach.food.FoodLogRepository;
import com.healthcoach.nutrient.dto.*;
import com.healthcoach.security.UserPrincipal;
import com.healthcoach.user.User;
import com.healthcoach.user.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/nutrient")
public class NutrientController {

    private final NutrientLogService service;
    private final UserRepository userRepo;
    private final AiServiceClient aiServiceClient;
    private final FoodLogRepository foodLogRepo;

    public NutrientController(NutrientLogService service, UserRepository userRepo, AiServiceClient aiServiceClient, FoodLogRepository foodLogRepo) {
        this.service = service;
        this.userRepo = userRepo;
        this.aiServiceClient = aiServiceClient;
        this.foodLogRepo = foodLogRepo;
    }

    @GetMapping("/daily-summary")
    public ResponseEntity<NutrientSummaryDTO> getDailySummary(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        User user = userRepo.findById(principal.getId())
            .orElseThrow(() -> new RuntimeException("User not found"));
        LocalDate targetDate = date != null ? date : LocalDate.now();
        return ResponseEntity.ok(service.getDailySummary(user, targetDate));
    }

    @GetMapping("/weekly-trends")
    public ResponseEntity<WeeklyNutrientTrendDTO> getWeeklyTrends(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        User user = userRepo.findById(principal.getId())
            .orElseThrow(() -> new RuntimeException("User not found"));
        LocalDate endDate = to != null ? to : LocalDate.now();
        return ResponseEntity.ok(service.getWeeklyTrend(user, endDate));
    }

    @PostMapping("/recommendations")
    public ResponseEntity<Map<String, Object>> getRecommendations(
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepo.findById(principal.getId())
            .orElseThrow(() -> new RuntimeException("User not found"));

        // Get 7-day trends for deficiency data
        WeeklyNutrientTrendDTO trend = service.getWeeklyTrend(user, LocalDate.now());

        // Build deficiency profile from chronic deficiencies
        List<Map<String, Object>> deficiencyProfile = trend.chronicDeficiencies().stream().map(key -> {
            double avgPct = trend.weeklyAvgPercentOfRda().getOrDefault(key, 0.0);
            Map<String, Object> entry = new java.util.LinkedHashMap<>();
            entry.put("nutrient", key);
            entry.put("avg_percent_rda", avgPct);
            entry.put("days_deficient", 7); // simplification
            return entry;
        }).collect(java.util.stream.Collectors.toList());

        // Build food history summary from recent food logs
        List<com.healthcoach.food.FoodLog> recentFood = foodLogRepo
                .findByUserId(user.getId(), PageRequest.of(0, 14, Sort.by(Sort.Direction.DESC, "date")))
                .getContent();
        String foodSummary = recentFood.stream()
            .limit(14)
            .map(f -> f.getFoodName() + " (" + f.getMealType() + ")")
            .collect(java.util.stream.Collectors.joining(", "));

        // Build user context
        Map<String, Object> userContext = new java.util.LinkedHashMap<>();
        userContext.put("region", user.getRegion() != null ? user.getRegion() : "India");
        userContext.put("cuisine_style", user.getCuisineStyle() != null ? user.getCuisineStyle() : "mixed");
        userContext.put("dietary_restrictions", user.getDietaryRestrictions() != null ? user.getDietaryRestrictions() : "none");
        userContext.put("gender", user.getGender() != null ? user.getGender() : "unknown");
        userContext.put("age", user.getAge() != null ? user.getAge().toString() : "adult");

        var aiResponse = aiServiceClient.getNutrientRecommendations(deficiencyProfile, foodSummary, userContext);

        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("deficiencyInsights", aiResponse.deficiencyInsights());
        result.put("foodRecommendations", aiResponse.foodRecommendations());
        result.put("supplementSuggestions", aiResponse.supplementSuggestions());
        result.put("chronicDeficiencies", trend.chronicDeficiencies());

        return ResponseEntity.ok(result);
    }
}

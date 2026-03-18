package com.healthcoach.food;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.NutrientAnalyzeResponse;
import com.healthcoach.nutrient.NutrientIntegrationService;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.food.dto.FoodLogRequest;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

@Service
public class FoodService {

    private final FoodLogRepository foodLogRepository;
    private final UserService userService;
    private final NutrientIntegrationService nutrientIntegrationService;
    private final AiServiceClient aiServiceClient;

    public FoodService(FoodLogRepository foodLogRepository, UserService userService,
                       NutrientIntegrationService nutrientIntegrationService,
                       AiServiceClient aiServiceClient) {
        this.foodLogRepository = foodLogRepository;
        this.userService = userService;
        this.nutrientIntegrationService = nutrientIntegrationService;
        this.aiServiceClient = aiServiceClient;
    }

    public FoodLog create(Long userId, FoodLogRequest request) {
        User user = userService.getById(userId);

        double protein  = request.protein();
        double carbs    = request.carbs();
        double fats     = request.fats();
        double calories = request.calories();

        // When the user provides no nutrition data, ask AI to estimate macros
        // from the food description so that dashboard metrics are populated.
        if (protein == 0 && carbs == 0 && fats == 0 && calories == 0) {
            try {
                String region   = user.getRegion()               != null ? user.getRegion()               : "India";
                String cuisine  = user.getCuisineStyle()          != null ? user.getCuisineStyle()          : "mixed";
                String dietary  = user.getDietaryRestrictions()   != null ? user.getDietaryRestrictions()   : "none";
                NutrientAnalyzeResponse est = aiServiceClient.analyzeNutrients(
                        request.foodName(), region, cuisine, dietary);
                if (est.proteinG()     != null) protein  = est.proteinG();
                if (est.carbsG()       != null) carbs    = est.carbsG();
                if (est.fatsG()        != null) fats     = est.fatsG();
                if (est.totalCalories() != null && est.totalCalories() > 0)
                    calories = est.totalCalories();
            } catch (Exception ignored) {
                // AI unavailable — save with zero macros rather than fail the request
            }
        }

        FoodLog log = new FoodLog();
        log.setUser(user);
        log.setMealType(request.mealType());
        log.setFoodName(request.foodName());
        log.setProtein(protein);
        log.setCarbs(carbs);
        log.setFats(fats);
        log.setCalories(calories);
        log.setDate(request.date());
        FoodLog saved = foodLogRepository.save(log);
        nutrientIntegrationService.analyzeAndSaveAsync(saved, user);
        return saved;
    }

    public Page<FoodLog> getByUser(Long userId, LocalDate from, LocalDate to, int page, int size) {
        PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "date"));
        if (from == null && to == null) {
            return foodLogRepository.findByUserId(userId, pageable);
        }
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end   = to   != null ? to   : LocalDate.now().plusDays(1);
        return foodLogRepository.findByUserIdAndDateBetween(userId, start, end, pageable);
    }

    /** Unbounded list for internal use (HealthSummaryService — already bounded by 90-day date range). */
    public List<FoodLog> getByUserUnbounded(Long userId, LocalDate from, LocalDate to) {
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end   = to   != null ? to   : LocalDate.now().plusDays(1);
        return foodLogRepository.findByUserIdAndDateBetween(userId, start, end);
    }
}

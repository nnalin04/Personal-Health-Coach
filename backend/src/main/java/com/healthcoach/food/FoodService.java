package com.healthcoach.food;

import com.healthcoach.nutrient.NutrientIntegrationService;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.food.dto.FoodLogRequest;
import java.time.LocalDate;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class FoodService {

    private final FoodLogRepository foodLogRepository;
    private final UserService userService;
    private final NutrientIntegrationService nutrientIntegrationService;

    public FoodService(FoodLogRepository foodLogRepository, UserService userService, NutrientIntegrationService nutrientIntegrationService) {
        this.foodLogRepository = foodLogRepository;
        this.userService = userService;
        this.nutrientIntegrationService = nutrientIntegrationService;
    }

    public FoodLog create(Long userId, FoodLogRequest request) {
        User user = userService.getById(userId);
        FoodLog log = new FoodLog();
        log.setUser(user);
        log.setMealType(request.mealType());
        log.setFoodName(request.foodName());
        log.setProtein(request.protein());
        log.setCarbs(request.carbs());
        log.setFats(request.fats());
        log.setCalories(request.calories());
        log.setDate(request.date());
        FoodLog saved = foodLogRepository.save(log);
        nutrientIntegrationService.analyzeAndSaveAsync(saved, user);
        return saved;
    }

    public List<FoodLog> getByUser(Long userId, LocalDate from, LocalDate to) {
        if (from == null && to == null) {
            return foodLogRepository.findByUserIdOrderByDateDesc(userId);
        }
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end = to != null ? to : LocalDate.now().plusDays(1);
        return foodLogRepository.findByUserIdAndDateBetween(userId, start, end);
    }
}

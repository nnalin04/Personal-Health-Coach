package com.healthcoach.food;

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

    public FoodService(FoodLogRepository foodLogRepository, UserService userService) {
        this.foodLogRepository = foodLogRepository;
        this.userService = userService;
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
        return foodLogRepository.save(log);
    }

    public List<FoodLog> getByUser(Long userId, LocalDate from, LocalDate to) {
        if (from != null && to != null) {
            return foodLogRepository.findByUserIdAndDateBetween(userId, from, to);
        }
        return foodLogRepository.findByUserIdOrderByDateDesc(userId);
    }
}

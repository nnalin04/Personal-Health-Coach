package com.healthcoach.food;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.NutrientAnalyzeResponse;
import com.healthcoach.nutrient.NutrientIntegrationService;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.food.dto.FoodLogRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;

@ExtendWith(MockitoExtension.class)
class FoodServiceTest {

    @Mock private FoodLogRepository foodLogRepository;
    @Mock private UserService userService;
    @Mock private NutrientIntegrationService nutrientIntegrationService;
    @Mock private AiServiceClient aiServiceClient;

    private FoodService foodService;

    @BeforeEach
    void setUp() {
        foodService = new FoodService(foodLogRepository, userService, nutrientIntegrationService, aiServiceClient);
    }

    @Test
    void create_ValidRequest_SavesLogAndTriggersNutrientAnalysis() {
        User user = new User();
        user.setId(1L);
        when(userService.getById(1L)).thenReturn(user);

        FoodLog saved = new FoodLog();
        saved.setFoodName("Chicken Rice");
        saved.setCalories(400.0);
        when(foodLogRepository.save(any())).thenReturn(saved);

        FoodLogRequest req = new FoodLogRequest("Lunch", "Chicken Rice", 30.0, 50.0, 10.0, 400.0, LocalDate.now());
        FoodLog result = foodService.create(1L, req);

        assertNotNull(result);
        assertEquals("Chicken Rice", result.getFoodName());
        verify(foodLogRepository).save(any(FoodLog.class));
        verify(nutrientIntegrationService).analyzeAndSaveAsync(eq(saved), eq(user));
        // Macros already provided — AI should NOT be called
        verify(aiServiceClient, never()).analyzeNutrients(any(), any(), any(), any());
    }

    @Test
    void create_ZeroMacros_AutoEstimatesViAI() {
        User user = new User();
        user.setId(1L);
        when(userService.getById(1L)).thenReturn(user);

        NutrientAnalyzeResponse estimate = new NutrientAnalyzeResponse(
                null, null, 25.0, 80.0, 15.0, 560.0, "AI estimate");
        when(aiServiceClient.analyzeNutrients(eq("Veg biryani"), any(), any(), any()))
                .thenReturn(estimate);

        FoodLog saved = new FoodLog();
        saved.setFoodName("Veg biryani");
        saved.setCalories(560.0);
        when(foodLogRepository.save(any())).thenReturn(saved);

        FoodLogRequest req = new FoodLogRequest("Lunch", "Veg biryani", 0.0, 0.0, 0.0, 0.0, LocalDate.now());
        foodService.create(1L, req);

        verify(aiServiceClient).analyzeNutrients(eq("Veg biryani"), any(), any(), any());
        verify(foodLogRepository).save(argThat(log ->
                log.getCalories() == 560.0 && log.getProtein() == 25.0
        ));
    }

    @Test
    void getByUser_NoDates_ReturnsAllRecordsWithoutDateFilter() {
        when(foodLogRepository.findByUserIdOrderByDateDesc(1L)).thenReturn(Collections.emptyList());

        List<FoodLog> result = foodService.getByUser(1L, null, null);

        assertNotNull(result);
        verify(foodLogRepository).findByUserIdOrderByDateDesc(1L);
        verify(foodLogRepository, never()).findByUserIdAndDateBetween(anyLong(), any(), any());
    }

    @Test
    void getByUser_WithBothDates_UsesDateBetween() {
        LocalDate from = LocalDate.now().minusDays(7);
        LocalDate to = LocalDate.now();
        when(foodLogRepository.findByUserIdAndDateBetween(1L, from, to)).thenReturn(Collections.emptyList());

        foodService.getByUser(1L, from, to);

        verify(foodLogRepository).findByUserIdAndDateBetween(1L, from, to);
        verify(foodLogRepository, never()).findByUserIdOrderByDateDesc(anyLong());
    }

    @Test
    void getByUser_OnlyFromDate_DefaultsEndToFuture() {
        LocalDate from = LocalDate.now().minusDays(7);

        foodService.getByUser(1L, from, null);

        verify(foodLogRepository).findByUserIdAndDateBetween(eq(1L), eq(from), any(LocalDate.class));
    }
}

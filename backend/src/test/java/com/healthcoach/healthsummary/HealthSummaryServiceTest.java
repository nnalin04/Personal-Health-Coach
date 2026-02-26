package com.healthcoach.healthsummary;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;

import com.healthcoach.bodymetrics.BodyMetricsRepository;
import com.healthcoach.food.FoodLogRepository;
import com.healthcoach.workout.WorkoutLogRepository;
import com.healthcoach.medical.LabValuesRepository;
import com.healthcoach.steps.StepsLogRepository;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Collections;
import java.util.Map;

@ExtendWith(MockitoExtension.class)
class HealthSummaryServiceTest {

    @Mock
    private FoodLogRepository foodLogRepository;
    @Mock
    private WorkoutLogRepository workoutLogRepository;
    @Mock
    private BodyMetricsRepository bodyMetricsRepository;
    @Mock
    private StepsLogRepository stepsLogRepository;
    @Mock
    private LabValuesRepository labValuesRepository;
    @Mock
    private UserService userService;

    private HealthSummaryService healthSummaryService;

    @BeforeEach
    void setUp() {
        healthSummaryService = new HealthSummaryService(
                userService,
                foodLogRepository,
                workoutLogRepository,
                bodyMetricsRepository,
                stepsLogRepository,
                labValuesRepository);
    }

    @Test
    void buildSummary_Success() {
        User user = new User();
        user.setId(1L);
        user.setEmail("test@example.com");

        when(userService.getById(anyLong())).thenReturn(user);
        when(foodLogRepository.findByUserIdAndDateBetween(anyLong(), any(), any())).thenReturn(Collections.emptyList());
        when(workoutLogRepository.findByUserIdAndDateBetween(anyLong(), any(), any()))
                .thenReturn(Collections.emptyList());
        when(bodyMetricsRepository.findByUserIdAndDateBetweenOrderByDateAsc(anyLong(), any(), any()))
                .thenReturn(Collections.emptyList());
        when(stepsLogRepository.findByUserIdAndDateBetween(anyLong(), any(), any()))
                .thenReturn(Collections.emptyList());
        when(labValuesRepository.findByReportUserIdOrderByReportReportDateAsc(anyLong()))
                .thenReturn(Collections.emptyList());

        Map<String, Object> summary = healthSummaryService.buildSummary(1L);

        assertNotNull(summary);
        assertTrue(summary.containsKey("profile"));
        assertTrue(summary.containsKey("nutrition_summary"));
        assertTrue(summary.containsKey("training_summary"));
        assertTrue(summary.containsKey("weight_trend"));
        assertTrue(summary.containsKey("medical_trends"));
        assertTrue(summary.containsKey("risk_flags"));
    }
}

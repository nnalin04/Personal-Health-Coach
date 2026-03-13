package com.healthcoach.user;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.healthcoach.bodymetrics.BodyMetricsRepository;
import com.healthcoach.common.ResourceNotFoundException;
import com.healthcoach.food.FoodLogRepository;
import com.healthcoach.goals.HealthGoalRepository;
import com.healthcoach.medical.MedicalReportRepository;
import com.healthcoach.nutrient.NutrientLogRepository;
import com.healthcoach.steps.StepsLogRepository;
import com.healthcoach.user.dto.UpdateProfileRequest;
import com.healthcoach.user.dto.UserDataExportDto;
import com.healthcoach.workout.WorkoutLogRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Collections;
import java.util.Optional;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock private UserRepository userRepository;
    @Mock private WorkoutLogRepository workoutLogRepository;
    @Mock private FoodLogRepository foodLogRepository;
    @Mock private BodyMetricsRepository bodyMetricsRepository;
    @Mock private StepsLogRepository stepsLogRepository;
    @Mock private MedicalReportRepository medicalReportRepository;
    @Mock private HealthGoalRepository healthGoalRepository;
    @Mock private NutrientLogRepository nutrientLogRepository;

    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(
                userRepository, workoutLogRepository, foodLogRepository,
                bodyMetricsRepository, stepsLogRepository, medicalReportRepository,
                healthGoalRepository, nutrientLogRepository
        );
    }

    @Test
    void getById_ExistingUser_ReturnsUser() {
        User user = new User();
        user.setId(1L);
        user.setEmail("test@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        User result = userService.getById(1L);

        assertNotNull(result);
        assertEquals("test@example.com", result.getEmail());
    }

    @Test
    void getById_NonExistentUser_ThrowsResourceNotFoundException() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> userService.getById(99L));
    }

    @Test
    void updateProfile_PartialUpdate_OnlyChangesProvidedFields() {
        User existing = new User();
        existing.setId(1L);
        existing.setAge(25);
        existing.setGender("Male");
        when(userRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UpdateProfileRequest req = new UpdateProfileRequest(30, null, null, null, null, null, null, null, null);
        User updated = userService.updateProfile(1L, req);

        assertEquals(30, updated.getAge());
        assertEquals("Male", updated.getGender()); // unchanged
    }

    @Test
    void deleteAccount_ExistingUser_DeletesById() {
        when(userRepository.existsById(1L)).thenReturn(true);

        userService.deleteAccount(1L);

        verify(userRepository).deleteById(1L);
    }

    @Test
    void deleteAccount_NonExistentUser_ThrowsResourceNotFoundException() {
        when(userRepository.existsById(99L)).thenReturn(false);

        assertThrows(ResourceNotFoundException.class, () -> userService.deleteAccount(99L));
        verify(userRepository, never()).deleteById(anyLong());
    }

    @Test
    void exportData_ReturnsCompleteExport() {
        User user = new User();
        user.setId(1L);
        user.setEmail("export@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(workoutLogRepository.findByUserIdOrderByDateDesc(1L)).thenReturn(Collections.emptyList());
        when(foodLogRepository.findByUserIdOrderByDateDesc(1L)).thenReturn(Collections.emptyList());
        when(bodyMetricsRepository.findByUserIdOrderByDateDesc(1L)).thenReturn(Collections.emptyList());
        when(stepsLogRepository.findByUserIdOrderByDateDesc(1L)).thenReturn(Collections.emptyList());
        when(medicalReportRepository.findByUserIdOrderByReportDateDesc(1L)).thenReturn(Collections.emptyList());
        when(healthGoalRepository.findByUserId(1L)).thenReturn(Collections.emptyList());
        when(nutrientLogRepository.findByUserIdAndLogDateBetween(eq(1L), any(), any())).thenReturn(Collections.emptyList());

        UserDataExportDto export = userService.exportData(1L);

        assertNotNull(export);
        assertNotNull(export.profile());
        assertNotNull(export.exportedAt());
        assertEquals(0, export.workoutLogs().size());
        assertEquals(0, export.foodLogs().size());
    }
}

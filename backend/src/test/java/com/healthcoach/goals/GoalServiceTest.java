package com.healthcoach.goals;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.healthcoach.common.ResourceNotFoundException;
import com.healthcoach.goals.dto.CreateGoalRequest;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

@ExtendWith(MockitoExtension.class)
class GoalServiceTest {

    @Mock private HealthGoalRepository goalRepository;
    @Mock private UserService userService;

    private GoalService goalService;

    @BeforeEach
    void setUp() {
        goalService = new GoalService(goalRepository, userService);
    }

    @Test
    void getUserGoals_ReturnsGoalsForUser() {
        when(goalRepository.findByUserId(1L)).thenReturn(Collections.emptyList());

        List<HealthGoal> result = goalService.getUserGoals(1L);

        assertNotNull(result);
        verify(goalRepository).findByUserId(1L);
    }

    @Test
    void createGoal_ValidRequest_SavesAndReturnsGoal() {
        User user = new User();
        user.setId(1L);
        when(userService.getById(1L)).thenReturn(user);

        HealthGoal saved = new HealthGoal();
        saved.setGoalType("WEIGHT");
        saved.setTargetValue(70.0);
        when(goalRepository.save(any())).thenReturn(saved);

        CreateGoalRequest req = new CreateGoalRequest("WEIGHT", 70.0, LocalDate.now().plusMonths(3));
        HealthGoal result = goalService.createGoal(1L, req);

        assertNotNull(result);
        assertEquals("WEIGHT", result.getGoalType());
        assertEquals(70.0, result.getTargetValue());
        verify(goalRepository).save(any(HealthGoal.class));
    }

    @Test
    void deleteGoal_ExistingGoal_DeletesSuccessfully() {
        HealthGoal goal = new HealthGoal();
        goal.setId(10L);
        when(goalRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(goal));

        goalService.deleteGoal(1L, 10L);

        verify(goalRepository).delete(goal);
    }

    @Test
    void deleteGoal_NonExistentGoal_ThrowsResourceNotFoundException() {
        when(goalRepository.findByIdAndUserId(99L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> goalService.deleteGoal(1L, 99L));
        verify(goalRepository, never()).delete(any());
    }
}

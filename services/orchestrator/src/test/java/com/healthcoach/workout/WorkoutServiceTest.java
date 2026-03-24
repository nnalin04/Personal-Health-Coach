package com.healthcoach.workout;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.workout.dto.WorkoutLogRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

import java.time.LocalDate;
import java.util.Collections;

@ExtendWith(MockitoExtension.class)
class WorkoutServiceTest {

    @Mock private WorkoutLogRepository workoutLogRepository;
    @Mock private UserService userService;

    private WorkoutService workoutService;

    @BeforeEach
    void setUp() {
        workoutService = new WorkoutService(workoutLogRepository, userService);
    }

    @Test
    void create_ValidRequest_SavesAndReturnsLog() {
        User user = new User();
        user.setId(1L);
        when(userService.getById(1L)).thenReturn(user);

        WorkoutLog saved = new WorkoutLog();
        saved.setExerciseName("Bench Press");
        saved.setSets(3);
        saved.setReps(10);
        saved.setWeight(60.0);
        when(workoutLogRepository.save(any())).thenReturn(saved);

        WorkoutLogRequest req = new WorkoutLogRequest("Bench Press", 3, 10, 60.0, LocalDate.now());
        WorkoutLog result = workoutService.create(1L, req);

        assertNotNull(result);
        assertEquals("Bench Press", result.getExerciseName());
        verify(workoutLogRepository).save(any(WorkoutLog.class));
    }

    @Test
    void getByUser_NoDates_ReturnsAllRecordsWithoutDateFilter() {
        when(workoutLogRepository.findByUserId(anyLong(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(Collections.emptyList()));

        Page<WorkoutLog> result = workoutService.getByUser(1L, null, null, 0, 50);

        assertNotNull(result);
        verify(workoutLogRepository).findByUserId(anyLong(), any(Pageable.class));
        verify(workoutLogRepository, never()).findByUserIdAndDateBetween(anyLong(), any(), any(), any(Pageable.class));
    }

    @Test
    void getByUser_WithBothDates_UsesDateBetween() {
        LocalDate from = LocalDate.now().minusDays(7);
        LocalDate to = LocalDate.now();
        when(workoutLogRepository.findByUserIdAndDateBetween(anyLong(), eq(from), eq(to), any(Pageable.class)))
                .thenReturn(new PageImpl<>(Collections.emptyList()));

        workoutService.getByUser(1L, from, to, 0, 50);

        verify(workoutLogRepository).findByUserIdAndDateBetween(anyLong(), eq(from), eq(to), any(Pageable.class));
        verify(workoutLogRepository, never()).findByUserId(anyLong(), any(Pageable.class));
    }

    @Test
    void getByUser_OnlyFromDate_DefaultsEndToFuture() {
        LocalDate from = LocalDate.now().minusDays(7);
        when(workoutLogRepository.findByUserIdAndDateBetween(anyLong(), eq(from), any(LocalDate.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(Collections.emptyList()));

        workoutService.getByUser(1L, from, null, 0, 50);

        verify(workoutLogRepository).findByUserIdAndDateBetween(
                eq(1L), eq(from), any(LocalDate.class), any(Pageable.class));
    }

    @Test
    void getByUser_OnlyToDate_DefaultsStartToPast() {
        LocalDate to = LocalDate.now();
        when(workoutLogRepository.findByUserIdAndDateBetween(anyLong(), any(LocalDate.class), eq(to), any(Pageable.class)))
                .thenReturn(new PageImpl<>(Collections.emptyList()));

        workoutService.getByUser(1L, null, to, 0, 50);

        verify(workoutLogRepository).findByUserIdAndDateBetween(
                eq(1L), any(LocalDate.class), eq(to), any(Pageable.class));
    }
}

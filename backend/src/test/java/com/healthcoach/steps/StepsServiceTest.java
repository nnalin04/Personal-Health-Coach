package com.healthcoach.steps;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.healthcoach.steps.dto.StepsLogRequest;
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

@ExtendWith(MockitoExtension.class)
class StepsServiceTest {

    @Mock private StepsLogRepository stepsLogRepository;
    @Mock private UserService userService;

    private StepsService stepsService;

    @BeforeEach
    void setUp() {
        stepsService = new StepsService(stepsLogRepository, userService);
    }

    @Test
    void create_ValidRequest_SavesAndReturnsLog() {
        User user = new User();
        user.setId(1L);
        when(userService.getById(1L)).thenReturn(user);

        StepsLog saved = new StepsLog();
        saved.setStepCount(8500);
        when(stepsLogRepository.save(any())).thenReturn(saved);

        StepsLogRequest req = new StepsLogRequest(8500, LocalDate.now());
        StepsLog result = stepsService.create(1L, req);

        assertNotNull(result);
        assertEquals(8500, result.getStepCount());
        verify(stepsLogRepository).save(any(StepsLog.class));
    }

    @Test
    void getByUser_NoDates_ReturnsAllRecordsWithoutDateFilter() {
        when(stepsLogRepository.findByUserIdOrderByDateDesc(1L)).thenReturn(Collections.emptyList());

        List<StepsLog> result = stepsService.getByUser(1L, null, null);

        assertNotNull(result);
        verify(stepsLogRepository).findByUserIdOrderByDateDesc(1L);
        verify(stepsLogRepository, never()).findByUserIdAndDateBetween(anyLong(), any(), any());
    }

    @Test
    void getByUser_WithBothDates_UsesDateBetween() {
        LocalDate from = LocalDate.now().minusDays(7);
        LocalDate to = LocalDate.now();
        when(stepsLogRepository.findByUserIdAndDateBetween(1L, from, to)).thenReturn(Collections.emptyList());

        stepsService.getByUser(1L, from, to);

        verify(stepsLogRepository).findByUserIdAndDateBetween(1L, from, to);
        verify(stepsLogRepository, never()).findByUserIdOrderByDateDesc(anyLong());
    }

    @Test
    void getByUser_OnlyFromDate_DefaultsEndToFuture() {
        LocalDate from = LocalDate.now().minusDays(7);

        stepsService.getByUser(1L, from, null);

        verify(stepsLogRepository).findByUserIdAndDateBetween(eq(1L), eq(from), any(LocalDate.class));
    }
}

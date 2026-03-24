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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

import java.time.LocalDate;
import java.util.Collections;

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
        when(stepsLogRepository.findByUserId(anyLong(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(Collections.emptyList()));

        Page<StepsLog> result = stepsService.getByUser(1L, null, null, 0, 50);

        assertNotNull(result);
        verify(stepsLogRepository).findByUserId(anyLong(), any(Pageable.class));
        verify(stepsLogRepository, never()).findByUserIdAndDateBetween(anyLong(), any(), any(), any(Pageable.class));
    }

    @Test
    void getByUser_WithBothDates_UsesDateBetween() {
        LocalDate from = LocalDate.now().minusDays(7);
        LocalDate to = LocalDate.now();
        when(stepsLogRepository.findByUserIdAndDateBetween(anyLong(), eq(from), eq(to), any(Pageable.class)))
                .thenReturn(new PageImpl<>(Collections.emptyList()));

        stepsService.getByUser(1L, from, to, 0, 50);

        verify(stepsLogRepository).findByUserIdAndDateBetween(anyLong(), eq(from), eq(to), any(Pageable.class));
        verify(stepsLogRepository, never()).findByUserId(anyLong(), any(Pageable.class));
    }

    @Test
    void getByUser_OnlyFromDate_DefaultsEndToFuture() {
        LocalDate from = LocalDate.now().minusDays(7);
        when(stepsLogRepository.findByUserIdAndDateBetween(anyLong(), eq(from), any(LocalDate.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(Collections.emptyList()));

        stepsService.getByUser(1L, from, null, 0, 50);

        verify(stepsLogRepository).findByUserIdAndDateBetween(
                eq(1L), eq(from), any(LocalDate.class), any(Pageable.class));
    }
}

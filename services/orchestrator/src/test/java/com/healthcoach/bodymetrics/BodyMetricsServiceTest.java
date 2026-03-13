package com.healthcoach.bodymetrics;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.healthcoach.bodymetrics.dto.BodyMetricsRequest;
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
class BodyMetricsServiceTest {

    @Mock private BodyMetricsRepository bodyMetricsRepository;
    @Mock private UserService userService;

    private BodyMetricsService bodyMetricsService;

    @BeforeEach
    void setUp() {
        bodyMetricsService = new BodyMetricsService(bodyMetricsRepository, userService);
    }

    @Test
    void create_ValidRequest_SavesAndReturnsMetrics() {
        User user = new User();
        user.setId(1L);
        when(userService.getById(1L)).thenReturn(user);

        BodyMetrics saved = new BodyMetrics();
        saved.setWeight(75.0);
        saved.setBmi(23.1);
        when(bodyMetricsRepository.save(any())).thenReturn(saved);

        BodyMetricsRequest req = new BodyMetricsRequest(75.0, 23.1, 18.5, 40.0, LocalDate.now());
        BodyMetrics result = bodyMetricsService.create(1L, req);

        assertNotNull(result);
        assertEquals(75.0, result.getWeight());
        assertEquals(23.1, result.getBmi());
        verify(bodyMetricsRepository).save(any(BodyMetrics.class));
    }

    @Test
    void getByUser_NoDates_ReturnsAllRecordsWithoutDateFilter() {
        when(bodyMetricsRepository.findByUserIdOrderByDateDesc(1L)).thenReturn(Collections.emptyList());

        List<BodyMetrics> result = bodyMetricsService.getByUser(1L, null, null);

        assertNotNull(result);
        verify(bodyMetricsRepository).findByUserIdOrderByDateDesc(1L);
        verify(bodyMetricsRepository, never()).findByUserIdAndDateBetweenOrderByDateAsc(anyLong(), any(), any());
    }

    @Test
    void getByUser_WithBothDates_UsesDateBetween() {
        LocalDate from = LocalDate.now().minusDays(30);
        LocalDate to = LocalDate.now();
        when(bodyMetricsRepository.findByUserIdAndDateBetweenOrderByDateAsc(1L, from, to))
                .thenReturn(Collections.emptyList());

        bodyMetricsService.getByUser(1L, from, to);

        verify(bodyMetricsRepository).findByUserIdAndDateBetweenOrderByDateAsc(1L, from, to);
        verify(bodyMetricsRepository, never()).findByUserIdOrderByDateDesc(anyLong());
    }

    @Test
    void getByUser_OnlyFromDate_DefaultsEndToFuture() {
        LocalDate from = LocalDate.now().minusDays(7);

        bodyMetricsService.getByUser(1L, from, null);

        verify(bodyMetricsRepository).findByUserIdAndDateBetweenOrderByDateAsc(
                eq(1L), eq(from), any(LocalDate.class));
    }
}

package com.healthcoach.steps;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StepsLogRepository extends JpaRepository<StepsLog, Long> {
    // Unbounded — kept for HealthSummaryService (bounded by date range)
    List<StepsLog> findByUserIdAndDateBetween(Long userId, LocalDate from, LocalDate to);

    // Paginated list
    Page<StepsLog> findByUserId(Long userId, Pageable pageable);
    Page<StepsLog> findByUserIdAndDateBetween(Long userId, LocalDate from, LocalDate to, Pageable pageable);
}

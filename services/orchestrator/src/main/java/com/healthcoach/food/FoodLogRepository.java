package com.healthcoach.food;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FoodLogRepository extends JpaRepository<FoodLog, Long> {
    // Unbounded — kept for internal use by HealthSummaryService (bounded by date range)
    List<FoodLog> findByUserIdAndDateBetween(Long userId, LocalDate startDate, LocalDate endDate);

    // Paginated list (default: page=0, size=50, sorted by date DESC via Pageable)
    Page<FoodLog> findByUserId(Long userId, Pageable pageable);
    Page<FoodLog> findByUserIdAndDateBetween(Long userId, LocalDate startDate, LocalDate endDate, Pageable pageable);
}

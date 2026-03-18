package com.healthcoach.bodymetrics;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BodyMetricsRepository extends JpaRepository<BodyMetrics, Long> {
    // Unbounded — kept for HealthSummaryService (bounded by date range, sorted ASC for trend)
    List<BodyMetrics> findByUserIdAndDateBetweenOrderByDateAsc(Long userId, LocalDate from, LocalDate to);

    // Paginated list (sorted by date DESC via Pageable)
    Page<BodyMetrics> findByUserId(Long userId, Pageable pageable);
    Page<BodyMetrics> findByUserIdAndDateBetween(Long userId, LocalDate from, LocalDate to, Pageable pageable);
}

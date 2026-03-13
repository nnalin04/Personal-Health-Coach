package com.healthcoach.bodymetrics;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BodyMetricsRepository extends JpaRepository<BodyMetrics, Long> {
    List<BodyMetrics> findByUserIdOrderByDateDesc(Long userId);
    List<BodyMetrics> findByUserIdAndDateBetweenOrderByDateAsc(Long userId, LocalDate from, LocalDate to);
}

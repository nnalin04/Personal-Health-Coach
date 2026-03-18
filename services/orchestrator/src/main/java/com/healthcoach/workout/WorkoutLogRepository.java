package com.healthcoach.workout;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, Long> {
    // Unbounded — kept for internal use by HealthSummaryService (bounded by date range)
    List<WorkoutLog> findByUserIdAndDateBetween(Long userId, LocalDate startDate, LocalDate endDate);

    // Paginated list
    Page<WorkoutLog> findByUserId(Long userId, Pageable pageable);
    Page<WorkoutLog> findByUserIdAndDateBetween(Long userId, LocalDate startDate, LocalDate endDate, Pageable pageable);
}

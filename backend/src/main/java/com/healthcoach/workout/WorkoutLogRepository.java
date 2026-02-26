package com.healthcoach.workout;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, Long> {
    List<WorkoutLog> findByUserIdOrderByDateDesc(Long userId);
    List<WorkoutLog> findByUserIdAndDateBetween(Long userId, LocalDate startDate, LocalDate endDate);
}

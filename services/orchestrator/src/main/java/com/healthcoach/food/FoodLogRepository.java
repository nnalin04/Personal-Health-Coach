package com.healthcoach.food;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FoodLogRepository extends JpaRepository<FoodLog, Long> {
    List<FoodLog> findByUserIdOrderByDateDesc(Long userId);
    List<FoodLog> findByUserIdAndDateBetween(Long userId, LocalDate startDate, LocalDate endDate);
}

package com.healthcoach.steps;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StepsLogRepository extends JpaRepository<StepsLog, Long> {
    List<StepsLog> findByUserIdOrderByDateDesc(Long userId);
    List<StepsLog> findByUserIdAndDateBetween(Long userId, LocalDate from, LocalDate to);
}

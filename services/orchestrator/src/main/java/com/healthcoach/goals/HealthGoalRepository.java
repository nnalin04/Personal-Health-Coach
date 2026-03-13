package com.healthcoach.goals;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface HealthGoalRepository extends JpaRepository<HealthGoal, Long> {
    List<HealthGoal> findByUserId(Long userId);
    List<HealthGoal> findByUserIdAndCompletedFalse(Long userId);
    Optional<HealthGoal> findByIdAndUserId(Long id, Long userId);
}

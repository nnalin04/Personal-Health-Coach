package com.healthcoach.nutrient;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;

public interface NutrientLogRepository extends JpaRepository<NutrientLog, Long> {

    List<NutrientLog> findByUserIdAndLogDateBetween(Long userId, LocalDate from, LocalDate to);

    List<NutrientLog> findByUserIdAndLogDate(Long userId, LocalDate date);

    @Query("SELECT n FROM NutrientLog n WHERE n.user.id = :userId AND n.logDate BETWEEN :from AND :to ORDER BY n.logDate")
    List<NutrientLog> findForPeriod(@Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);
}

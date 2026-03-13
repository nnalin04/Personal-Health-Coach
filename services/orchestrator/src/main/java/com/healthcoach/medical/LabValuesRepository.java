package com.healthcoach.medical;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LabValuesRepository extends JpaRepository<LabValues, Long> {
    List<LabValues> findByReportUserIdOrderByReportReportDateAsc(Long userId);

    List<LabValues> findByReportUserIdAndReportReportDateAfterOrderByReportReportDateAsc(
            Long userId, LocalDate after);
}

package com.healthcoach.medical;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LabValuesRepository extends JpaRepository<LabValues, Long> {
    List<LabValues> findByReportUserIdOrderByReportReportDateAsc(Long userId);
}

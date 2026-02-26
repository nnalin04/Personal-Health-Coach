package com.healthcoach.medical;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MedicalReportRepository extends JpaRepository<MedicalReport, Long> {
    List<MedicalReport> findByUserIdOrderByReportDateDesc(Long userId);
}

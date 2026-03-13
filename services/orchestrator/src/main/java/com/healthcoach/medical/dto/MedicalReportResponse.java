package com.healthcoach.medical.dto;

import com.healthcoach.medical.LabValues;
import com.healthcoach.medical.MedicalReport;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public record MedicalReportResponse(
        Long id,
        String reportFilePath,
        LocalDate reportDate,
        Instant createdAt,
        List<LabValuesResponse> labs,
        List<String> extractionNotes
) {
    public static MedicalReportResponse from(MedicalReport report, List<LabValues> labs, List<String> extractionNotes) {
        return new MedicalReportResponse(
                report.getId(),
                report.getReportFilePath(),
                report.getReportDate(),
                report.getCreatedAt(),
                labs.stream().map(LabValuesResponse::from).toList(),
                extractionNotes
        );
    }
}

package com.healthcoach.aiclient.dto;

public record ParseMedicalReportRequest(
        String fileName,
        String fileBase64,
        String extractedText
) {
}

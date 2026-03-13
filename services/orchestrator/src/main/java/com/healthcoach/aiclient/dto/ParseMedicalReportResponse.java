package com.healthcoach.aiclient.dto;

import java.util.List;

public record ParseMedicalReportResponse(
        ParsedLabValues labValues,
        List<String> extractionNotes
) {
}

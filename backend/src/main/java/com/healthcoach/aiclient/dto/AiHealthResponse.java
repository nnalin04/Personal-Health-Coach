package com.healthcoach.aiclient.dto;

import java.util.List;

public record AiHealthResponse(
        List<String> dietSuggestions,
        List<String> trainingSuggestions,
        List<String> recoverySuggestions,
        List<String> medicalAwarenessNotes,
        String disclaimer
) {
}

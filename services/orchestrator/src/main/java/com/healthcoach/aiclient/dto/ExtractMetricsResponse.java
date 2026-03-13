package com.healthcoach.aiclient.dto;

import java.util.List;

public record ExtractMetricsResponse(List<ExtractedMetric> metrics, String raw_text) {

    public record ExtractedMetric(String metric, Double value, String date, String unit) {
    }
}

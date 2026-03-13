package com.healthcoach.bodymetrics.dto;

import com.healthcoach.bodymetrics.BodyMetrics;
import java.time.LocalDate;

public record BodyMetricsResponse(
        Long id,
        Double weight,
        Double bmi,
        Double bodyFat,
        Double muscleMass,
        LocalDate date
) {
    public static BodyMetricsResponse from(BodyMetrics metric) {
        return new BodyMetricsResponse(
                metric.getId(),
                metric.getWeight(),
                metric.getBmi(),
                metric.getBodyFat(),
                metric.getMuscleMass(),
                metric.getDate()
        );
    }
}

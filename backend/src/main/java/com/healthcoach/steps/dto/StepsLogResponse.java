package com.healthcoach.steps.dto;

import com.healthcoach.steps.StepsLog;
import java.time.LocalDate;

public record StepsLogResponse(
        Long id,
        Integer stepCount,
        LocalDate date
) {
    public static StepsLogResponse from(StepsLog log) {
        return new StepsLogResponse(log.getId(), log.getStepCount(), log.getDate());
    }
}

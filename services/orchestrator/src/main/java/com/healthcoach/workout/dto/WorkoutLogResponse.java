package com.healthcoach.workout.dto;

import com.healthcoach.workout.WorkoutLog;
import java.time.LocalDate;

public record WorkoutLogResponse(
        Long id,
        String exerciseName,
        Integer sets,
        Integer reps,
        Double weight,
        LocalDate date
) {
    public static WorkoutLogResponse from(WorkoutLog log) {
        return new WorkoutLogResponse(
                log.getId(),
                log.getExerciseName(),
                log.getSets(),
                log.getReps(),
                log.getWeight(),
                log.getDate()
        );
    }
}

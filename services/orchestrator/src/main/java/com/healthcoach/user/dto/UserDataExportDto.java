package com.healthcoach.user.dto;

import com.healthcoach.bodymetrics.dto.BodyMetricsResponse;
import com.healthcoach.food.dto.FoodLogResponse;
import com.healthcoach.steps.dto.StepsLogResponse;
import com.healthcoach.workout.dto.WorkoutLogResponse;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * Full data export for a user — returned by GET /api/users/me/export.
 * Contains all user-owned data for GDPR/privacy compliance.
 */
public record UserDataExportDto(
        UserProfileResponse profile,
        Instant exportedAt,
        List<WorkoutLogResponse> workoutLogs,
        List<FoodLogResponse> foodLogs,
        List<BodyMetricsResponse> bodyMetrics,
        List<StepsLogResponse> stepsLogs,
        List<MedicalReportExport> medicalReports,
        List<GoalExport> healthGoals,
        List<NutrientLogExport> nutrientLogs
) {
    /** Slimmed-down medical report for export (avoids circular ref with LabValues). */
    public record MedicalReportExport(Long id, LocalDate reportDate, String reportFilePath, Instant createdAt) {}

    /** Health goal export (user backref is already @JsonIgnore on entity). */
    public record GoalExport(Long id, String goalType, Double targetValue, LocalDate targetDate, boolean completed) {}

    /** Key nutrient fields for export without the User backref. */
    public record NutrientLogExport(
            Long id, LocalDate logDate, String foodDescription,
            Double vitaminA, Double vitaminC, Double vitaminD, Double vitaminE, Double vitaminK,
            Double vitaminB12, Double vitaminB6, Double vitaminB9, Double vitaminB1, Double vitaminB2, Double vitaminB3,
            Double calcium, Double iron, Double zinc, Double magnesium, Double potassium, Double selenium, Double iodine
    ) {}
}

package com.healthcoach.healthsummary;

import com.healthcoach.bodymetrics.BodyMetrics;
import com.healthcoach.bodymetrics.BodyMetricsRepository;
import com.healthcoach.food.FoodLog;
import com.healthcoach.food.FoodLogRepository;
import com.healthcoach.medical.LabValues;
import com.healthcoach.medical.LabValuesRepository;
import com.healthcoach.steps.StepsLog;
import com.healthcoach.steps.StepsLogRepository;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.workout.WorkoutLog;
import com.healthcoach.workout.WorkoutLogRepository;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import org.springframework.stereotype.Service;

@Service
public class HealthSummaryService {

    private final UserService userService;
    private final FoodLogRepository foodLogRepository;
    private final WorkoutLogRepository workoutLogRepository;
    private final BodyMetricsRepository bodyMetricsRepository;
    private final StepsLogRepository stepsLogRepository;
    private final LabValuesRepository labValuesRepository;

    public HealthSummaryService(
            UserService userService,
            FoodLogRepository foodLogRepository,
            WorkoutLogRepository workoutLogRepository,
            BodyMetricsRepository bodyMetricsRepository,
            StepsLogRepository stepsLogRepository,
            LabValuesRepository labValuesRepository
    ) {
        this.userService = userService;
        this.foodLogRepository = foodLogRepository;
        this.workoutLogRepository = workoutLogRepository;
        this.bodyMetricsRepository = bodyMetricsRepository;
        this.stepsLogRepository = stepsLogRepository;
        this.labValuesRepository = labValuesRepository;
    }

    public Map<String, Object> buildSummary(Long userId) {
        User user = userService.getById(userId);
        LocalDate now = LocalDate.now();
        LocalDate start90 = now.minusDays(89);

        List<FoodLog> foodLogs = foodLogRepository.findByUserIdAndDateBetween(userId, start90, now);
        List<WorkoutLog> workoutLogs = workoutLogRepository.findByUserIdAndDateBetween(userId, start90, now);
        List<BodyMetrics> bodyMetrics = bodyMetricsRepository.findByUserIdAndDateBetweenOrderByDateAsc(userId, start90, now);
        List<StepsLog> stepsLogs = stepsLogRepository.findByUserIdAndDateBetween(userId, start90, now);
        List<LabValues> labs = labValuesRepository.findByReportUserIdOrderByReportReportDateAsc(userId);

        Map<String, Object> profile = buildProfile(user, bodyMetrics);
        Map<String, Object> nutrition = buildNutritionSummary(foodLogs, now);
        Map<String, Object> training = buildTrainingSummary(workoutLogs, stepsLogs, now);
        Map<String, Object> weightTrend = buildWeightTrend(bodyMetrics, now);
        Map<String, Object> medicalTrends = buildMedicalTrends(labs);
        List<String> riskFlags = buildRiskFlags(foodLogs, workoutLogs, bodyMetrics, stepsLogs, labs, now);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("profile", profile);
        response.put("nutrition_summary", nutrition);
        response.put("training_summary", training);
        response.put("weight_trend", weightTrend);
        response.put("medical_trends", medicalTrends);
        response.put("risk_flags", riskFlags);
        return response;
    }

    private Map<String, Object> buildProfile(User user, List<BodyMetrics> metrics) {
        BodyMetrics latest = metrics.isEmpty() ? null : metrics.get(metrics.size() - 1);
        Map<String, Object> profile = new LinkedHashMap<>();
        profile.put("age", user.getAge());
        profile.put("gender", user.getGender());
        profile.put("height", user.getHeight());
        profile.put("goal", user.getGoal());
        profile.put("diet_type", user.getDietType());
        profile.put("medical_flags", user.getMedicalFlags());
        profile.put("latest_weight", latest != null ? latest.getWeight() : null);
        return profile;
    }

    private Map<String, Object> buildNutritionSummary(List<FoodLog> foodLogs, LocalDate now) {
        Map<String, Object> nutrition = new LinkedHashMap<>();
        nutrition.put("last_7_days", nutritionWindow(foodLogs, now, 7));
        nutrition.put("last_30_days", nutritionWindow(foodLogs, now, 30));
        nutrition.put("last_90_days", nutritionWindow(foodLogs, now, 90));
        return nutrition;
    }

    private Map<String, Object> nutritionWindow(List<FoodLog> foodLogs, LocalDate now, int days) {
        LocalDate start = now.minusDays(days - 1L);
        List<FoodLog> window = foodLogs.stream().filter(f -> !f.getDate().isBefore(start)).toList();
        double avgProtein = window.stream().mapToDouble(FoodLog::getProtein).average().orElse(0.0);
        double avgCalories = window.stream().mapToDouble(FoodLog::getCalories).average().orElse(0.0);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("avg_protein", round(avgProtein));
        out.put("avg_calories", round(avgCalories));
        out.put("entry_count", window.size());
        return out;
    }

    private Map<String, Object> buildTrainingSummary(List<WorkoutLog> workouts, List<StepsLog> steps, LocalDate now) {
        Map<String, Object> training = new LinkedHashMap<>();
        Map<String, Object> freq = new LinkedHashMap<>();
        freq.put("last_7_days", round(workoutFrequencyPerWeek(workouts, now, 7)));
        freq.put("last_30_days", round(workoutFrequencyPerWeek(workouts, now, 30)));
        freq.put("last_90_days", round(workoutFrequencyPerWeek(workouts, now, 90)));

        Map<String, Object> stepAverage = new LinkedHashMap<>();
        stepAverage.put("last_7_days", round(stepAverage(steps, now, 7)));
        stepAverage.put("last_30_days", round(stepAverage(steps, now, 30)));
        stepAverage.put("last_90_days", round(stepAverage(steps, now, 90)));

        training.put("workout_frequency", freq);
        training.put("strength_progression", strengthProgression(workouts, now));
        training.put("step_average", stepAverage);
        return training;
    }

    private Map<String, Object> buildWeightTrend(List<BodyMetrics> bodyMetrics, LocalDate now) {
        Map<String, Object> weightTrend = new LinkedHashMap<>();
        weightTrend.put("last_7_days", weightWindowTrend(bodyMetrics, now, 7));
        weightTrend.put("last_30_days", weightWindowTrend(bodyMetrics, now, 30));
        weightTrend.put("last_90_days", weightWindowTrend(bodyMetrics, now, 90));
        return weightTrend;
    }

    private Map<String, Object> weightWindowTrend(List<BodyMetrics> bodyMetrics, LocalDate now, int days) {
        LocalDate start = now.minusDays(days - 1L);
        List<BodyMetrics> window = bodyMetrics.stream()
                .filter(m -> !m.getDate().isBefore(start))
                .toList();

        Map<String, Object> trend = new LinkedHashMap<>();
        if (window.isEmpty()) {
            trend.put("start_weight", null);
            trend.put("end_weight", null);
            trend.put("change", null);
            trend.put("direction", "unknown");
            return trend;
        }

        Double startWeight = window.get(0).getWeight();
        Double endWeight = window.get(window.size() - 1).getWeight();
        trend.put("start_weight", startWeight);
        trend.put("end_weight", endWeight);

        if (startWeight == null || endWeight == null) {
            trend.put("change", null);
            trend.put("direction", "unknown");
            return trend;
        }

        double change = endWeight - startWeight;
        trend.put("change", round(change));
        if (Math.abs(change) < 0.0001) {
            trend.put("direction", "stable");
        } else if (change > 0) {
            trend.put("direction", "up");
        } else {
            trend.put("direction", "down");
        }
        return trend;
    }

    private double workoutFrequencyPerWeek(List<WorkoutLog> workouts, LocalDate now, int days) {
        LocalDate start = now.minusDays(days - 1L);
        long count = workouts.stream().filter(w -> !w.getDate().isBefore(start)).count();
        return count / (days / 7.0);
    }

    private double stepAverage(List<StepsLog> steps, LocalDate now, int days) {
        LocalDate start = now.minusDays(days - 1L);
        return steps.stream()
                .filter(s -> !s.getDate().isBefore(start))
                .mapToInt(StepsLog::getStepCount)
                .average()
                .orElse(0.0);
    }

    private Map<String, Object> strengthProgression(List<WorkoutLog> workouts, LocalDate now) {
        LocalDate last30Start = now.minusDays(29);
        LocalDate prev30Start = now.minusDays(59);
        LocalDate prev30End = now.minusDays(30);

        double last30Volume = workouts.stream()
                .filter(w -> !w.getDate().isBefore(last30Start))
                .mapToDouble(this::volume)
                .sum();

        double prev30Volume = workouts.stream()
                .filter(w -> !w.getDate().isBefore(prev30Start) && !w.getDate().isAfter(prev30End))
                .mapToDouble(this::volume)
                .sum();

        double changePercent = prev30Volume == 0.0 ? 0.0 : ((last30Volume - prev30Volume) / prev30Volume) * 100.0;

        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("last_30_day_volume", round(last30Volume));
        summary.put("previous_30_day_volume", round(prev30Volume));
        summary.put("change_percent", round(changePercent));
        return summary;
    }

    private double volume(WorkoutLog workout) {
        return workout.getSets() * workout.getReps() * workout.getWeight();
    }

    private Map<String, Object> buildMedicalTrends(List<LabValues> labs) {
        Map<String, Object> trends = new LinkedHashMap<>();
        if (labs.size() < 2) {
            trends.put("status", "Insufficient lab history for trend comparison");
            return trends;
        }

        LabValues previous = labs.get(labs.size() - 2);
        LabValues latest = labs.get(labs.size() - 1);

        trends.put("vitamin_d", trendOf(previous.getVitaminD(), latest.getVitaminD(), false));
        trends.put("tsh", trendOf(previous.getTsh(), latest.getTsh(), true));
        trends.put("ldl", trendOf(previous.getLdl(), latest.getLdl(), true));
        trends.put("hdl", trendOf(previous.getHdl(), latest.getHdl(), false));
        trends.put("triglycerides", trendOf(previous.getTriglycerides(), latest.getTriglycerides(), true));
        trends.put("hba1c", trendOf(previous.getHba1c(), latest.getHba1c(), true));
        trends.put("creatinine", trendOf(previous.getCreatinine(), latest.getCreatinine(), true));
        trends.put("hemoglobin", trendOf(previous.getHemoglobin(), latest.getHemoglobin(), false));
        trends.put("alt", trendOf(previous.getAlt(), latest.getAlt(), true));
        trends.put("ast", trendOf(previous.getAst(), latest.getAst(), true));
        trends.put("glucose", trendOf(previous.getGlucose(), latest.getGlucose(), true));
        trends.put("testosterone", trendOf(previous.getTestosterone(), latest.getTestosterone(), false));
        return trends;
    }

    private Map<String, Object> trendOf(Double previous, Double latest, boolean lowerIsBetter) {
        Map<String, Object> trend = new LinkedHashMap<>();
        trend.put("previous", previous);
        trend.put("latest", latest);
        if (previous == null || latest == null) {
            trend.put("change", null);
            trend.put("direction", "unknown");
            return trend;
        }
        double change = latest - previous;
        trend.put("change", round(change));
        if (Math.abs(change) < 0.0001) {
            trend.put("direction", "stable");
        } else {
            boolean improved = lowerIsBetter ? change < 0 : change > 0;
            trend.put("direction", improved ? "improved" : "worsened");
        }
        return trend;
    }

    private List<String> buildRiskFlags(
            List<FoodLog> foods,
            List<WorkoutLog> workouts,
            List<BodyMetrics> bodyMetrics,
            List<StepsLog> steps,
            List<LabValues> labs,
            LocalDate now
    ) {
        List<String> flags = new ArrayList<>();

        double avgProtein7 = nutritionWindow(foods, now, 7).get("avg_protein") instanceof Double d ? d : 0.0;
        double latestWeight = latestValue(bodyMetrics, BodyMetrics::getWeight, 70.0);
        double targetProtein = latestWeight * 1.2;
        if (avgProtein7 > 0 && avgProtein7 < targetProtein * 0.8) {
            flags.add("Potential protein deficit based on recent intake versus body weight target.");
        }

        List<BodyMetrics> last30 = bodyMetrics.stream()
                .filter(m -> !m.getDate().isBefore(now.minusDays(29)))
                .toList();
        if (last30.size() >= 3) {
            double min = last30.stream().mapToDouble(BodyMetrics::getWeight).min().orElse(0.0);
            double max = last30.stream().mapToDouble(BodyMetrics::getWeight).max().orElse(0.0);
            if ((max - min) < 0.5) {
                flags.add("Possible weight plateau over the last 30 days.");
            }
        }

        long workoutsLast30 = workouts.stream().filter(w -> !w.getDate().isBefore(now.minusDays(29))).count();
        double stepAvg30 = stepAverage(steps, now, 30);
        if (workoutsLast30 < 8 || stepAvg30 < 6000) {
            flags.add("Training or activity inconsistency detected in the last 30 days.");
        }

        if (labs.size() >= 2) {
            LabValues previous = labs.get(labs.size() - 2);
            LabValues latest = labs.get(labs.size() - 1);
            if (isDeteriorating(previous.getLdl(), latest.getLdl(), 10.0)
                    || isDeteriorating(previous.getHba1c(), latest.getHba1c(), 0.2)
                    || isDeteriorating(previous.getCreatinine(), latest.getCreatinine(), 0.2)
                    || isDecreasing(previous.getVitaminD(), latest.getVitaminD(), 5.0)
                    || isDeteriorating(previous.getAlt(), latest.getAlt(), 8.0)
                    || isDeteriorating(previous.getAst(), latest.getAst(), 8.0)
                    || isDeteriorating(previous.getGlucose(), latest.getGlucose(), 10.0)
                    || isDecreasing(previous.getTestosterone(), latest.getTestosterone(), 70.0)) {
                flags.add("Non-diagnostic medical lab deterioration pattern detected; clinician follow-up advised.");
            }
        }

        return flags;
    }

    private boolean isDeteriorating(Double previous, Double latest, double threshold) {
        return previous != null && latest != null && (latest - previous) > threshold;
    }

    private boolean isDecreasing(Double previous, Double latest, double threshold) {
        return previous != null && latest != null && (previous - latest) > threshold;
    }

    private <T> double latestValue(List<T> items, Function<T, Double> extractor, double fallback) {
        return items.stream()
                .map(extractor)
                .filter(v -> v != null)
                .reduce((first, second) -> second)
                .orElse(fallback);
    }

    private double round(double value) {
        return Math.round(value * 100.0) / 100.0;
    }
}

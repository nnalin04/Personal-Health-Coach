package com.healthcoach.user;

import com.healthcoach.bodymetrics.BodyMetricsRepository;
import com.healthcoach.bodymetrics.dto.BodyMetricsResponse;
import com.healthcoach.common.ResourceNotFoundException;
import com.healthcoach.food.FoodLogRepository;
import com.healthcoach.food.dto.FoodLogResponse;
import com.healthcoach.goals.HealthGoalRepository;
import com.healthcoach.medical.MedicalReportRepository;
import com.healthcoach.nutrient.NutrientLog;
import com.healthcoach.nutrient.NutrientLogRepository;
import com.healthcoach.steps.StepsLogRepository;
import com.healthcoach.steps.dto.StepsLogResponse;
import com.healthcoach.user.dto.UpdateProfileRequest;
import com.healthcoach.user.dto.UserDataExportDto;
import com.healthcoach.user.dto.UserDataExportDto.GoalExport;
import com.healthcoach.user.dto.UserDataExportDto.MedicalReportExport;
import com.healthcoach.user.dto.UserDataExportDto.NutrientLogExport;
import com.healthcoach.user.dto.UserProfileResponse;
import com.healthcoach.workout.WorkoutLogRepository;
import com.healthcoach.workout.dto.WorkoutLogResponse;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final WorkoutLogRepository workoutLogRepository;
    private final FoodLogRepository foodLogRepository;
    private final BodyMetricsRepository bodyMetricsRepository;
    private final StepsLogRepository stepsLogRepository;
    private final MedicalReportRepository medicalReportRepository;
    private final HealthGoalRepository healthGoalRepository;
    private final NutrientLogRepository nutrientLogRepository;

    public UserService(
            UserRepository userRepository,
            WorkoutLogRepository workoutLogRepository,
            FoodLogRepository foodLogRepository,
            BodyMetricsRepository bodyMetricsRepository,
            StepsLogRepository stepsLogRepository,
            MedicalReportRepository medicalReportRepository,
            HealthGoalRepository healthGoalRepository,
            NutrientLogRepository nutrientLogRepository
    ) {
        this.userRepository = userRepository;
        this.workoutLogRepository = workoutLogRepository;
        this.foodLogRepository = foodLogRepository;
        this.bodyMetricsRepository = bodyMetricsRepository;
        this.stepsLogRepository = stepsLogRepository;
        this.medicalReportRepository = medicalReportRepository;
        this.healthGoalRepository = healthGoalRepository;
        this.nutrientLogRepository = nutrientLogRepository;
    }

    public User getById(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));
    }

    @Transactional
    public User updateProfile(Long userId, UpdateProfileRequest request) {
        User user = getById(userId);
        if (request.age() != null) user.setAge(request.age());
        if (request.gender() != null) user.setGender(request.gender());
        if (request.height() != null) user.setHeight(request.height());
        if (request.goal() != null) user.setGoal(request.goal());
        if (request.dietType() != null) user.setDietType(request.dietType());
        if (request.medicalFlags() != null) user.setMedicalFlags(request.medicalFlags());
        if (request.region() != null) user.setRegion(request.region());
        if (request.cuisineStyle() != null) user.setCuisineStyle(request.cuisineStyle());
        if (request.dietaryRestrictions() != null) user.setDietaryRestrictions(request.dietaryRestrictions());
        return userRepository.save(user);
    }

    /** Permanently delete the user and all their data (CASCADE handles child rows). */
    @Transactional
    public void deleteAccount(Long userId) {
        if (!userRepository.existsById(userId)) {
            throw new ResourceNotFoundException("User not found: " + userId);
        }
        userRepository.deleteById(userId);
    }

    /** Return a full export of all data owned by the user. */
    @Transactional(readOnly = true)
    public UserDataExportDto exportData(Long userId) {
        User user = getById(userId);

        Pageable allByDateDesc = Pageable.unpaged(Sort.by(Sort.Direction.DESC, "date"));

        List<WorkoutLogResponse> workouts = workoutLogRepository
                .findByUserId(userId, allByDateDesc).stream()
                .map(WorkoutLogResponse::from).toList();

        List<FoodLogResponse> food = foodLogRepository
                .findByUserId(userId, allByDateDesc).stream()
                .map(FoodLogResponse::from).toList();

        List<BodyMetricsResponse> metrics = bodyMetricsRepository
                .findByUserId(userId, allByDateDesc).stream()
                .map(BodyMetricsResponse::from).toList();

        List<StepsLogResponse> steps = stepsLogRepository
                .findByUserId(userId, allByDateDesc).stream()
                .map(StepsLogResponse::from).toList();

        List<MedicalReportExport> reports = medicalReportRepository
                .findByUserIdOrderByReportDateDesc(userId).stream()
                .map(r -> new MedicalReportExport(r.getId(), r.getReportDate(), r.getReportFilePath(), r.getCreatedAt()))
                .toList();

        List<GoalExport> goals = healthGoalRepository
                .findByUserId(userId).stream()
                .map(g -> new GoalExport(g.getId(), g.getGoalType(), g.getTargetValue(), g.getTargetDate(), g.isCompleted()))
                .toList();

        List<NutrientLogExport> nutrients = nutrientLogRepository
                .findByUserIdAndLogDateBetween(userId,
                        java.time.LocalDate.now().minusYears(1),
                        java.time.LocalDate.now()).stream()
                .map(UserService::toNutrientExport).toList();

        return new UserDataExportDto(
                UserProfileResponse.from(user),
                Instant.now(),
                workouts, food, metrics, steps, reports, goals, nutrients
        );
    }

    private static NutrientLogExport toNutrientExport(NutrientLog n) {
        return new NutrientLogExport(
                n.getId(), n.getLogDate(), n.getFoodDescription(),
                n.getVitaminAMcg(), n.getVitaminCMg(), n.getVitaminDMcg(),
                n.getVitaminEMg(), n.getVitaminKMcg(), n.getVitaminB12Mcg(),
                n.getVitaminB6Mg(), n.getVitaminB9Mcg(), n.getVitaminB1Mg(),
                n.getVitaminB2Mg(), n.getVitaminB3Mg(),
                n.getCalciumMg(), n.getIronMg(), n.getZincMg(),
                n.getMagnesiumMg(), n.getPotassiumMg(), n.getSeleniumMcg(), n.getIodineMcg()
        );
    }
}

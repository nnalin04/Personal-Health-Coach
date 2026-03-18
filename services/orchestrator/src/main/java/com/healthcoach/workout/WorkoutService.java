package com.healthcoach.workout;

import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.workout.dto.WorkoutLogRequest;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

@Service
public class WorkoutService {

    private final WorkoutLogRepository workoutLogRepository;
    private final UserService userService;

    public WorkoutService(WorkoutLogRepository workoutLogRepository, UserService userService) {
        this.workoutLogRepository = workoutLogRepository;
        this.userService = userService;
    }

    public WorkoutLog create(Long userId, WorkoutLogRequest request) {
        User user = userService.getById(userId);
        WorkoutLog log = new WorkoutLog();
        log.setUser(user);
        log.setExerciseName(request.exerciseName());
        log.setSets(request.sets());
        log.setReps(request.reps());
        log.setWeight(request.weight());
        log.setDate(request.date());
        return workoutLogRepository.save(log);
    }

    public Page<WorkoutLog> getByUser(Long userId, LocalDate from, LocalDate to, int page, int size) {
        PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "date"));
        if (from == null && to == null) {
            return workoutLogRepository.findByUserId(userId, pageable);
        }
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end   = to   != null ? to   : LocalDate.now().plusDays(1);
        return workoutLogRepository.findByUserIdAndDateBetween(userId, start, end, pageable);
    }

    /** Unbounded list for HealthSummaryService (already bounded by date range). */
    public List<WorkoutLog> getByUserUnbounded(Long userId, LocalDate from, LocalDate to) {
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end   = to   != null ? to   : LocalDate.now().plusDays(1);
        return workoutLogRepository.findByUserIdAndDateBetween(userId, start, end);
    }
}

package com.healthcoach.workout;

import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import com.healthcoach.workout.dto.WorkoutLogRequest;
import java.time.LocalDate;
import java.util.List;
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

    public List<WorkoutLog> getByUser(Long userId, LocalDate from, LocalDate to) {
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end = to != null ? to : LocalDate.now();
        return workoutLogRepository.findByUserIdAndDateBetween(userId, start, end);
    }
}

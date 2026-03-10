package com.healthcoach.steps;

import com.healthcoach.steps.dto.StepsLogRequest;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import java.time.LocalDate;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class StepsService {

    private final StepsLogRepository stepsLogRepository;
    private final UserService userService;

    public StepsService(StepsLogRepository stepsLogRepository, UserService userService) {
        this.stepsLogRepository = stepsLogRepository;
        this.userService = userService;
    }

    public StepsLog create(Long userId, StepsLogRequest request) {
        User user = userService.getById(userId);
        StepsLog log = new StepsLog();
        log.setUser(user);
        log.setStepCount(request.stepCount());
        log.setDate(request.date());
        return stepsLogRepository.save(log);
    }

    public List<StepsLog> getByUser(Long userId, LocalDate from, LocalDate to) {
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end = to != null ? to : LocalDate.now();
        return stepsLogRepository.findByUserIdAndDateBetween(userId, start, end);
    }
}

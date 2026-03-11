package com.healthcoach.bodymetrics;

import com.healthcoach.bodymetrics.dto.BodyMetricsRequest;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import java.time.LocalDate;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class BodyMetricsService {

    private final BodyMetricsRepository bodyMetricsRepository;
    private final UserService userService;

    public BodyMetricsService(BodyMetricsRepository bodyMetricsRepository, UserService userService) {
        this.bodyMetricsRepository = bodyMetricsRepository;
        this.userService = userService;
    }

    public BodyMetrics create(Long userId, BodyMetricsRequest request) {
        User user = userService.getById(userId);
        BodyMetrics metrics = new BodyMetrics();
        metrics.setUser(user);
        metrics.setWeight(request.weight());
        metrics.setBmi(request.bmi());
        metrics.setBodyFat(request.bodyFat());
        metrics.setMuscleMass(request.muscleMass());
        metrics.setDate(request.date());
        return bodyMetricsRepository.save(metrics);
    }

    public List<BodyMetrics> getByUser(Long userId, LocalDate from, LocalDate to) {
        if (from == null && to == null) {
            return bodyMetricsRepository.findByUserIdOrderByDateDesc(userId);
        }
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end = to != null ? to : LocalDate.now().plusDays(1);
        return bodyMetricsRepository.findByUserIdAndDateBetweenOrderByDateAsc(userId, start, end);
    }
}

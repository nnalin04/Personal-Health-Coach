package com.healthcoach.bodymetrics;

import com.healthcoach.bodymetrics.dto.BodyMetricsRequest;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
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

    public Page<BodyMetrics> getByUser(Long userId, LocalDate from, LocalDate to, int page, int size) {
        PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "date"));
        if (from == null && to == null) {
            return bodyMetricsRepository.findByUserId(userId, pageable);
        }
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end   = to   != null ? to   : LocalDate.now().plusDays(1);
        return bodyMetricsRepository.findByUserIdAndDateBetween(userId, start, end, pageable);
    }

    /** Unbounded list for HealthSummaryService (bounded by date range, sorted ASC for trend). */
    public List<BodyMetrics> getByUserUnbounded(Long userId, LocalDate from, LocalDate to) {
        LocalDate start = from != null ? from : LocalDate.now().minusDays(89);
        LocalDate end   = to   != null ? to   : LocalDate.now().plusDays(1);
        return bodyMetricsRepository.findByUserIdAndDateBetweenOrderByDateAsc(userId, start, end);
    }
}

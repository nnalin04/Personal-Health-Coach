package com.healthcoach.workout;

import com.healthcoach.security.UserPrincipal;
import com.healthcoach.workout.dto.WorkoutLogRequest;
import com.healthcoach.workout.dto.WorkoutLogResponse;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/workouts")
public class WorkoutController {

    private final WorkoutService workoutService;

    public WorkoutController(WorkoutService workoutService) {
        this.workoutService = workoutService;
    }

    @PostMapping
    public WorkoutLogResponse create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody WorkoutLogRequest request
    ) {
        return WorkoutLogResponse.from(workoutService.create(principal.getId(), request));
    }

    @GetMapping
    public List<WorkoutLogResponse> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return workoutService.getByUser(principal.getId(), from, to)
                .stream()
                .map(WorkoutLogResponse::from)
                .toList();
    }
}

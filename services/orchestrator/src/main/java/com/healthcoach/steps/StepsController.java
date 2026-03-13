package com.healthcoach.steps;

import com.healthcoach.security.UserPrincipal;
import com.healthcoach.steps.dto.StepsLogRequest;
import com.healthcoach.steps.dto.StepsLogResponse;
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
@RequestMapping("/api/steps")
public class StepsController {

    private final StepsService stepsService;

    public StepsController(StepsService stepsService) {
        this.stepsService = stepsService;
    }

    @PostMapping
    public StepsLogResponse create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody StepsLogRequest request
    ) {
        return StepsLogResponse.from(stepsService.create(principal.getId(), request));
    }

    @GetMapping
    public List<StepsLogResponse> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return stepsService.getByUser(principal.getId(), from, to)
                .stream()
                .map(StepsLogResponse::from)
                .toList();
    }
}

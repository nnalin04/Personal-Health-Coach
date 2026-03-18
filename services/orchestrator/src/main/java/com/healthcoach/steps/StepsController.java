package com.healthcoach.steps;

import com.healthcoach.common.PagedResponse;
import com.healthcoach.security.UserPrincipal;
import com.healthcoach.steps.dto.StepsLogRequest;
import com.healthcoach.steps.dto.StepsLogResponse;
import jakarta.validation.Valid;
import java.time.LocalDate;
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
    public PagedResponse<StepsLogResponse> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return PagedResponse.from(
                stepsService.getByUser(principal.getId(), from, to, page, size)
                            .map(StepsLogResponse::from)
        );
    }
}

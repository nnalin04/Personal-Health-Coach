package com.healthcoach.bodymetrics;

import com.healthcoach.common.PagedResponse;
import com.healthcoach.bodymetrics.dto.BodyMetricsRequest;
import com.healthcoach.bodymetrics.dto.BodyMetricsResponse;
import com.healthcoach.security.UserPrincipal;
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
@RequestMapping("/api/body-metrics")
public class BodyMetricsController {

    private final BodyMetricsService bodyMetricsService;

    public BodyMetricsController(BodyMetricsService bodyMetricsService) {
        this.bodyMetricsService = bodyMetricsService;
    }

    @PostMapping
    public BodyMetricsResponse create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody BodyMetricsRequest request
    ) {
        return BodyMetricsResponse.from(bodyMetricsService.create(principal.getId(), request));
    }

    @GetMapping
    public PagedResponse<BodyMetricsResponse> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return PagedResponse.from(
                bodyMetricsService.getByUser(principal.getId(), from, to, page, size)
                                  .map(BodyMetricsResponse::from)
        );
    }
}

package com.healthcoach.food;

import com.healthcoach.common.PagedResponse;
import com.healthcoach.food.dto.FoodLogRequest;
import com.healthcoach.food.dto.FoodLogResponse;
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
@RequestMapping("/api/foods")
public class FoodController {

    private final FoodService foodService;

    public FoodController(FoodService foodService) {
        this.foodService = foodService;
    }

    @PostMapping
    public FoodLogResponse create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody FoodLogRequest request
    ) {
        return FoodLogResponse.from(foodService.create(principal.getId(), request));
    }

    @GetMapping
    public PagedResponse<FoodLogResponse> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return PagedResponse.from(
                foodService.getByUser(principal.getId(), from, to, page, size)
                           .map(FoodLogResponse::from)
        );
    }
}

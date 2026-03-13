package com.healthcoach.food;

import com.healthcoach.food.dto.FoodLogRequest;
import com.healthcoach.food.dto.FoodLogResponse;
import com.healthcoach.security.UserPrincipal;
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
    public List<FoodLogResponse> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return foodService.getByUser(principal.getId(), from, to)
                .stream()
                .map(FoodLogResponse::from)
                .toList();
    }
}

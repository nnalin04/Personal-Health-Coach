package com.healthcoach.nutrient;

import com.healthcoach.nutrient.dto.*;
import com.healthcoach.security.UserPrincipal;
import com.healthcoach.user.User;
import com.healthcoach.user.UserRepository;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/nutrient")
public class NutrientController {

    private final NutrientLogService service;
    private final UserRepository userRepo;

    public NutrientController(NutrientLogService service, UserRepository userRepo) {
        this.service = service;
        this.userRepo = userRepo;
    }

    @GetMapping("/daily-summary")
    public ResponseEntity<NutrientSummaryDTO> getDailySummary(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        User user = userRepo.findById(principal.getId())
            .orElseThrow(() -> new RuntimeException("User not found"));
        LocalDate targetDate = date != null ? date : LocalDate.now();
        return ResponseEntity.ok(service.getDailySummary(user, targetDate));
    }

    @GetMapping("/weekly-trends")
    public ResponseEntity<WeeklyNutrientTrendDTO> getWeeklyTrends(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        User user = userRepo.findById(principal.getId())
            .orElseThrow(() -> new RuntimeException("User not found"));
        LocalDate endDate = to != null ? to : LocalDate.now();
        return ResponseEntity.ok(service.getWeeklyTrend(user, endDate));
    }
}
